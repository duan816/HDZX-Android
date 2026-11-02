#include "GPSRtk.h"

#include "GPSProvider.h"
#include "GPSRTKFactGroup.h"
#include "GPSType.h"
#include "NTRIPManager.h"
#include "QGCLoggingCategory.h"
#include "RTCMMavlink.h"
#include "RTKSettings.h"
#include "SettingsManager.h"

#include <limits>

QGC_LOGGING_CATEGORY(GPSRtkLog, "GPS.GPSRtk")

namespace {
struct GPSTypeEntry
{
    QLatin1StringView key;
    GPSType type;
    int manufacturerId;  // RTKSettings::baseReceiverManufacturers enum value
};

constexpr GPSTypeEntry kGPSTypeTable[] = {
    {QLatin1StringView("trimble"), GPSType::trimble, 1},
    {QLatin1StringView("septentrio"), GPSType::septentrio, 2},
    {QLatin1StringView("femtomes"), GPSType::femto, 3},
    {QLatin1StringView("blox"), GPSType::u_blox, 4},
    {QLatin1StringView("um982"), GPSType::unicore, 5},
    {QLatin1StringView("unicore"), GPSType::unicore, 5},
};
}  // namespace

GPSRtk::GPSRtk(QObject* parent) : QObject(parent), _gpsRtkFactGroup(new GPSRTKFactGroup(this))
{
    qCDebug(GPSRtkLog) << this;

    (void) qRegisterMetaType<satellite_info_s>("satellite_info_s");
    (void) qRegisterMetaType<sensor_gps_s>("sensor_gps_s");
    (void) qRegisterMetaType<GPSConnectionError>("GPSConnectionError");
    (void) qRegisterMetaType<GPSSurveyInStatus>("GPSSurveyInStatus");
    _gpsRtkFactGroup->connected()->setSendValueChangedSignals(true);
    _gpsRtkFactGroup->connecting()->setSendValueChangedSignals(true);
}

GPSRtk::~GPSRtk()
{
    disconnectGPS();

    qCDebug(GPSRtkLog) << this;
}

void GPSRtk::_onGPSConnect()
{
    if (sender() != _gpsProvider) { return; }
    _gpsRtkFactGroup->connecting()->setRawValue(false);
    _gpsRtkFactGroup->connected()->setRawValue(true);
}

void GPSRtk::_onGPSDisconnect()
{
    _gpsRtkFactGroup->connecting()->setRawValue(false);
    _gpsRtkFactGroup->connected()->setRawValue(false);
    _gpsRtkFactGroup->setSatelliteBars({});
    _gpsRtkFactGroup->streamBytesPerSec()->setRawValue(0.0);
}

void GPSRtk::_onGPSConnectionError(GPSConnectionError error)
{
    if (sender() != _gpsProvider) { return; }
    switch (error) {
        case GPSConnectionError::OpenFailed:
            qCWarning(GPSRtkLog) << "Failed to open GPS serial device";
            break;
        case GPSConnectionError::ConfigFailed:
            qCWarning(GPSRtkLog) << "GPS receiver did not accept configuration";
            break;
        case GPSConnectionError::DeviceError:
            qCWarning(GPSRtkLog) << "GPS device error, connection lost";
            break;
        case GPSConnectionError::None:
            break;
    }

    _gpsRtkFactGroup->lastError()->setRawValue(static_cast<int>(error));
}

void GPSRtk::_onGPSSurveyInStatus(const GPSSurveyInStatus& status)
{
    if (sender() != _gpsProvider) { return; }
    _gpsRtkFactGroup->currentDuration()->setRawValue(status.durationSecs);
    _gpsRtkFactGroup->currentAccuracy()->setRawValue(static_cast<double>(status.meanAccuracyMM) / 1000.0);
    _gpsRtkFactGroup->currentLatitude()->setRawValue(status.latitude);
    _gpsRtkFactGroup->currentLongitude()->setRawValue(status.longitude);
    _gpsRtkFactGroup->currentAltitude()->setRawValue(status.altitude);
    _gpsRtkFactGroup->valid()->setRawValue(status.valid);
    _gpsRtkFactGroup->active()->setRawValue(status.active);
}

void GPSRtk::_onRTCMStreamStatus(quint64 totalBytes, quint64 validFrames, quint64 invalidFrames, int lastMessageId, double bytesPerSecond)
{
    if (sender() != _gpsProvider) { return; }
    _gpsRtkFactGroup->streamBytes()->setRawValue(static_cast<quint32>(qMin<quint64>(totalBytes, std::numeric_limits<quint32>::max())));
    _gpsRtkFactGroup->rtcmFrames()->setRawValue(static_cast<quint32>(qMin<quint64>(validFrames, std::numeric_limits<quint32>::max())));
    _gpsRtkFactGroup->invalidRtcmFrames()->setRawValue(static_cast<quint32>(qMin<quint64>(invalidFrames, std::numeric_limits<quint32>::max())));
    _gpsRtkFactGroup->lastRtcmMessageId()->setRawValue(lastMessageId);
    _gpsRtkFactGroup->streamBytesPerSec()->setRawValue(bytesPerSecond);
}

void GPSRtk::connectGPS(const QString& device, QStringView gps_type, bool configureReceiver, unsigned directBaudRate)
{
    RTKSettings* const rtkSettings = SettingsManager::instance()->rtkSettings();

    GPSType type = GPSType::u_blox;
    int manufacturerId = 4;  // u-blox by default
    for (const GPSTypeEntry& entry : kGPSTypeTable) {
        if (gps_type.contains(entry.key, Qt::CaseInsensitive)) {
            type = entry.type;
            manufacturerId = entry.manufacturerId;
            break;
        }
    }
    rtkSettings->baseReceiverManufacturers()->setRawValue(manufacturerId);
    qCDebug(GPSRtkLog) << "Connecting GPS device" << gps_type << "manufacturer id" << manufacturerId
                       << "configure receiver" << configureReceiver << "direct baud" << directBaudRate;

    disconnectGPS();

    _requestGpsStop = std::make_shared<std::atomic_bool>(false);
    _gpsRtkFactGroup->connecting()->setRawValue(true);
    _gpsRtkFactGroup->lastError()->setRawValue(static_cast<int>(GPSConnectionError::None));
    _gpsRtkFactGroup->streamBytes()->setRawValue(0);
    _gpsRtkFactGroup->rtcmFrames()->setRawValue(0);
    _gpsRtkFactGroup->invalidRtcmFrames()->setRawValue(0);
    _gpsRtkFactGroup->lastRtcmMessageId()->setRawValue(0);
    _gpsRtkFactGroup->streamBytesPerSec()->setRawValue(0.0);
    _gpsRtkFactGroup->setSatelliteBars({});
    _gpsRtkFactGroup->numSatellites()->setRawValue(0);
    _gpsRtkFactGroup->numSatellitesUsed()->setRawValue(0);
    _gpsRtkFactGroup->valid()->setRawValue(false);
    _gpsRtkFactGroup->active()->setRawValue(false);
    _gpsRtkFactGroup->currentDuration()->setRawValue(0);
    _gpsRtkFactGroup->currentAccuracy()->setRawValue(0.0);
    const bool useFixedBase =
        static_cast<BaseModeDefinition::Mode>(rtkSettings->useFixedBasePosition()->rawValue().toInt()) ==
        BaseModeDefinition::Mode::BaseFixed;
    const GPSReceiverConfig rtkConfig = {
        .useFixedBase = useFixedBase,
        .surveyInAccMeters = rtkSettings->surveyInAccuracyLimit()->rawValue().toDouble(),
        .surveyInDurationSecs = rtkSettings->surveyInMinObservationDuration()->rawValue().toInt(),
        .fixedBaseLatitude = rtkSettings->fixedBasePositionLatitude()->rawValue().toDouble(),
        .fixedBaseLongitude = rtkSettings->fixedBasePositionLongitude()->rawValue().toDouble(),
        .fixedBaseAltitudeMeters = rtkSettings->fixedBasePositionAltitude()->rawValue().toFloat(),
        .fixedBaseAccuracyMeters = rtkSettings->fixedBasePositionAccuracy()->rawValue().toFloat(),
    };
    _gpsProvider = new GPSProvider(device, type, rtkConfig, configureReceiver, directBaudRate, _requestGpsStop, this);
    // Forward serial-RTK corrections through NTRIPManager's shared RTCMMavlink so
    // serial and NTRIP sources share one GPS_RTCM_DATA sequence-id domain.
    RTCMMavlink* const rtcmMavlink = NTRIPManager::instance()->rtcmMavlink();
    if (rtcmMavlink) {
        (void) connect(_gpsProvider, &GPSProvider::RTCMDataUpdate, rtcmMavlink, &RTCMMavlink::RTCMDataUpdate);
    } else {
        qCWarning(GPSRtkLog) << "Shared RTCMMavlink unavailable; serial RTK corrections will not be forwarded";
    }
    (void) connect(_gpsProvider, &GPSProvider::satelliteInfoUpdate, this, &GPSRtk::_satelliteInfoUpdate);
    (void) connect(_gpsProvider, &GPSProvider::rawSatelliteBarsUpdate, this, &GPSRtk::_rawSatelliteBarsUpdate);
    (void) connect(_gpsProvider, &GPSProvider::sensorGpsUpdate, this, &GPSRtk::_sensorGpsUpdate);
    (void) connect(_gpsProvider, &GPSProvider::surveyInStatus, this, &GPSRtk::_onGPSSurveyInStatus);
    (void) connect(_gpsProvider, &GPSProvider::rtcmStreamStatus, this, &GPSRtk::_onRTCMStreamStatus);
    (void) connect(_gpsProvider, &GPSProvider::connectionError, this, &GPSRtk::_onGPSConnectionError);
    (void) connect(_gpsProvider, &GPSProvider::transportOpened, this, &GPSRtk::_onGPSConnect);
    (void) connect(_gpsProvider, &GPSProvider::receiverConfigured, this, [this, connectionId = _connectionId]() {
        if (connectionId == _connectionId) {
            _gpsRtkFactGroup->lastError()->setRawValue(static_cast<int>(GPSConnectionError::None));
        }
    });
    (void) connect(_gpsProvider, &GPSProvider::finished, this, [this, connectionId = _connectionId]() {
        // disconnect() cannot retract events that were already queued before a reconnect.
        if (connectionId == _connectionId) { _onGPSDisconnect(); }
    });

    // Start the thread only after every signal is wired, so no early emission is lost.
    (void) QMetaObject::invokeMethod(_gpsProvider, "start", Qt::AutoConnection);
}

void GPSRtk::disconnectGPS()
{
    ++_connectionId;
    if (_gpsProvider) {
        _requestGpsStop->store(true, std::memory_order_relaxed);
        (void) _gpsProvider->disconnect(this);
        if (_gpsProvider->wait(kGPSThreadDisconnectTimeout)) {
            _gpsProvider->deleteLater();
            _gpsProvider = nullptr;
        } else {
            qCWarning(GPSRtkLog) << "GPS thread did not exit in time; deferring cleanup to finished()";
            _gpsProvider->setParent(nullptr);
            (void) connect(_gpsProvider, &QThread::finished, _gpsProvider, &QObject::deleteLater);
            // The stop token is owned by the worker, even after GPSRtk is destroyed.
            if (_gpsProvider->isFinished()) { _gpsProvider->deleteLater(); }
        }
        _gpsProvider = nullptr;
    }
    _onGPSDisconnect();
    _gpsRtkFactGroup->setSatelliteBars({});
}

bool GPSRtk::connected() const
{
    return (_gpsProvider ? _gpsProvider->isRunning() : false);
}

FactGroup* GPSRtk::gpsRtkFactGroup()
{
    return _gpsRtkFactGroup;
}

GPSRtk::SatelliteCounts GPSRtk::countSatellites(const satellite_info_s& msg)
{
    SatelliteCounts counts;
    counts.inView = qMin(msg.count, satellite_info_s::SAT_INFO_MAX_SATELLITES);
    for (uint8_t i = 0; i < counts.inView; ++i) {
        if (msg.used[i]) {
            ++counts.used;
        }
    }
    return counts;
}

void GPSRtk::_satelliteInfoUpdate(const satellite_info_s& msg)
{
    if (sender() != _gpsProvider) { return; }
    const SatelliteCounts counts = countSatellites(msg);
    qCDebug(GPSRtkLog) << Q_FUNC_INFO << QStringLiteral("%1 in view, %2 used").arg(counts.inView).arg(counts.used);
    _gpsRtkFactGroup->numSatellites()->setRawValue(counts.inView);
    _gpsRtkFactGroup->numSatellitesUsed()->setRawValue(counts.used);

    QVariantList bars;
    bars.reserve(counts.inView);
    for (uint8_t i = 0; i < counts.inView; ++i) {
        QVariantMap bar;
        bar.insert(QStringLiteral("id"), msg.svid[i]);
        bar.insert(QStringLiteral("snr"), msg.snr[i]);
        bar.insert(QStringLiteral("elevation"), msg.elevation[i]);
        bar.insert(QStringLiteral("azimuth"), static_cast<int>(msg.azimuth[i]) * 2);
        bar.insert(QStringLiteral("used"), msg.used[i] != 0);
        bars.append(bar);
    }
    _gpsRtkFactGroup->setSatelliteBars(bars);
}

void GPSRtk::_rawSatelliteBarsUpdate(const QVariantList &bars)
{
    if (sender() != _gpsProvider) { return; }
    _gpsRtkFactGroup->numSatellites()->setRawValue(bars.size());
    _gpsRtkFactGroup->setSatelliteBars(bars);
}

void GPSRtk::_sensorGpsUpdate(const sensor_gps_s& msg)
{
    if (sender() != _gpsProvider) { return; }
    qCDebug(GPSRtkLog) << Q_FUNC_INFO
                       << QStringLiteral("alt=%1, long=%2, lat=%3")
                              .arg(msg.altitude_msl_m)
                              .arg(msg.longitude_deg)
                              .arg(msg.latitude_deg);
}
