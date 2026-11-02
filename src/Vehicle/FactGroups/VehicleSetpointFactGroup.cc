#include "VehicleSetpointFactGroup.h"
#include "Vehicle.h"

#include <QtMath>

VehicleSetpointFactGroup::VehicleSetpointFactGroup(QObject *parent)
    : FactGroup(1000, QStringLiteral(":/json/Vehicle/SetpointFact.json"), parent)
{
    _addFact(&_rollFact);
    _addFact(&_pitchFact);
    _addFact(&_yawFact);
    _addFact(&_rollRateFact);
    _addFact(&_pitchRateFact);
    _addFact(&_yawRateFact);

    _rollFact.setRawValue(qQNaN());
    _pitchFact.setRawValue(qQNaN());
    _yawFact.setRawValue(qQNaN());
    _rollRateFact.setRawValue(qQNaN());
    _pitchRateFact.setRawValue(qQNaN());
    _yawRateFact.setRawValue(qQNaN());
    const QStringList terms{QStringLiteral("P"), QStringLiteral("I"), QStringLiteral("D"), QStringLiteral("FF")};
    for (int axis = 0; axis < 3; ++axis) {
        for (int term = 0; term < 4; ++term) {
            auto* fact = new Fact(0, QStringLiteral("pid%1%2").arg(axis).arg(terms[term]), FactMetaData::valueTypeDouble, this);
            fact->setRawValue(qQNaN());
            _addFact(fact);
            _pidTerms[axis][term] = fact;
        }
    }
}

Fact* VehicleSetpointFactGroup::pidTerm(int axis, int term) const
{
    return axis >= 0 && axis < 3 && term >= 0 && term < 4 ? _pidTerms[axis][term] : nullptr;
}

bool VehicleSetpointFactGroup::pidTermsFresh(int axis) const
{
    return axis >= 0 && axis < 3 && _pidReceived[axis].isValid() && _pidReceived[axis].elapsed() < 1500;
}

void VehicleSetpointFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    Q_UNUSED(vehicle);

    if (message.msgid == MAVLINK_MSG_ID_PID_TUNING) {
        mavlink_pid_tuning_t tuning{};
        mavlink_msg_pid_tuning_decode(&message, &tuning);
        // Other PID_TUNING axes describe different controllers and must not be relabelled as attitude/position PIDs.
        if (tuning.axis >= PID_TUNING_ROLL && tuning.axis <= PID_TUNING_YAW) {
            const int axis = tuning.axis - PID_TUNING_ROLL;
            const std::array values{tuning.P, tuning.I, tuning.D, tuning.FF};
            for (int term = 0; term < 4; ++term) _pidTerms[axis][term]->setRawValue(values[term]);
            _pidReceived[axis].restart();
        }
        return;
    }

    if (message.msgid != MAVLINK_MSG_ID_ATTITUDE_TARGET) {
        return;
    }

    mavlink_attitude_target_t attitudeTarget{};
    mavlink_msg_attitude_target_decode(&message, &attitudeTarget);
    _attitudeReceived.restart();

    float targetRoll, targetPitch, targetYaw;
    mavlink_quaternion_to_euler(attitudeTarget.q, &targetRoll, &targetPitch, &targetYaw);

    double quaternionNorm = 0;
    for (const float value : attitudeTarget.q) quaternionNorm += value * value;
    const bool attitudeValid = !(attitudeTarget.type_mask & ATTITUDE_TARGET_TYPEMASK_ATTITUDE_IGNORE)
        && qIsFinite(quaternionNorm) && std::abs(quaternionNorm - 1.0) < 0.05;
    roll()->setRawValue(attitudeValid ? qRadiansToDegrees(targetRoll) : qQNaN());
    pitch()->setRawValue(attitudeValid ? qRadiansToDegrees(targetPitch) : qQNaN());
    if (targetYaw < 0.f) {
        targetYaw += 2.f * static_cast<float>(M_PI); // bring to range [0, 2pi] to match the heading angle
    }
    yaw()->setRawValue(attitudeValid ? qRadiansToDegrees(targetYaw) : qQNaN());

    rollRate()->setRawValue(attitudeTarget.type_mask & ATTITUDE_TARGET_TYPEMASK_BODY_ROLL_RATE_IGNORE ? qQNaN() : qRadiansToDegrees(attitudeTarget.body_roll_rate));
    pitchRate()->setRawValue(attitudeTarget.type_mask & ATTITUDE_TARGET_TYPEMASK_BODY_PITCH_RATE_IGNORE ? qQNaN() : qRadiansToDegrees(attitudeTarget.body_pitch_rate));
    yawRate()->setRawValue(attitudeTarget.type_mask & ATTITUDE_TARGET_TYPEMASK_BODY_YAW_RATE_IGNORE ? qQNaN() : qRadiansToDegrees(attitudeTarget.body_yaw_rate));

    _setTelemetryAvailable(true);
}
