#include "VehicleGPSFactGroup.h"
#include "GPSHeading.h"
#include "Vehicle.h"
#include "QGCGeo.h"
#include "QGCLoggingCategory.h"
#include "development/mavlink_msg_gnss_integrity.h"

#include <QtPositioning/QGeoCoordinate>
#include <QtCore/QtMath>

VehicleGPSFactGroup::VehicleGPSFactGroup(QObject *parent)
    : FactGroup(1000, ":/json/Vehicle/GPSFact.json", parent)
{
    _addFact(&_latFact);
    _addFact(&_lonFact);
    _addFact(&_mgrsFact);
    _addFact(&_hdopFact);
    _addFact(&_vdopFact);
    _addFact(&_hAccFact);
    _addFact(&_vAccFact);
    _addFact(&_altitudeEllipsoidFact);
    _addFact(&_courseOverGroundFact);
    _addFact(&_yawFact);
    _addFact(&_lockFact);
    _addFact(&_countFact);
    _addFact(&_systemErrorsFact);
    _addFact(&_spoofingStateFact);
    _addFact(&_jammingStateFact);
    _addFact(&_authenticationStateFact);
    _addFact(&_correctionsQualityFact);
    _addFact(&_systemQualityFact);
    _addFact(&_gnssSignalQualityFact);
    _addFact(&_postProcessingQualityFact);
    _addFact(&_gpsSatellitesFact);
    _addFact(&_bdsSatellitesFact);
    _addFact(&_galileoSatellitesFact);
    _addFact(&_glonassSatellitesFact);
    _addFact(&_rtkBaselineDistanceFact);
    _addFact(&_rtkRateFact);
    _addFact(&_rtkMessageAgeFact);

    _latFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _lonFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _mgrsFact.setRawValue("");
    _hdopFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _vdopFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _hAccFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _vAccFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _altitudeEllipsoidFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _courseOverGroundFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _yawFact.setRawValue(std::numeric_limits<int16_t>::quiet_NaN());
    _spoofingStateFact.setRawValue(255);
    _jammingStateFact.setRawValue(255);
    _authenticationStateFact.setRawValue(255);
    _correctionsQualityFact.setRawValue(255);
    _systemQualityFact.setRawValue(255);
    _gnssSignalQualityFact.setRawValue(255);
    _postProcessingQualityFact.setRawValue(255);
    _rtkBaselineDistanceFact.setRawValue(qQNaN());
    _rtkRateFact.setRawValue(qQNaN());
    _rtkMessageAgeFact.setRawValue(qQNaN());
}

void VehicleGPSFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    Q_UNUSED(vehicle);

    switch (message.msgid) {
    case MAVLINK_MSG_ID_GPS_RAW_INT:
        _handleGpsRawInt(message);
        break;
    case MAVLINK_MSG_ID_HIGH_LATENCY:
        _handleHighLatency(message);
        break;
    case MAVLINK_MSG_ID_HIGH_LATENCY2:
        _handleHighLatency2(message);
        break;
    case MAVLINK_MSG_ID_GNSS_INTEGRITY:
        _handleGnssIntegrity(message);
        break;
    case MAVLINK_MSG_ID_GPS_STATUS:
        _handleGpsStatus(message);
        break;
    case MAVLINK_MSG_ID_GPS_RTK:
        _handleGpsRtk(message);
        break;
    default:
        break;
    }
}

void VehicleGPSFactGroup::_handleGpsRawInt(const mavlink_message_t &message)
{
    mavlink_gps_raw_int_t gpsRawInt{};
    mavlink_msg_gps_raw_int_decode(&message, &gpsRawInt);

    lat()->setRawValue(gpsRawInt.lat * 1e-7);
    lon()->setRawValue(gpsRawInt.lon * 1e-7);
    mgrs()->setRawValue(QGCGeo::convertGeoToMGRS(QGeoCoordinate(gpsRawInt.lat * 1e-7, gpsRawInt.lon * 1e-7)));
    count()->setRawValue((gpsRawInt.satellites_visible == 255) ? 0 : gpsRawInt.satellites_visible);
    hdop()->setRawValue((gpsRawInt.eph == UINT16_MAX) ? qQNaN() : (gpsRawInt.eph / 100.0));
    vdop()->setRawValue((gpsRawInt.epv == UINT16_MAX) ? qQNaN() : (gpsRawInt.epv / 100.0));
    hAcc()->setRawValue((message.len < 38 || gpsRawInt.h_acc == UINT32_MAX) ? qQNaN() : (gpsRawInt.h_acc / 1000.0));
    vAcc()->setRawValue((message.len < 42 || gpsRawInt.v_acc == UINT32_MAX) ? qQNaN() : (gpsRawInt.v_acc / 1000.0));
    // alt_ellipsoid is a MAVLink 2 extension field in millimetres above the
    // WGS84 ellipsoid. A MAVLink 1 packet does not contain this field.
    altitudeEllipsoid()->setRawValue((message.len < 34) ? qQNaN() : (gpsRawInt.alt_ellipsoid / 1000.0));
    courseOverGround()->setRawValue((gpsRawInt.cog == UINT16_MAX) ? qQNaN() : (gpsRawInt.cog / 100.0));
    yaw()->setRawValue(GPSHeading::fromRaw(gpsRawInt.yaw));
    lock()->setRawValue(gpsRawInt.fix_type);
    emit fixTypeReceived(gpsRawInt.fix_type);

    _setTelemetryAvailable(true);
}

void VehicleGPSFactGroup::_handleHighLatency(const mavlink_message_t &message)
{
    mavlink_high_latency_t highLatency{};
    mavlink_msg_high_latency_decode(&message, &highLatency);

    lat()->setRawValue(highLatency.latitude * 1e-7);
    lon()->setRawValue(highLatency.longitude * 1e-7);
    mgrs()->setRawValue(QGCGeo::convertGeoToMGRS(QGeoCoordinate(highLatency.latitude * 1e-7, highLatency.longitude * 1e-7, highLatency.altitude_amsl)));
    count()->setRawValue(0);
    hAcc()->setRawValue(qQNaN());
    vAcc()->setRawValue(qQNaN());
    altitudeEllipsoid()->setRawValue(qQNaN());

    _setTelemetryAvailable(true);
}

void VehicleGPSFactGroup::_handleHighLatency2(const mavlink_message_t &message)
{
    mavlink_high_latency2_t highLatency2{};
    mavlink_msg_high_latency2_decode(&message, &highLatency2);

    lat()->setRawValue(highLatency2.latitude * 1e-7);
    lon()->setRawValue(highLatency2.longitude * 1e-7);
    mgrs()->setRawValue(QGCGeo::convertGeoToMGRS(QGeoCoordinate(highLatency2.latitude * 1e-7, highLatency2.longitude * 1e-7, highLatency2.altitude)));
    count()->setRawValue(0);
    hdop()->setRawValue((highLatency2.eph == UINT8_MAX) ? qQNaN() : (highLatency2.eph / 10.0));
    vdop()->setRawValue((highLatency2.epv == UINT8_MAX) ? qQNaN() : (highLatency2.epv / 10.0));
    hAcc()->setRawValue(qQNaN());
    vAcc()->setRawValue(qQNaN());
    altitudeEllipsoid()->setRawValue(qQNaN());

    _setTelemetryAvailable(true);
}

void VehicleGPSFactGroup::_handleGnssIntegrity(const mavlink_message_t& message)
{
    mavlink_gnss_integrity_t gnssIntegrity;
    mavlink_msg_gnss_integrity_decode(&message, &gnssIntegrity);

    if (gnssIntegrity.id != _gnssIntegrityId) {
        return;
    }

    systemErrors()->setRawValue         (gnssIntegrity.system_errors);
    spoofingState()->setRawValue        (gnssIntegrity.spoofing_state);
    jammingState()->setRawValue         (gnssIntegrity.jamming_state);
    authenticationState()->setRawValue  (gnssIntegrity.authentication_state);
    correctionsQuality()->setRawValue   (gnssIntegrity.corrections_quality);
    systemQuality()->setRawValue        (gnssIntegrity.system_status_summary);
    gnssSignalQuality()->setRawValue    (gnssIntegrity.gnss_signal_quality);
    postProcessingQuality()->setRawValue(gnssIntegrity.post_processing_quality);

    emit gnssIntegrityReceived();
}

void VehicleGPSFactGroup::_handleGpsStatus(const mavlink_message_t& message)
{
    mavlink_gps_status_t status{};
    mavlink_msg_gps_status_decode(&message, &status);

    int gps = 0;
    int bds = 0;
    int galileo = 0;
    int glonass = 0;

    // GPS_STATUS reports the classic MAVLink PRN ranges. Some receivers send
    // the system's native PRN while others use the NMEA ranges, so accept both
    // common representations where they do not overlap.
    const int satellites = qMin<int>(status.satellites_visible, MAVLINK_MSG_GPS_STATUS_FIELD_SATELLITE_PRN_LEN);
    for (int i = 0; i < satellites; ++i) {
        const int prn = status.satellite_prn[i];
        if (prn >= 1 && prn <= 32) {
            ++gps;
        } else if (prn >= 65 && prn <= 96) {
            ++glonass;
        } else if (prn >= 201 && prn <= 237) {
            ++bds;
        } else if (prn >= 301 && prn <= 336) {
            ++galileo;
        }
    }

    gpsSatellites()->setRawValue(gps);
    bdsSatellites()->setRawValue(bds);
    galileoSatellites()->setRawValue(galileo);
    glonassSatellites()->setRawValue(glonass);
    _setTelemetryAvailable(true);
}

void VehicleGPSFactGroup::_handleGpsRtk(const mavlink_message_t& message)
{
    mavlink_gps_rtk_t rtk{};
    mavlink_msg_gps_rtk_decode(&message, &rtk);

    const double a = static_cast<double>(rtk.baseline_a_mm);
    const double b = static_cast<double>(rtk.baseline_b_mm);
    const double c = static_cast<double>(rtk.baseline_c_mm);
    rtkBaselineDistance()->setRawValue(qSqrt(a * a + b * b + c * c) / 1000.0);
    rtkRate()->setRawValue(rtk.rtk_rate);
    _lastRtkMessageTimer.restart();
    rtkMessageAge()->setRawValue(0.0);
    _setTelemetryAvailable(true);
}

void VehicleGPSFactGroup::_updateAllValues()
{
    FactGroup::_updateAllValues();
    if (_lastRtkMessageTimer.isValid()) {
        rtkMessageAge()->setRawValue(_lastRtkMessageTimer.elapsed() / 1000.0);
    }
}
