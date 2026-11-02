#pragma once

#include "GPSDriver.h"  // facade; also publishes GPSReceiverConfig + the GNSS data structs relayed below
#include "GPSType.h"

#include <QtCore/QByteArray>
#include <QtCore/QMetaType>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QThread>
#include <QtCore/QVariantList>

#include <atomic>
#include <cstdint>
#include <memory>

class SerialGPSTransport;

enum class GPSConnectionError
{
    None,
    OpenFailed,   ///< serial device could not be opened
    ConfigFailed, ///< receiver did not accept configuration
    DeviceError,  ///< fatal serial error after a working connection
};
Q_DECLARE_METATYPE(GPSConnectionError)

class GPSProvider : public QThread
{
    Q_OBJECT

public:
    GPSProvider(const QString &device, GPSType type, const GPSReceiverConfig &config, bool configureReceiver,
                unsigned directBaudRate, std::shared_ptr<std::atomic_bool> requestStop, QObject *parent = nullptr);

signals:
    void transportOpened();
    void receiverConfigured();
    void satelliteInfoUpdate(const satellite_info_s &message);
    void rawSatelliteBarsUpdate(const QVariantList &bars);
    void sensorGpsUpdate(const sensor_gps_s &message);
    void RTCMDataUpdate(const QByteArray &message);
    void surveyInStatus(const GPSSurveyInStatus &status);
    void rtcmStreamStatus(quint64 totalBytes, quint64 validFrames, quint64 invalidFrames, int lastMessageId, double bytesPerSecond);
    void connectionError(GPSConnectionError error);

private:
    void run() final;
    bool _configureUnicore(SerialGPSTransport &transport);
    void _runRawStream(SerialGPSTransport &transport);

    QString _device;
    GPSType _type;
    const std::shared_ptr<std::atomic_bool> _stopOwner;
    const std::atomic_bool &_requestStop;
    GPSReceiverConfig _config{};
    bool _configureReceiver = true;
    unsigned _directBaudRate = 115200;

    static constexpr uint32_t kGPSReceiveTimeout = 1200;
    static constexpr uint32_t kConfigRetryDelayMs = 500;
    static constexpr uint8_t kMaxIdleReceiveCycles = 3;
};
