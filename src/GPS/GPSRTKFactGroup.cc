#include "GPSRTKFactGroup.h"
#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(GPSRTKFactGroupLog, "GPS.GPSRTKFactGroup")

GPSRTKFactGroup::GPSRTKFactGroup(QObject *parent)
    : FactGroup(1000, QStringLiteral(":/json/Vehicle/GPSRTKFact.json"), parent)
{
    // qCDebug(GPSRTKFactGroupLog) << Q_FUNC_INFO << this;

    _addFact(&_connectedFact);
    _addFact(&_connectingFact);
    _addFact(&_currentDurationFact);
    _addFact(&_currentAccuracyFact);
    _addFact(&_currentLatitudeFact);
    _addFact(&_currentLongitudeFact);
    _addFact(&_currentAltitudeFact);
    _addFact(&_validFact);
    _addFact(&_activeFact);
    _addFact(&_numSatellitesFact);
    _addFact(&_numSatellitesUsedFact);
    _addFact(&_streamBytesFact);
    _addFact(&_rtcmFramesFact);
    _addFact(&_invalidRtcmFramesFact);
    _addFact(&_lastRtcmMessageIdFact);
    _addFact(&_streamBytesPerSecFact);
    _addFact(&_lastErrorFact);
}

GPSRTKFactGroup::~GPSRTKFactGroup()
{
    // qCDebug(GPSRTKFactGroupLog) << Q_FUNC_INFO << this;
}

void GPSRTKFactGroup::setSatelliteBars(const QVariantList &bars)
{
    if (_satelliteBars == bars) {
        return;
    }
    _satelliteBars = bars;
    emit satelliteBarsChanged();
}
