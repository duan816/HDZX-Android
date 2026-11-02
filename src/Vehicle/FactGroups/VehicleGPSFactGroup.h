#pragma once

#include "FactGroup.h"

#include <QtCore/QElapsedTimer>

class VehicleGPSFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(int fixType READ fixType NOTIFY fixTypeReceived)
    Q_PROPERTY(Fact *lat                    READ lat                    CONSTANT)
    Q_PROPERTY(Fact *lon                    READ lon                    CONSTANT)
    Q_PROPERTY(Fact *mgrs                   READ mgrs                   CONSTANT)
    Q_PROPERTY(Fact *hdop                   READ hdop                   CONSTANT)
    Q_PROPERTY(Fact *vdop                   READ vdop                   CONSTANT)
    Q_PROPERTY(Fact *hAcc                   READ hAcc                   CONSTANT)
    Q_PROPERTY(Fact *vAcc                   READ vAcc                   CONSTANT)
    Q_PROPERTY(Fact *altitudeEllipsoid      READ altitudeEllipsoid      CONSTANT)
    Q_PROPERTY(Fact *courseOverGround       READ courseOverGround       CONSTANT)
    Q_PROPERTY(Fact *yaw                    READ yaw                    CONSTANT)
    Q_PROPERTY(Fact *count                  READ count                  CONSTANT)
    Q_PROPERTY(Fact *lock                   READ lock                   CONSTANT)
    Q_PROPERTY(Fact* systemErrors           READ systemErrors           CONSTANT)
    Q_PROPERTY(Fact* spoofingState          READ spoofingState          CONSTANT)
    Q_PROPERTY(Fact* jammingState           READ jammingState           CONSTANT)
    Q_PROPERTY(Fact* authenticationState    READ authenticationState    CONSTANT)
    Q_PROPERTY(Fact* correctionsQuality     READ correctionsQuality     CONSTANT)
    Q_PROPERTY(Fact* systemQuality          READ systemQuality          CONSTANT)
    Q_PROPERTY(Fact* gnssSignalQuality      READ gnssSignalQuality      CONSTANT)
    Q_PROPERTY(Fact* postProcessingQuality  READ postProcessingQuality  CONSTANT)
    Q_PROPERTY(Fact* gpsSatellites          READ gpsSatellites          CONSTANT)
    Q_PROPERTY(Fact* bdsSatellites          READ bdsSatellites          CONSTANT)
    Q_PROPERTY(Fact* galileoSatellites      READ galileoSatellites      CONSTANT)
    Q_PROPERTY(Fact* glonassSatellites      READ glonassSatellites      CONSTANT)
    Q_PROPERTY(Fact* rtkBaselineDistance    READ rtkBaselineDistance    CONSTANT)
    Q_PROPERTY(Fact* rtkRate                READ rtkRate                CONSTANT)
    Q_PROPERTY(Fact* rtkMessageAge          READ rtkMessageAge          CONSTANT)

public:
    explicit VehicleGPSFactGroup(QObject *parent = nullptr);

    int fixType() const { return _lockFact.rawValue().toInt(); }
    Fact *lat() { return &_latFact; }
    Fact *lon() { return &_lonFact; }
    Fact *mgrs() { return &_mgrsFact; }
    Fact *hdop() { return &_hdopFact; }
    Fact *vdop() { return &_vdopFact; }
    Fact *hAcc() { return &_hAccFact; }
    Fact *vAcc() { return &_vAccFact; }
    Fact *altitudeEllipsoid() { return &_altitudeEllipsoidFact; }
    Fact *courseOverGround() { return &_courseOverGroundFact; }
    Fact *yaw() { return &_yawFact; }
    Fact *count() { return &_countFact; }
    Fact *lock() { return &_lockFact; }
    Fact *systemErrors() { return &_systemErrorsFact; }
    Fact *spoofingState() { return &_spoofingStateFact; }
    Fact *jammingState() { return &_jammingStateFact; }
    Fact *authenticationState() { return &_authenticationStateFact; }
    Fact *correctionsQuality() { return &_correctionsQualityFact; }
    Fact *systemQuality() { return &_systemQualityFact; }
    Fact *gnssSignalQuality() { return &_gnssSignalQualityFact; }
    Fact *postProcessingQuality() { return &_postProcessingQualityFact; }
    Fact *gpsSatellites()         { return &_gpsSatellitesFact; }
    Fact *bdsSatellites()         { return &_bdsSatellitesFact; }
    Fact *galileoSatellites()     { return &_galileoSatellitesFact; }
    Fact *glonassSatellites()     { return &_glonassSatellitesFact; }
    Fact *rtkBaselineDistance()   { return &_rtkBaselineDistanceFact; }
    Fact *rtkRate()               { return &_rtkRateFact; }
    Fact *rtkMessageAge()         { return &_rtkMessageAgeFact; }

    // Overrides from FactGroup
    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) override;

signals:
    void gnssIntegrityReceived();
    void fixTypeReceived(int fix);

protected:
    void _handleGpsRawInt(const mavlink_message_t &message);
    void _handleHighLatency(const mavlink_message_t &message);
    void _handleHighLatency2(const mavlink_message_t &message);
    void _handleGnssIntegrity(const mavlink_message_t& message);
    void _handleGpsStatus(const mavlink_message_t& message);
    void _handleGpsRtk(const mavlink_message_t& message);
    void _updateAllValues() final;

    Fact _latFact = Fact(0, QStringLiteral("lat"), FactMetaData::valueTypeDouble);
    Fact _lonFact = Fact(0, QStringLiteral("lon"), FactMetaData::valueTypeDouble);
    Fact _mgrsFact = Fact(0, QStringLiteral("mgrs"), FactMetaData::valueTypeString);
    Fact _hdopFact = Fact(0, QStringLiteral("hdop"), FactMetaData::valueTypeDouble);
    Fact _vdopFact = Fact(0, QStringLiteral("vdop"), FactMetaData::valueTypeDouble);
    Fact _hAccFact = Fact(0, QStringLiteral("hAcc"), FactMetaData::valueTypeDouble);
    Fact _vAccFact = Fact(0, QStringLiteral("vAcc"), FactMetaData::valueTypeDouble);
    Fact _altitudeEllipsoidFact = Fact(0, QStringLiteral("altitudeEllipsoid"), FactMetaData::valueTypeDouble);
    Fact _courseOverGroundFact = Fact(0, QStringLiteral("courseOverGround"), FactMetaData::valueTypeDouble);
    Fact _yawFact = Fact(0, QStringLiteral("yaw"), FactMetaData::valueTypeDouble);
    Fact _countFact = Fact(0, QStringLiteral("count"), FactMetaData::valueTypeInt32);
    Fact _lockFact = Fact(0, QStringLiteral("lock"), FactMetaData::valueTypeInt32);
    Fact _systemErrorsFact = Fact(0, QStringLiteral("systemErrors"), FactMetaData::valueTypeUint32);
    Fact _spoofingStateFact = Fact(0, QStringLiteral("spoofingState"), FactMetaData::valueTypeUint8);
    Fact _jammingStateFact = Fact(0, QStringLiteral("jammingState"), FactMetaData::valueTypeUint8);
    Fact _authenticationStateFact = Fact(0, QStringLiteral("authenticationState"), FactMetaData::valueTypeUint8);
    Fact _correctionsQualityFact = Fact(0, QStringLiteral("correctionsQuality"), FactMetaData::valueTypeUint8);
    Fact _systemQualityFact = Fact(0, QStringLiteral("systemQuality"), FactMetaData::valueTypeUint8);
    Fact _gnssSignalQualityFact = Fact(0, QStringLiteral("gnssSignalQuality"), FactMetaData::valueTypeUint8);
    Fact _postProcessingQualityFact = Fact(0, QStringLiteral("postProcessingQuality"), FactMetaData::valueTypeUint8);
    Fact _gpsSatellitesFact = Fact(0, QStringLiteral("gpsSatellites"), FactMetaData::valueTypeInt32);
    Fact _bdsSatellitesFact = Fact(0, QStringLiteral("bdsSatellites"), FactMetaData::valueTypeInt32);
    Fact _galileoSatellitesFact = Fact(0, QStringLiteral("galileoSatellites"), FactMetaData::valueTypeInt32);
    Fact _glonassSatellitesFact = Fact(0, QStringLiteral("glonassSatellites"), FactMetaData::valueTypeInt32);
    Fact _rtkBaselineDistanceFact = Fact(0, QStringLiteral("rtkBaselineDistance"), FactMetaData::valueTypeDouble);
    Fact _rtkRateFact = Fact(0, QStringLiteral("rtkRate"), FactMetaData::valueTypeDouble);
    Fact _rtkMessageAgeFact = Fact(0, QStringLiteral("rtkMessageAge"), FactMetaData::valueTypeDouble);

    uint8_t _gnssIntegrityId {};
    QElapsedTimer _lastRtkMessageTimer;
};
