#pragma once

#include "FactGroup.h"

#include <QtCore/QVariantList>

class GPSRTKFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact *connected          READ connected          CONSTANT)
    Q_PROPERTY(Fact *connecting         READ connecting         CONSTANT)
    Q_PROPERTY(Fact *currentDuration    READ currentDuration    CONSTANT)
    Q_PROPERTY(Fact *currentAccuracy    READ currentAccuracy    CONSTANT)
    Q_PROPERTY(Fact *currentLatitude    READ currentLatitude    CONSTANT)
    Q_PROPERTY(Fact *currentLongitude   READ currentLongitude   CONSTANT)
    Q_PROPERTY(Fact *currentAltitude    READ currentAltitude    CONSTANT)
    Q_PROPERTY(Fact *valid              READ valid              CONSTANT)
    Q_PROPERTY(Fact *active             READ active             CONSTANT)
    Q_PROPERTY(Fact *numSatellites      READ numSatellites      CONSTANT)
    Q_PROPERTY(Fact *numSatellitesUsed  READ numSatellitesUsed  CONSTANT)
    Q_PROPERTY(Fact *streamBytes        READ streamBytes        CONSTANT)
    Q_PROPERTY(Fact *rtcmFrames         READ rtcmFrames         CONSTANT)
    Q_PROPERTY(Fact *invalidRtcmFrames  READ invalidRtcmFrames  CONSTANT)
    Q_PROPERTY(Fact *lastRtcmMessageId  READ lastRtcmMessageId  CONSTANT)
    Q_PROPERTY(Fact *streamBytesPerSec  READ streamBytesPerSec  CONSTANT)
    Q_PROPERTY(Fact *lastError          READ lastError          CONSTANT)
    Q_PROPERTY(QVariantList satelliteBars READ satelliteBars NOTIFY satelliteBarsChanged)

public:
    explicit GPSRTKFactGroup(QObject *parent = nullptr);
    ~GPSRTKFactGroup();

    Fact *connected() { return &_connectedFact; }
    Fact *connecting() { return &_connectingFact; }
    Fact *currentDuration() { return &_currentDurationFact; }
    Fact *currentAccuracy() { return &_currentAccuracyFact; }
    Fact *currentLatitude() { return &_currentLatitudeFact; }
    Fact *currentLongitude() { return &_currentLongitudeFact; }
    Fact *currentAltitude()  { return &_currentAltitudeFact; }
    Fact *valid() { return &_validFact; }
    Fact *active() { return &_activeFact; }
    Fact *numSatellites() { return &_numSatellitesFact; }
    Fact *numSatellitesUsed() { return &_numSatellitesUsedFact; }
    Fact *streamBytes() { return &_streamBytesFact; }
    Fact *rtcmFrames() { return &_rtcmFramesFact; }
    Fact *invalidRtcmFrames() { return &_invalidRtcmFramesFact; }
    Fact *lastRtcmMessageId() { return &_lastRtcmMessageIdFact; }
    Fact *streamBytesPerSec() { return &_streamBytesPerSecFact; }
    Fact *lastError() { return &_lastErrorFact; }
    QVariantList satelliteBars() const { return _satelliteBars; }
    void setSatelliteBars(const QVariantList &bars);

signals:
    void satelliteBarsChanged();

private:
    Fact _connectedFact = Fact(0, QStringLiteral("connected"), FactMetaData::valueTypeBool);
    Fact _connectingFact = Fact(0, QStringLiteral("connecting"), FactMetaData::valueTypeBool);
    Fact _currentDurationFact = Fact(0, QStringLiteral("currentDuration"), FactMetaData::valueTypeDouble);
    Fact _currentAccuracyFact = Fact(0, QStringLiteral("currentAccuracy"), FactMetaData::valueTypeDouble);
    Fact _currentLatitudeFact = Fact(0, QStringLiteral("currentLatitude"), FactMetaData::valueTypeDouble);
    Fact _currentLongitudeFact = Fact(0, QStringLiteral("currentLongitude"), FactMetaData::valueTypeDouble);
    Fact _currentAltitudeFact = Fact(0, QStringLiteral("currentAltitude"), FactMetaData::valueTypeFloat);
    Fact _validFact = Fact(0, QStringLiteral("valid"), FactMetaData::valueTypeBool);
    Fact _activeFact = Fact(0, QStringLiteral("active"), FactMetaData::valueTypeBool);
    Fact _numSatellitesFact = Fact(0, QStringLiteral("numSatellites"), FactMetaData::valueTypeInt32);
    Fact _numSatellitesUsedFact = Fact(0, QStringLiteral("numSatellitesUsed"), FactMetaData::valueTypeInt32);
    Fact _streamBytesFact = Fact(0, QStringLiteral("streamBytes"), FactMetaData::valueTypeUint32);
    Fact _rtcmFramesFact = Fact(0, QStringLiteral("rtcmFrames"), FactMetaData::valueTypeUint32);
    Fact _invalidRtcmFramesFact = Fact(0, QStringLiteral("invalidRtcmFrames"), FactMetaData::valueTypeUint32);
    Fact _lastRtcmMessageIdFact = Fact(0, QStringLiteral("lastRtcmMessageId"), FactMetaData::valueTypeInt32);
    Fact _streamBytesPerSecFact = Fact(0, QStringLiteral("streamBytesPerSec"), FactMetaData::valueTypeDouble);
    Fact _lastErrorFact = Fact(0, QStringLiteral("lastError"), FactMetaData::valueTypeUint32);
    QVariantList _satelliteBars;
};
