#include "GPSProvider.h"

#include "GPSDriver.h"
#include "QGCLoggingCategory.h"
#include "RTCMParser.h"
#include "RTCMMavlink.h"
#include "SerialGPSTransport.h"

#include <QtCore/QElapsedTimer>
#include <QtCore/QHash>
#include <QtCore/QMap>
#include <QtCore/QStringList>
#include <QtCore/QVector>

#include <cstring>
#include <utility>

QGC_LOGGING_CATEGORY(GPSProviderLog, "GPS.GPSProvider")

namespace {
struct SatelliteSample
{
    int id = 0;
    int elevation = 0;
    int azimuth = 0;
    int snr = 0;
};

bool checksumValid(const QByteArray &sentence)
{
    const int star = sentence.indexOf('*');
    if ((sentence.size() < 7) || (sentence[0] != '$') || (star < 0) || (star + 2 >= sentence.size())) {
        return false;
    }
    uint8_t checksum = 0;
    for (int i = 1; i < star; ++i) {
        checksum ^= static_cast<uint8_t>(sentence[i]);
    }
    bool ok = false;
    const int expected = sentence.mid(star + 1, 2).toInt(&ok, 16);
    return ok && (checksum == expected);
}
} // namespace

GPSProvider::GPSProvider(const QString &device, GPSType type, const GPSReceiverConfig &config, bool configureReceiver,
                         unsigned directBaudRate, std::shared_ptr<std::atomic_bool> requestStop, QObject *parent)
    : QThread(parent)
    , _device(device)
    , _type(type)
    , _stopOwner(requestStop ? std::move(requestStop) : std::make_shared<std::atomic_bool>(false))
    , _requestStop(*_stopOwner)
    , _config(config)
    , _configureReceiver(configureReceiver)
    , _directBaudRate(directBaudRate)
{
    qCDebug(GPSProviderLog) << QStringLiteral("Survey in accuracy: %1 | duration: %2").arg(_config.surveyInAccMeters).arg(_config.surveyInDurationSecs);
}

void GPSProvider::run()
{
#ifdef SIMULATE_RTCM_OUTPUT
    RTCMMavlink rtcm;
    rtcm.sendSimulatedData(_requestStop);
    return;
#endif

    SerialGPSTransport transport(_device, _requestStop);
    if (!transport.open()) {
        if (!_requestStop) {
            emit connectionError(GPSConnectionError::OpenFailed);
        }
        return;
    }

    if (_requestStop) {
        return;
    }
    emit transportOpened();

    if (!_configureReceiver) {
        if (!transport.setBaudrate(_directBaudRate)) {
            emit connectionError(GPSConnectionError::ConfigFailed);
            return;
        }
        emit receiverConfigured();
        _runRawStream(transport);
        qCDebug(GPSProviderLog) << "Exiting generic direct-connect RTCM thread";
        return;
    }

    if (_type == GPSType::unicore) {
        if (!_configureUnicore(transport)) {
            if (!_requestStop) {
                emit connectionError(GPSConnectionError::ConfigFailed);
            }
            return;
        }
        emit receiverConfigured();
        _runRawStream(transport);
        qCDebug(GPSProviderLog) << "Exiting Unicore base-station thread";
        return;
    }

    bool gotData = false;
    GPSDriverSinks sinks;
    sinks.onPosition = [this](const sensor_gps_s &message) { emit sensorGpsUpdate(message); };
    sinks.onSatelliteInfo = [this](const satellite_info_s &message) { emit satelliteInfoUpdate(message); };
    sinks.onRTCM = [this, &gotData](const QByteArray &message) {
        gotData = true;
        emit RTCMDataUpdate(message);
    };
    sinks.onSurveyIn = [this, &gotData](const GPSSurveyInStatus &status) {
        gotData = true;
        qCDebug(GPSProviderLog) << QStringLiteral("Survey-in: %1s accuracy: %2mm valid: %3 active: %4")
                                       .arg(status.durationSecs).arg(status.meanAccuracyMM).arg(status.valid).arg(status.active);
        emit surveyInStatus(status);
    };

    GPSDriver driver(_type, transport, _config, std::move(sinks));

    bool configErrorReported = false;
    while (!_requestStop) {
        if (!driver.configure()) {
            if (_requestStop) {
                break; // disconnect aborted configure mid-flight; not a real failure
            }
            if (transport.fatalError()) {
                emit connectionError(GPSConnectionError::DeviceError);
                break;
            }
            if (!configErrorReported) {
                emit connectionError(GPSConnectionError::ConfigFailed);
                configErrorReported = true;
            }
            msleep(kConfigRetryDelayMs);
            continue;
        }
        configErrorReported = false;
        emit receiverConfigured();

        uint8_t idleCycles = 0;
        while (!_requestStop && (idleCycles < kMaxIdleReceiveCycles)) {
            gotData = false;
            const int ret = driver.receive(kGPSReceiveTimeout);
            const bool progress = (ret > 0) || gotData; // position/sat (ret) or RTCM/survey-in (sinks)
            idleCycles = progress ? 0 : (idleCycles + 1);
        }

        if (transport.fatalError()) {
            emit connectionError(GPSConnectionError::DeviceError);
            break;
        }
    }

    qCDebug(GPSProviderLog) << "Exiting GPS thread";
}

bool GPSProvider::_configureUnicore(SerialGPSTransport &transport)
{
    if (!transport.setBaudrate(115200U)) {
        return false;
    }

    static constexpr const char *commands[] = {
        "GPGGA COM3 1\r\n",
        "GPGSV COM3 1\r\n",
        "mode base time 60 2 2.5\r\n",
        "rtcm1006 com3 1\r\n",
        "rtcm1033 com3 1\r\n",
        "rtcm1074 com3 1\r\n",
        "rtcm1124 com3 1\r\n",
        "rtcm1084 com3 1\r\n",
        "rtcm1094 com3 1\r\n",
        "saveconfig\r\n",
    };

    for (const char *command : commands) {
        if (_requestStop) {
            return false;
        }
        const int length = static_cast<int>(std::strlen(command));
        if (transport.write(reinterpret_cast<const uint8_t *>(command), length) != length) {
            qCWarning(GPSProviderLog) << "Failed to send Unicore base command" << command;
            return false;
        }
        QThread::msleep(80);
    }
    return true;
}

void GPSProvider::_runRawStream(SerialGPSTransport &transport)
{
    RTCMParser rtcmParser;
    QByteArray nmeaSentence;
    QHash<QString, QVector<SatelliteSample>> assemblingSatellites;
    QHash<QString, QVector<SatelliteSample>> completedSatellites;
    QHash<QString, int> lastGsvPart;
    QHash<QString, qint64> lastGsvUpdate;
    QElapsedTimer satelliteTimer;
    satelliteTimer.start();
    quint64 totalBytes = 0;
    quint64 validFrames = 0;
    quint64 invalidFrames = 0;
    quint64 windowBytes = 0;
    int lastMessageId = 0;
    QElapsedTimer rateTimer;
    rateTimer.start();

    auto publishSatellites = [this, &completedSatellites]() {
        QMap<QString, QVariantMap> unique;
        for (auto it = completedSatellites.cbegin(); it != completedSatellites.cend(); ++it) {
            for (const SatelliteSample &satellite : it.value()) {
                const QString id = it.key().section(':', 0, 0) + QString::number(satellite.id);
                // Multiple signal IDs for one satellite: show its strongest reported C/N0.
                if (!unique.contains(id) || unique[id].value("snr").toInt() < satellite.snr) {
                    unique[id] = {{"id", id}, {"snr", qBound(0, satellite.snr, 99)},
                        {"elevation", satellite.elevation}, {"azimuth", satellite.azimuth}, {"used", false}};
                }
            }
        }
        QVariantList bars;
        for (const auto &bar : unique) {
            if (bars.size() >= satellite_info_s::SAT_INFO_MAX_SATELLITES) { break; }
            bars.append(bar);
        }
        emit rawSatelliteBarsUpdate(bars); // Empty complete GSV cycles clear old bars too.
    };

    auto processNmea = [&assemblingSatellites, &completedSatellites, &publishSatellites,
                        &lastGsvPart, &lastGsvUpdate, &satelliteTimer](const QByteArray &sentence) {
        if (!checksumValid(sentence)) {
            return;
        }
        const int star = sentence.indexOf('*');
        const QList<QByteArray> fields = sentence.mid(1, star - 1).split(',');
        if ((fields.size() < 4) || !fields[0].endsWith("GSV")) {
            return;
        }
        bool okTotal = false;
        bool okNumber = false;
        const int totalMessages = fields[1].toInt(&okTotal);
        const int messageNumber = fields[2].toInt(&okNumber);
        if (!okTotal || !okNumber || (messageNumber < 1) || (totalMessages < messageNumber) || totalMessages > 64) {
            return;
        }
        const QString talker = QString::fromLatin1(fields[0].left(2))
            + (((fields.size() - 4) % 4 == 1) ? ':' + QString::fromLatin1(fields.last()) : QString());
        if (!lastGsvPart.contains(talker) && lastGsvPart.size() >= 32) { return; }
        if (messageNumber == 1) {
            assemblingSatellites[talker].clear();
        } else if (lastGsvPart.value(talker, 0) != messageNumber - 1) {
            return; // Do not combine missing/out-of-order multipart cycles.
        }
        lastGsvPart[talker] = messageNumber;
        QVector<SatelliteSample> &satellites = assemblingSatellites[talker];
        for (int i = 4; (i + 3) < fields.size(); i += 4) {
            bool okId = false;
            const int id = fields[i].toInt(&okId);
            if (!okId || id <= 0 || satellites.size() >= 256) {
                continue;
            }
            satellites.append({id, fields[i + 1].toInt(), fields[i + 2].toInt(), fields[i + 3].toInt()});
        }
        if (messageNumber == totalMessages) {
            completedSatellites[talker] = satellites;
            lastGsvUpdate[talker] = satelliteTimer.elapsed();
            publishSatellites();
        }
    };

    uint8_t buffer[4096];
    while (!_requestStop) {
        const int count = transport.read(buffer, static_cast<int>(sizeof(buffer)), 250);
        if (count < 0) {
            if (!_requestStop) {
                emit connectionError(GPSConnectionError::DeviceError);
            }
            break;
        }
        if (count > 0) {
            totalBytes += static_cast<quint64>(count);
            windowBytes += static_cast<quint64>(count);
            for (int i = 0; i < count; ++i) {
                const uint8_t byte = buffer[i];
                if (rtcmParser.addByte(byte)) {
                    if (rtcmParser.validateCrc()) {
                        ++validFrames;
                        lastMessageId = rtcmParser.messageId();
                        emit RTCMDataUpdate(rtcmParser.currentFrame());
                    } else {
                        ++invalidFrames;
                    }
                    rtcmParser.reset();
                }

                if (byte == '$') {
                    nmeaSentence.clear();
                    nmeaSentence.append('$');
                } else if (!nmeaSentence.isEmpty()) {
                    if (nmeaSentence.size() < 512) {
                        nmeaSentence.append(static_cast<char>(byte));
                    }
                    if (byte == '\n') {
                        processNmea(nmeaSentence.trimmed());
                        nmeaSentence.clear();
                    }
                }
            }
        }

        const qint64 elapsedMs = rateTimer.elapsed();
        if (elapsedMs >= 1000) {
            bool expired = false;
            for (auto it = lastGsvUpdate.begin(); it != lastGsvUpdate.end();) {
                if (satelliteTimer.elapsed() - it.value() > 10000) {
                    completedSatellites.remove(it.key());
                    it = lastGsvUpdate.erase(it);
                    expired = true;
                } else { ++it; }
            }
            if (expired) { publishSatellites(); }
            const double bytesPerSecond = (static_cast<double>(windowBytes) * 1000.0) / static_cast<double>(elapsedMs);
            emit rtcmStreamStatus(totalBytes, validFrames, invalidFrames, lastMessageId, bytesPerSecond);
            windowBytes = 0;
            rateTimer.restart();
        }

        if (transport.fatalError()) {
            emit connectionError(GPSConnectionError::DeviceError);
            break;
        }
    }
}
