#include "MultiVehicleManager.h"
#include "RebootConnectionManager.h"
#include "VehicleIdConflictManager.h"
#include "FirmwarePlugin.h"
#include "FirmwarePluginManager.h"
#ifndef QGC_NO_SERIAL_LINK
#include "SerialLink.h"
#include "QGCSerialPortInfo.h"
#endif
#include <QtCore/QDir>
#include <QtCore/QJsonDocument>
#include <QtCore/QSaveFile>
#include <QtCore/QStandardPaths>
#include <QtCore/QUuid>
#include "MAVLinkProtocol.h"
#include "AppMessages.h"
#include "ParameterManager.h"
#include "SettingsManager.h"
#include "MavlinkSettings.h"
#include "FirmwareUpgradeSettings.h"
#include "QGCCorePlugin.h"
#include "QGCOptions.h"
#include "LinkManager.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"
#include "LinkInterface.h"
#include "MissionItem.h"
#include "MissionManager.h"
#include "QmlObjectListModel.h"
#ifdef Q_OS_IOS
#include "MobileScreenMgr.h"
#elif defined(Q_OS_ANDROID)
#include "AndroidInterface.h"
#endif
#include "QGCLoggingCategory.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QTimer>
#include <QtCore/QVariantMap>
#include <QtCore/QtNumeric>

#include <limits>

QGC_LOGGING_CATEGORY(MultiVehicleManagerLog, "Vehicle.MultiVehicleManager")

Q_APPLICATION_STATIC(MultiVehicleManager, _multiVehicleManagerInstance);



MultiVehicleManager::MultiVehicleManager(QObject *parent)
    : QObject(parent)
    , _gcsHeartbeatTimer(new QTimer(this))
    , _vehicles(new QmlObjectListModel(this))
    , _selectedVehicles(new QmlObjectListModel(this))
    , _idConflicts(new VehicleIdConflictManager(this))
    , _rebootConnection(new RebootConnectionManager(this))
{
    qCDebug(MultiVehicleManagerLog) << this;
    _idConflicts->setMessageSender([](QObject *object, mavlink_message_t &message) {
        auto *link = qobject_cast<LinkInterface *>(object);
        if (!link || !link->isConnected() || !link->mavlinkChannelIsSet()) return false;
        link->sendMessageThreadSafe(message);
        return true;
    });
    _idConflicts->setBackupWriter([](const QVariantMap &record) {
        const QString directory = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
            + QStringLiteral("/VehicleIdBackups");
        if (!QDir().mkpath(directory)) return false;
        QSaveFile file(directory + QStringLiteral("/") + QUuid::createUuid().toString(QUuid::WithoutBraces) + QStringLiteral(".json"));
        if (!file.open(QIODevice::WriteOnly)) return false;
        const QByteArray bytes = QJsonDocument::fromVariant(record).toJson(QJsonDocument::Indented);
        return file.write(bytes) == bytes.size() && file.commit();
    });
    connect(_idConflicts, &VehicleIdConflictManager::systemIdQuarantined, this, [this](int id) {
        Vehicle *vehicle = getVehicleById(id);
        if (vehicle) vehicle->vehicleLinkManager()->closeVehicle();
    });
    connect(_idConflicts, &VehicleIdConflictManager::conflictsChanged, this, [this, hadConflict = false]() mutable {
        const bool conflict = _idConflicts->hasConflicts();
        if (conflict && !hadConflict) QGC::showAppMessage(tr("检测到重复飞机编号，第二路已隔离。点击顶部“编号冲突”可自动分配编号。"));
        hadConflict = conflict;
    });
}

MultiVehicleManager::~MultiVehicleManager()
{
    qCDebug(MultiVehicleManagerLog) << this;
}

MultiVehicleManager *MultiVehicleManager::instance()
{
    return _multiVehicleManagerInstance();
}

bool MultiVehicleManager::acceptVehicleIdFrame(LinkInterface *link, const mavlink_message_t &message)
{
    if (!link || !link->isConnected()) return false;
    if (link->isLogReplay()) return true;
    if (!_idWatchedLinks.contains(link)) {
        _idWatchedLinks.insert(link);
        connect(link, &LinkInterface::disconnected, this, [this, link]() {
            _idUsbDetails.remove(link);
            _idConflicts->removeLink(link);
        });
        connect(link, &QObject::destroyed, this, [this, link]() {
            _idWatchedLinks.remove(link);
            _idUsbDetails.remove(link);
            _idConflicts->removeLink(link);
        });
    }
    VehicleIdConflictManager::LinkDetails details;
    details.name = link->linkConfiguration() ? link->linkConfiguration()->name() : tr("未知链路");
    details.channel = link->mavlinkChannel();
#ifndef QGC_NO_SERIAL_LINK
    if (const auto *serial = link->linkConfiguration() ? qobject_cast<SerialConfiguration *>(link->linkConfiguration().get()) : nullptr) {
        details.name = serial->portName();
        if (!_idUsbDetails.contains(link)) {
            bool usb = serial->usbDirect();
            QString identity;
            for (const QGCSerialPortInfo &info : QGCSerialPortInfo::availablePorts()) {
                if (info.portName() != serial->portName() && info.systemLocation() != serial->portName()) continue;
                QGCSerialPortInfo::BoardType_t type;
                QString board;
                usb |= info.getBoardInfo(type, board) && type == QGCSerialPortInfo::BoardTypePixhawk;
                if (!info.serialNumber().isEmpty() && info.serialNumber() != QStringLiteral("0")) identity = info.serialNumber();
                break;
            }
            _idUsbDetails.insert(link, {usb, identity});
        }
        details.directUsb = _idUsbDetails.value(link).first;
        details.usbIdentity = _idUsbDetails.value(link).second;
    }
#endif
    if (message.msgid == MAVLINK_MSG_ID_HEARTBEAT && message.compid == MAV_COMP_ID_AUTOPILOT1) {
        mavlink_heartbeat_t heartbeat{};
        mavlink_msg_heartbeat_decode(&message, &heartbeat);
        FirmwarePlugin *plugin = FirmwarePluginManager::instance()->firmwarePluginForAutopilot(
            static_cast<MAV_AUTOPILOT>(heartbeat.autopilot), static_cast<MAV_TYPE>(heartbeat.type));
        if (plugin) {
            details.parameterNames = plugin->systemIdParameterNames();
            details.numericCast = plugin->systemIdParameterUsesNumericCast();
        }
    }
    _idConflicts->setGroundStationId(MAVLinkProtocol::instance()->getSystemId());
    return _idConflicts->acceptMessage(link, details, message);
}

void MultiVehicleManager::init()
{
    if (_initialized) {
        return;
    }

    _offlineEditingVehicle = new Vehicle(Vehicle::MAV_AUTOPILOT_TRACK, Vehicle::MAV_TYPE_TRACK, this);

    (void) connect(MAVLinkProtocol::instance(), &MAVLinkProtocol::vehicleHeartbeatInfo, this, &MultiVehicleManager::_vehicleHeartbeatInfo);

    _gcsHeartbeatTimer->setInterval(kGCSHeartbeatRateMSecs);
    _gcsHeartbeatTimer->setSingleShot(false);
    (void) connect(_gcsHeartbeatTimer, &QTimer::timeout, this, &MultiVehicleManager::_sendGCSHeartbeat);
    _gcsHeartbeatTimer->start();

    _initialized = true;
}

void MultiVehicleManager::_vehicleHeartbeatInfo(LinkInterface* link, int vehicleId, int componentId, int vehicleFirmwareType, int vehicleType)
{
    if (componentId != MAV_COMP_ID_AUTOPILOT1) {
        // Don't create vehicles for components other than the autopilot
        qCDebug(MultiVehicleManagerLog) << "Ignoring heartbeat from unknown component port:vehicleId:componentId:fwType:vehicleType"
                                        << link->linkConfiguration()->name()
                                        << vehicleId
                                        << componentId
                                        << vehicleFirmwareType
                                        << vehicleType;
        return;
    }

    // When you flash a new ArduCopter it does not set a FRAME_CLASS for some reason. This is the only ArduPilot variant which
    // works this way. Because of this the vehicle type is not known at first connection. In order to make QGC work reasonably
    // we assume ArduCopter for this case.
    if ((vehicleType == MAV_TYPE_GENERIC) && (vehicleFirmwareType == MAV_AUTOPILOT_ARDUPILOTMEGA)) {
        vehicleType = MAV_TYPE_QUADROTOR;
    }

    switch (vehicleType) {
    case MAV_TYPE_GCS:
    case MAV_TYPE_ONBOARD_CONTROLLER:
    case MAV_TYPE_GIMBAL:
    case MAV_TYPE_ADSB:
        // These are not vehicles, so don't create a vehicle for them
        return;
    default:
        break;
    }

    if ((_vehicles->count() > 0) && !QGCCorePlugin::instance()->options()->multiVehicleEnabled()) {
        return;
    }

    if (_ignoreVehicleIds.contains(vehicleId) || getVehicleById(vehicleId) || (vehicleId == 0)) {
        return;
    }

    qCDebug(MultiVehicleManagerLog) << "Adding new vehicle link:vehicleId:componentId:vehicleFirmwareType:vehicleType "
                                    << link->linkConfiguration()->name()
                                    << vehicleId
                                    << componentId
                                    << vehicleFirmwareType
                                    << vehicleType;

    if (vehicleId == MAVLinkProtocol::instance()->getSystemId()) {
        QGC::showAppMessage(tr("Warning: A vehicle is using the same system id as %1: %2").arg(QCoreApplication::applicationName()).arg(vehicleId));
    }

    Vehicle *const vehicle = new Vehicle(link, vehicleId, componentId, (MAV_AUTOPILOT)vehicleFirmwareType, (MAV_TYPE)vehicleType, this);
    (void) connect(vehicle->vehicleLinkManager(), &VehicleLinkManager::allLinksRemoved, this, &MultiVehicleManager::_deleteVehiclePhase1);
    (void) connect(vehicle->parameterManager(), &ParameterManager::parametersReadyChanged, this, &MultiVehicleManager::_vehicleParametersReadyChanged);

    _vehicles->append(vehicle);

    // Send QGC heartbeat ASAP, this allows PX4 to start accepting commands
    _sendGCSHeartbeat();

    SettingsManager::instance()->firmwareUpgradeSettings()->defaultFirmwareType()->setRawValue(vehicleFirmwareType);

    emit vehicleAdded(vehicle);

    if (_vehicles->count() > 1) {
        QGC::showAppMessage(tr("Connected to Vehicle %1").arg(vehicleId));
    } else {
        setActiveVehicle(vehicle);
    }

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    if (_vehicles->count() == 1) {
        qCDebug(MultiVehicleManagerLog) << "keepScreenOn";
        #if defined(Q_OS_ANDROID)
            AndroidInterface::setKeepScreenOn(true);
        #elif defined(Q_OS_IOS)
            MobileScreenMgr::setKeepScreenOn(true);
        #endif
    }
#endif
}

void MultiVehicleManager::_deleteVehiclePhase1(Vehicle *vehicle)
{
    qCDebug(MultiVehicleManagerLog) << Q_FUNC_INFO << vehicle;

    bool found = false;
    for (int i = 0; i < _vehicles->count(); i++) {
        if (_vehicles->get(i) == vehicle) {
            (void) _vehicles->removeAt(i);
            found = true;
            break;
        }
    }

    if (!found) {
        qCWarning(MultiVehicleManagerLog) << "Vehicle not found in map!";
        return;
    }

    deselectVehicle(vehicle->id());



    QGC::showAppMessage(tr("飞行器 %1 已断开，地面站将保持运行。可点击左上角重新连接。").arg(vehicle->id()));

    if (vehicle == _activeVehicle) {
        ++_activeVehicleSwitchRevision;
        _setActiveVehicleAvailable(false);
        _setParameterReadyVehicleAvailable(false);
    }
    emit vehicleRemoved(vehicle);

#if defined(Q_OS_ANDROID) || defined (Q_OS_IOS)
    if (_vehicles->count() == 0) {
        qCDebug(MultiVehicleManagerLog) << "restoreScreenOn";
        #if defined(Q_OS_ANDROID)
            AndroidInterface::setKeepScreenOn(false);
        #elif defined(Q_OS_IOS)
            MobileScreenMgr::setKeepScreenOn(false);
        #endif
    }
#endif

    // We must let the above signals flow through the system as well as get back to the main loop event queue
    // before we can actually delete the Vehicle. The reason is that Qml may be holding on to references to it.
    // Even though the above signals should unload any Qml which has references, that Qml will not be destroyed
    // until we get back to the main loop. So we set a short timer which will then fire after Qt has finished
    // doing all of its internal nastiness to clean up the Qml. This works for both the normal running case
    // as well as the unit testing case which of course has a different signal flow!
    QTimer::singleShot(20, this, [this, vehicle]() {
        _deleteVehiclePhase2(vehicle);
    });
}

void MultiVehicleManager::_deleteVehiclePhase2(Vehicle *vehicle)
{
    qCDebug(MultiVehicleManagerLog) << Q_FUNC_INFO << vehicle;

    /// Qml has been notified of vehicle about to go away and should be disconnected from it by now.
    /// This means we can now clear the active vehicle property and delete the Vehicle for real.

    // Removing a background vehicle must not switch the main debugging target.
    if (vehicle == _activeVehicle) {
        Vehicle *newActiveVehicle = _vehicles->count() > 0 ? qobject_cast<Vehicle*>(_vehicles->get(0)) : nullptr;
        _setActiveVehicle(newActiveVehicle);
    }

    if (_activeVehicle) {
        _setActiveVehicleAvailable(true);
        if (_activeVehicle->parameterManager()->parametersReady()) {
            _setParameterReadyVehicleAvailable(true);
        }
    }

    vehicle->deleteLater();
}

void MultiVehicleManager::setActiveVehicle(Vehicle *vehicle)
{
    qCDebug(MultiVehicleManagerLog) << Q_FUNC_INFO << vehicle;
    if (vehicle && !_vehicles->contains(vehicle)) return;
    // A newer selection cancels older deferred selections, including returning
    // to the current vehicle before a pending switch has completed.
    const auto revision = ++_activeVehicleSwitchRevision;
    if (vehicle != _activeVehicle) {
        if (_activeVehicle) {
            // The sequence of signals is very important in order to not leave Qml elements connected
            // to a non-existent vehicle.

            // First we must signal that there is no active vehicle available. This will disconnect
            // any existing ui from the currently active vehicle.
            _setActiveVehicleAvailable(false);
            _setParameterReadyVehicleAvailable(false);
        }

        const QPointer<Vehicle> target(vehicle);
        const bool clearRequested = !vehicle;
        QTimer::singleShot(20, this, [this, target, revision, clearRequested]() {
            if (revision != _activeVehicleSwitchRevision || (target && !_vehicles->contains(target))) return;
            if (target || clearRequested) _setActiveVehiclePhase2(target);
        });
    } else if (_activeVehicle) {
        _setActiveVehicleAvailable(true);
        _setParameterReadyVehicleAvailable(_activeVehicle->parameterManager()->parametersReady());
    }
}

void MultiVehicleManager::_setActiveVehiclePhase2(Vehicle *vehicle)
{
    qCDebug(MultiVehicleManagerLog) << Q_FUNC_INFO << vehicle;

    _setActiveVehicle(vehicle);

    if (_activeVehicle) {
        _setActiveVehicleAvailable(true);

        if (_activeVehicle->parameterManager()->parametersReady()) {
            _setParameterReadyVehicleAvailable(true);
        }
    }
}

void MultiVehicleManager::_vehicleParametersReadyChanged(bool parametersReady)
{
    ParameterManager *const paramMgr = qobject_cast<ParameterManager*>(sender());
    if (!paramMgr) {
        return;
    }

    if (paramMgr->vehicle() == _activeVehicle) {
        _setParameterReadyVehicleAvailable(parametersReady);
    }
}

void MultiVehicleManager::_sendGCSHeartbeat()
{
    if (!SettingsManager::instance()->mavlinkSettings()->sendGCSHeartbeat()->rawValue().toBool()) {
        return;
    }

    const QList<SharedLinkInterfacePtr> sharedLinks = LinkManager::instance()->links();
    for (const SharedLinkInterfacePtr &link: sharedLinks) {
        if (!link->isConnected()) {
            continue;
        }

        const SharedLinkConfigurationPtr linkConfiguration = link->linkConfiguration();
        if (linkConfiguration->isHighLatency()) {
            continue;
        }

        mavlink_message_t message{};
        (void) mavlink_msg_heartbeat_pack_chan(
            MAVLinkProtocol::instance()->getSystemId(),
            MAVLinkProtocol::instance()->getComponentId(),
            link->mavlinkChannel(),
            &message,
            MAV_TYPE_GCS,
            MAV_AUTOPILOT_INVALID,
            MAV_MODE_MANUAL_ARMED,
            0,
            MAV_STATE_ACTIVE
        );

        link->sendMessageThreadSafe(message);
    }
}

void MultiVehicleManager::selectVehicle(int vehicleId)
{
    if(!_vehicleSelected(vehicleId)) {
        Vehicle *const vehicle = getVehicleById(vehicleId);
        _selectedVehicles->append(vehicle);
        return;
    }
}

void MultiVehicleManager::deselectVehicle(int vehicleId)
{
    for (int i = 0; i < _selectedVehicles->count(); i++) {
        Vehicle *const vehicle = qobject_cast<Vehicle*>(_selectedVehicles->get(i));
        if (vehicle->id() == vehicleId) {
            _selectedVehicles->removeAt(i);
            return;
        }
    }
}

void MultiVehicleManager::deselectAllVehicles()
{
    _selectedVehicles->clear();
}

bool MultiVehicleManager::_vehicleSelected(int vehicleId)
{
    for (int i = 0; i < _selectedVehicles->count(); i++) {
        Vehicle *const vehicle = qobject_cast<Vehicle*>(_selectedVehicles->get(i));
        if (vehicle->id() == vehicleId) {
            return true;
        }
    }
    return false;
}

Vehicle *MultiVehicleManager::getVehicleById(int vehicleId) const
{
    for (int i = 0; i < _vehicles->count(); i++) {
        Vehicle *const vehicle = qobject_cast<Vehicle*>(_vehicles->get(i));
        if (vehicle->id() == vehicleId) {
            return vehicle;
        }
    }

    return nullptr;
}

void MultiVehicleManager::_setActiveVehicle(Vehicle *vehicle)
{
    if (vehicle != _activeVehicle) {
        _activeVehicle = vehicle;
        emit activeVehicleChanged(vehicle);
    }
}

void MultiVehicleManager::_setActiveVehicleAvailable(bool activeVehicleAvailable)
{
    if (activeVehicleAvailable != _activeVehicleAvailable) {
        _activeVehicleAvailable = activeVehicleAvailable;
        emit activeVehicleAvailableChanged(activeVehicleAvailable);
    }
}

void MultiVehicleManager::_setParameterReadyVehicleAvailable(bool parametersReady)
{
    if (parametersReady != _parameterReadyVehicleAvailable) {
        _parameterReadyVehicleAvailable = parametersReady;
        parameterReadyVehicleAvailableChanged(parametersReady);
    }
}
