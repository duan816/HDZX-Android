#include "RebootConnectionManager.h"

#include "LinkInterface.h"
#include "LinkManager.h"
#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "QmlObjectListModel.h"
#include "Vehicle.h"
#include "VehicleIdConflictManager.h"
#include "VehicleLinkManager.h"
#ifndef QGC_NO_SERIAL_LINK
#include "SerialLink.h"
#endif

RebootConnectionManager::RebootConnectionManager(QObject* parent) : QObject(parent)
{
    _timer.setInterval(500);
    connect(&_timer, &QTimer::timeout, this, &RebootConnectionManager::_poll);
}

Vehicle* RebootConnectionManager::progressVehicle() const
{
    return _progressVehicle;
}

void RebootConnectionManager::_setProgressVehicle(Vehicle* vehicle)
{
    if (_progressVehicle == vehicle)
        return;
    disconnect(_progressVehicleDestroyed);
    _progressVehicle = vehicle;
    if (vehicle) {
        _progressVehicleDestroyed = connect(vehicle, &QObject::destroyed, this, [this] {
            _progressVehicle = nullptr;
            emit changed();
        });
    }
    emit changed();
}

void RebootConnectionManager::_update(int stage, const QString& text, bool active)
{
    if (!active && stage != 3)
        _setProgressVehicle(nullptr);
    if (_stage == stage && _status == text && _active == active)
        return;
    _stage = stage;
    _status = text;
    _active = active;
    emit changed();
    if (!active)
        _timer.stop();
}

bool RebootConnectionManager::begin(Vehicle* vehicle)
{
    if (_active || !vehicle || vehicle->armed() || vehicle->flying())
        return false;
    const auto link = vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!link || !link->isConnected())
        return false;
    _configuration = link->linkConfiguration();
    _identity = MultiVehicleManager::instance()->idConflicts()->identityForLink(link.get(), vehicle->id());
    _setProgressVehicle(nullptr);
    _original = vehicle;
    _systemId = vehicle->id();
    _elapsed.restart();
    _lastAttempt = 0;
    _update(0, tr("已请求重启 %1 号机，等待确认与断开").arg(_systemId), true);
    _timer.start();
    return true;
}

void RebootConnectionManager::commandRejected()
{
    _update(4, tr("飞控未确认重启命令，未自动重复发送；请检查连接。"), false);
}

void RebootConnectionManager::cancel()
{
    _update(4, tr("已取消等待；不会撤销已发送的重启命令，也不关闭其他飞机。"), false);
}

void RebootConnectionManager::_poll()
{
    if (!_active)
        return;
    if (_elapsed.elapsed() > 90000) {
        _update(4, tr("等待重连超时，请检查供电与接线；没有再次重启飞控。"), false);
        return;
    }
    if (_original) {
        _setProgressVehicle(nullptr);
        _update(0, tr("等待 %1 号机完成重启并断开旧连接").arg(_systemId), true);
        return;
    }
    // A restart can also apply a pending system-ID change. With a known UID,
    // identify the controller across the whole fleet rather than waiting on the
    // obsolete address. Never substitute a different controller with that ID.
    auto* fleet = MultiVehicleManager::instance();
    Vehicle* vehicle = nullptr;
    if (_identity.isEmpty()) {
        vehicle = fleet->getVehicleById(_systemId);
    } else {
        for (int i = 0; i < fleet->vehicles()->count(); ++i) {
            auto* candidate = qobject_cast<Vehicle*>(fleet->vehicles()->get(i));
            if (!candidate) continue;
            const auto candidateLink = candidate->vehicleLinkManager()->primaryLink().lock();
            if (candidateLink && fleet->idConflicts()->identityForLink(candidateLink.get(), candidate->id()) == _identity) {
                vehicle = candidate;
                break;
            }
        }
    }
    if (vehicle) {
        const auto link = vehicle->vehicleLinkManager()->primaryLink().lock();
        if (!link) {
            _setProgressVehicle(nullptr);
            return;
        }
        const auto identity = fleet->idConflicts()->identityForLink(link.get(), vehicle->id());
        if (_identity.isEmpty()) {
            bool sameEndpoint = link->linkConfiguration() == _configuration;
#ifndef QGC_NO_SERIAL_LINK
            const auto* original = qobject_cast<SerialConfiguration*>(_configuration.get());
            const auto* current = qobject_cast<SerialConfiguration*>(link->linkConfiguration().get());
            sameEndpoint = sameEndpoint || (original && current && original->portName() == current->portName());
#endif
            if (!sameEndpoint) {
                _setProgressVehicle(nullptr);
                _update(1, tr("设备未提供硬件身份，正在等待原连接端口；不会接受其他端口的同编号设备。"), true);
                return;
            }
        }
        if (!_identity.isEmpty() && (identity.isEmpty() || identity != _identity)) {
            _setProgressVehicle(nullptr);
            _update(1, tr("等待原飞控的硬件身份；其他同编号设备不会被当成重连成功。"), true);
            return;
        }
        // Only expose progress after the same identity/endpoint checks used for reconnect success.
        _setProgressVehicle(vehicle);
        if (vehicle->vehicleLinkManager()->communicationLost() || !link->isConnected() ||
            !vehicle->isInitialConnectComplete() || !vehicle->parameterManager()->parametersReady()) {
            _update(2, tr("已收到目标心跳，正在读取参数和状态。"), true);
            return;
        }
        const int previousId = _systemId;
        _systemId = vehicle->id();
        QString status = tr("连接已恢复；设备没有可校验的硬件身份，请核对编号与端口。");
        if (!_identity.isEmpty()) {
            status = previousId == _systemId
                ? tr("%1 号机已自动重连，硬件身份和初始化均已确认。").arg(_systemId)
                : tr("原 %1 号飞控已自动重连（当前编号 %2），硬件身份和初始化均已确认。")
                    .arg(previousId).arg(_systemId);
        }
        _update(3, status, false);
        return;
    }
    _setProgressVehicle(nullptr);
    _update(1, tr("正在等待 %1 号机上线并自动重新连接…").arg(_systemId), true);
    if (_configuration && !_configuration->link() && _elapsed.elapsed() - _lastAttempt >= 2000) {
        _lastAttempt = _elapsed.elapsed();
        // Existing automatic links may already be reconnecting this endpoint.
        for (const auto& link : LinkManager::instance()->links()) {
            if(!link||!link->linkConfiguration())continue;
            if(link->linkConfiguration()==_configuration)return;
#ifndef QGC_NO_SERIAL_LINK
            const auto* original=qobject_cast<SerialConfiguration*>(_configuration.get());
            const auto* current=qobject_cast<SerialConfiguration*>(link->linkConfiguration().get());
            if(original&&current&&original->portName()==current->portName())return;
#endif
        }
        LinkManager::instance()->createConnectedLink(_configuration);
    }
}
