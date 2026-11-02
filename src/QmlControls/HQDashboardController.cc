#include "HQDashboardController.h"
#include "MAVLinkLib.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"

#include <QtCore/QStringList>

#include <cmath>

HQDashboardController::HQDashboardController(QObject *parent)
    : QObject(parent)
{
    _clock.start();
    _refresh.setInterval(500);
    connect(&_refresh, &QTimer::timeout, this, [this]() {
        ++_revision;
        emit revisionChanged();
    });
}

Vehicle *HQDashboardController::vehicle() const
{
    return _vehicle.data();
}

void HQDashboardController::setVehicle(Vehicle *vehicle)
{
    if (_vehicle == vehicle) {
        return;
    }
    if (_vehicle) {
        disconnect(_vehicle, nullptr, this, nullptr);
    }
    disconnect(_communicationLostConnection);
    disconnect(_allLinksRemovedConnection);
    _vehicle = vehicle;
    _received.clear();
    _altitudeSeen = false;
    _linksRemoved = false;
    if (_vehicle) {
        connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &HQDashboardController::_messageReceived);
        connect(_vehicle, &QObject::destroyed, this, [this]() {
            _vehicle = nullptr;
            _received.clear();
            _refresh.stop();
            ++_revision;
            emit vehicleChanged();
            emit revisionChanged();
        });
        if (auto *linkManager = _vehicle->vehicleLinkManager()) {
            _communicationLostConnection = connect(linkManager, &VehicleLinkManager::communicationLostChanged, this, [this](bool lost) {
                if (lost) {
                    _clearSamples();
                }
            });
            _allLinksRemovedConnection = connect(linkManager, &VehicleLinkManager::allLinksRemoved, this, [this]() {
                _linksRemoved = true;
                _clearSamples();
            });
        }
        _refresh.start();
    } else {
        _refresh.stop();
    }
    ++_revision;
    emit vehicleChanged();
    emit revisionChanged();
}

bool HQDashboardController::available(const QString &field) const
{
    const auto sample = _received.constFind(field);
    return _vehicle && !_linksRemoved
        && (!_vehicle->vehicleLinkManager() || !_vehicle->vehicleLinkManager()->communicationLost())
        && sample != _received.cend() && _clock.elapsed() - sample.value() <= 5000;
}

void HQDashboardController::_clearSamples()
{
    _received.clear();
    ++_revision;
    emit revisionChanged();
}

void HQDashboardController::_mark(const QString &field, bool valid)
{
    _freshnessChanged = _freshnessChanged || (available(field) != valid);
    if (valid) {
        _received.insert(field, _clock.elapsed());
    } else {
        _received.remove(field);
    }
}

void HQDashboardController::_invalidateForeignMessage(const mavlink_message_t &message)
{
    // Some existing decoders also consume other components' telemetry. Their
    // Facts remain shared for compatibility; revoke only this HUD's trust in
    // affected values until the next sample from its selected flight controller.
    QStringList fields;
    switch (message.msgid) {
    case MAVLINK_MSG_ID_GPS_RAW_INT:
        fields = {QStringLiteral("gps1"), QStringLiteral("gps1Satellites"), QStringLiteral("gps1Yaw")};
        break;
    case MAVLINK_MSG_ID_GPS2_RAW:
        fields = {QStringLiteral("gps2"), QStringLiteral("gps2Satellites"), QStringLiteral("gps2Yaw")};
        break;
    case MAVLINK_MSG_ID_BATTERY_STATUS: {
        mavlink_battery_status_t battery{};
        mavlink_msg_battery_status_decode(&message, &battery);
        const QString prefix = QStringLiteral("battery%1").arg(battery.id);
        fields = {prefix, prefix + QStringLiteral("Remaining"), prefix + QStringLiteral("Voltage"),
            prefix + QStringLiteral("Current"), prefix + QStringLiteral("Consumed"),
            prefix + QStringLiteral("Temperature"), prefix + QStringLiteral("TimeRemaining")};
        break;
    }
    case MAVLINK_MSG_ID_VFR_HUD:
        fields = {QStringLiteral("groundSpeed"), QStringLiteral("airSpeed"), QStringLiteral("climbRate"),
            QStringLiteral("throttle"), QStringLiteral("throttlePct")};
        break;
    case MAVLINK_MSG_ID_ALTITUDE:
        fields = {QStringLiteral("altitudeRelative"), QStringLiteral("altitudeAMSL")};
        // The legacy altitude decoder latches ALTITUDE precedence regardless of
        // component. A later GLOBAL_POSITION_INT therefore cannot refresh its
        // potentially overwritten altitude Facts. Wait for a genuine ALTITUDE.
        _altitudeSeen = true;
        break;
    case MAVLINK_MSG_ID_NAV_CONTROLLER_OUTPUT:
        fields = {QStringLiteral("distanceToNextWP")};
        break;
    case MAVLINK_MSG_ID_RC_CHANNELS:
        fields = {QStringLiteral("rcRSSI"), QStringLiteral("rcChannels")};
        break;
    case MAVLINK_MSG_ID_SERVO_OUTPUT_RAW:
        fields = {QStringLiteral("servoOutputs")};
        break;
    case MAVLINK_MSG_ID_RADIO_STATUS:
        fields = {QStringLiteral("radioStatus")};
        break;
    case MAVLINK_MSG_ID_SYS_STATUS:
        fields = {QStringLiteral("sysStatus")};
        break;
    default:
        return;
    }
    bool changed = false;
    for (const auto &field : fields) {
        changed = (_received.remove(field) != 0) || changed;
    }
    if (changed) {
        ++_revision;
        emit revisionChanged();
    }
}

void HQDashboardController::_messageReceived(const mavlink_message_t &message)
{
    _freshnessChanged = false;
    const bool obstacleMessage = message.msgid == MAVLINK_MSG_ID_OBSTACLE_DISTANCE || message.msgid == MAVLINK_MSG_ID_DISTANCE_SENSOR;
    // Vehicle has already routed this legacy radio marker by its physical link.
    // Do not accept arbitrary other-system/component telemetry as FC data.
    const bool legacyRadio = message.msgid == MAVLINK_MSG_ID_RADIO_STATUS && message.sysid == '3' && message.compid == 'D';
    if (!_vehicle || _linksRemoved || (_vehicle->vehicleLinkManager() && _vehicle->vehicleLinkManager()->communicationLost())) {
        return;
    }
    if (!legacyRadio && (message.sysid != _vehicle->id() || (!obstacleMessage && message.compid != _vehicle->compId()))) {
        _invalidateForeignMessage(message);
        return;
    }
    switch (message.msgid) {
    case MAVLINK_MSG_ID_ESTIMATOR_STATUS:
    case MAVLINK_MSG_ID_EKF_STATUS_REPORT:
        _mark(QStringLiteral("estimatorStatus"));
        break;
    case MAVLINK_MSG_ID_GPS_RAW_INT: {
        mavlink_gps_raw_int_t gps{};
        mavlink_msg_gps_raw_int_decode(&message, &gps);
        _mark(QStringLiteral("gps1"));
        _mark(QStringLiteral("gps1Satellites"), gps.satellites_visible != UINT8_MAX);
        _mark(QStringLiteral("gps1Yaw"), message.len > 50 && gps.yaw > 0 && gps.yaw <= 36000);
        break;
    }
    case MAVLINK_MSG_ID_GPS2_RAW: {
        mavlink_gps2_raw_t gps{};
        mavlink_msg_gps2_raw_decode(&message, &gps);
        _mark(QStringLiteral("gps2"));
        _mark(QStringLiteral("gps2Satellites"), gps.satellites_visible != UINT8_MAX);
        _mark(QStringLiteral("gps2Yaw"), message.len > 35 && gps.yaw > 0 && gps.yaw <= 36000);
        break;
    }
    case MAVLINK_MSG_ID_DISTANCE_SENSOR: {
        mavlink_distance_sensor_t sensor{};
        mavlink_msg_distance_sensor_decode(&message, &sensor);
        if (sensor.orientation > MAV_SENSOR_ROTATION_YAW_315) {
            return; // Up/down-facing altimeters are not horizontal obstacle sectors.
        }
        _mark(QStringLiteral("distance%1").arg(sensor.orientation), sensor.signal_quality != 1
            && sensor.max_distance > sensor.min_distance && sensor.current_distance <= sensor.max_distance
            && (sensor.current_distance == 0 || sensor.current_distance >= sensor.min_distance));
        break;
    }
    case MAVLINK_MSG_ID_HEARTBEAT:
        _mark(QStringLiteral("flightMode"));
        break;
    case MAVLINK_MSG_ID_VIBRATION: {
        mavlink_vibration_t vibration{};
        mavlink_msg_vibration_decode(&message, &vibration);
        _mark(QStringLiteral("vibration"));
        _mark(QStringLiteral("vibrationX"), std::isfinite(vibration.vibration_x) && vibration.vibration_x >= 0);
        _mark(QStringLiteral("vibrationY"), std::isfinite(vibration.vibration_y) && vibration.vibration_y >= 0);
        _mark(QStringLiteral("vibrationZ"), std::isfinite(vibration.vibration_z) && vibration.vibration_z >= 0);
        break;
    }
    case MAVLINK_MSG_ID_RADIO_STATUS:
        _mark(QStringLiteral("radioStatus"));
        break;
    case MAVLINK_MSG_ID_SYSTEM_TIME: {
        mavlink_system_time_t time{};
        mavlink_msg_system_time_decode(&message, &time);
        _mark(QStringLiteral("systemTime"));
        _mark(QStringLiteral("utcTime"), time.time_unix_usec != 0);
        break;
    }
    case MAVLINK_MSG_ID_SYS_STATUS:
        _mark(QStringLiteral("sysStatus"));
        break;
    case MAVLINK_MSG_ID_SERVO_OUTPUT_RAW:
        _mark(QStringLiteral("servoOutputs"));
        break;
    case MAVLINK_MSG_ID_HOME_POSITION:
        _mark(QStringLiteral("homePosition"));
        _mark(QStringLiteral("distanceToHome"), _vehicle->homePosition().isValid()
              && _vehicle->coordinate().isValid() && available(QStringLiteral("coordinate")));
        break;
    case MAVLINK_MSG_ID_MISSION_CURRENT: {
        mavlink_mission_current_t current{};
        mavlink_msg_mission_current_decode(&message, &current);
        _mark(QStringLiteral("missionItemIndex"), current.seq != UINT16_MAX);
        break;
    }
    case MAVLINK_MSG_ID_NAV_CONTROLLER_OUTPUT:
        _mark(QStringLiteral("distanceToNextWP"));
        break;
    case MAVLINK_MSG_ID_OBSTACLE_DISTANCE: {
        mavlink_obstacle_distance_t obstacle{};
        mavlink_msg_obstacle_distance_decode(&message, &obstacle);
        const double increment = obstacle.increment_f != 0 ? obstacle.increment_f : obstacle.increment;
        _mark(QStringLiteral("obstacleDistance"), std::isfinite(increment) && increment != 0
            && std::isfinite(obstacle.angle_offset) && obstacle.max_distance > obstacle.min_distance
            && (obstacle.frame == MAV_FRAME_GLOBAL || obstacle.frame == MAV_FRAME_BODY_FRD));
        break;
    }
    case MAVLINK_MSG_ID_VFR_HUD: {
        mavlink_vfr_hud_t hud{};
        mavlink_msg_vfr_hud_decode(&message, &hud);
        _mark(QStringLiteral("groundSpeed"), std::isfinite(hud.groundspeed));
        _mark(QStringLiteral("airSpeed"), std::isfinite(hud.airspeed));
        _mark(QStringLiteral("climbRate"), std::isfinite(hud.climb));
        _mark(QStringLiteral("throttle"), hud.throttle <= 100);
        _mark(QStringLiteral("throttlePct"), hud.throttle <= 100);
        break;
    }
    case MAVLINK_MSG_ID_ATTITUDE: {
        mavlink_attitude_t attitude{};
        mavlink_msg_attitude_decode(&message, &attitude);
        _mark(QStringLiteral("roll"), std::isfinite(attitude.roll));
        _mark(QStringLiteral("pitch"), std::isfinite(attitude.pitch));
        _mark(QStringLiteral("heading"), std::isfinite(attitude.yaw));
        break;
    }
    case MAVLINK_MSG_ID_ATTITUDE_QUATERNION: {
        mavlink_attitude_quaternion_t attitude{};
        mavlink_msg_attitude_quaternion_decode(&message, &attitude);
        const bool valid = std::isfinite(attitude.q1) && std::isfinite(attitude.q2)
            && std::isfinite(attitude.q3) && std::isfinite(attitude.q4)
            && (attitude.q1 * attitude.q1 + attitude.q2 * attitude.q2
                + attitude.q3 * attitude.q3 + attitude.q4 * attitude.q4) > 0.000001f;
        _mark(QStringLiteral("roll"), valid);
        _mark(QStringLiteral("pitch"), valid);
        _mark(QStringLiteral("heading"), valid);
        break;
    }
    case MAVLINK_MSG_ID_ALTITUDE: {
        mavlink_altitude_t altitude{};
        mavlink_msg_altitude_decode(&message, &altitude);
        _altitudeSeen = true;
        _mark(QStringLiteral("altitudeRelative"), std::isfinite(altitude.altitude_relative));
        _mark(QStringLiteral("altitudeAMSL"), std::isfinite(altitude.altitude_amsl));
        break;
    }
    case MAVLINK_MSG_ID_GLOBAL_POSITION_INT: {
        mavlink_global_position_int_t position{};
        mavlink_msg_global_position_int_decode(&message, &position);
        _mark(QStringLiteral("coordinate"), (position.lat != 0 || position.lon != 0)
            && position.lat >= -900000000 && position.lat <= 900000000
            && position.lon >= -1800000000 && position.lon <= 1800000000);
        _mark(QStringLiteral("distanceToHome"), available(QStringLiteral("coordinate"))
              && _vehicle->homePosition().isValid());
        if (!_altitudeSeen) {
            _mark(QStringLiteral("altitudeRelative"));
            _mark(QStringLiteral("altitudeAMSL"));
        }
        break;
    }
    case MAVLINK_MSG_ID_BATTERY_STATUS: {
        mavlink_battery_status_t battery{};
        mavlink_msg_battery_status_decode(&message, &battery);
        const QString prefix = QStringLiteral("battery%1").arg(battery.id);
        const bool remaining = battery.battery_remaining >= 0 && battery.battery_remaining <= 100;
        _mark(prefix, remaining); // Compatibility: the existing battery ring displays percent.
        _mark(prefix + QStringLiteral("Remaining"), remaining);
        _mark(prefix + QStringLiteral("Voltage"), battery.voltages[0] != UINT16_MAX);
        _mark(prefix + QStringLiteral("Current"), battery.current_battery != -1);
        _mark(prefix + QStringLiteral("Consumed"), battery.current_consumed >= 0);
        _mark(prefix + QStringLiteral("Temperature"), battery.temperature != INT16_MAX);
        _mark(prefix + QStringLiteral("TimeRemaining"), battery.time_remaining > 0);
        break;
    }
    case MAVLINK_MSG_ID_RC_CHANNELS: {
        mavlink_rc_channels_t channels{};
        mavlink_msg_rc_channels_decode(&message, &channels);
        const uint16_t raw[] = {channels.chan1_raw, channels.chan2_raw, channels.chan3_raw,
            channels.chan4_raw, channels.chan5_raw, channels.chan6_raw, channels.chan7_raw,
            channels.chan8_raw, channels.chan9_raw, channels.chan10_raw, channels.chan11_raw,
            channels.chan12_raw, channels.chan13_raw, channels.chan14_raw, channels.chan15_raw,
            channels.chan16_raw, channels.chan17_raw, channels.chan18_raw};
        bool contiguous = true;
        bool unused = false;
        int validCount = 0;
        for (const auto value : raw) {
            if (value == UINT16_MAX) {
                unused = true;
            } else {
                ++validCount;
                contiguous = contiguous && !unused;
            }
        }
        // Match the existing RC decoder: it cannot publish a non-contiguous
        // packet. Such a packet must not make an old display snapshot fresh.
        _mark(QStringLiteral("rcRSSI"), contiguous && channels.rssi <= 100);
        _mark(QStringLiteral("rcChannels"), contiguous && channels.chancount > 0 && validCount > 0);
        break;
    }
    default:
        return;
    }
    // Facts notify their own value changes. Refresh the whole availability
    // graph only when validity changes, rather than for every telemetry packet.
    if (_freshnessChanged) {
        ++_revision;
        emit revisionChanged();
    }
}
