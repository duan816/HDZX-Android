#include "VehicleLocalPositionSetpointFactGroup.h"
#include "Vehicle.h"

VehicleLocalPositionSetpointFactGroup::VehicleLocalPositionSetpointFactGroup(QObject *parent)
    : FactGroup(1000, QStringLiteral(":/json/Vehicle/LocalPositionSetpointFact.json"), parent)
{
    _addFact(&_xFact);
    _addFact(&_yFact);
    _addFact(&_zFact);
    _addFact(&_vxFact);
    _addFact(&_vyFact);
    _addFact(&_vzFact);

    _xFact.setRawValue(qQNaN());
    _yFact.setRawValue(qQNaN());
    _zFact.setRawValue(qQNaN());
    _vxFact.setRawValue(qQNaN());
    _vyFact.setRawValue(qQNaN());
    _vzFact.setRawValue(qQNaN());
}

void VehicleLocalPositionSetpointFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    Q_UNUSED(vehicle);

    if (message.msgid != MAVLINK_MSG_ID_POSITION_TARGET_LOCAL_NED) {
        return;
    }

    mavlink_position_target_local_ned_t localPosition{};
    mavlink_msg_position_target_local_ned_decode(&message, &localPosition);
    _received.restart();

    // Offset/body-frame targets cannot be compared directly with LOCAL_POSITION_NED.
    const bool localNed = localPosition.coordinate_frame == MAV_FRAME_LOCAL_NED;
    x()->setRawValue(localNed && !(localPosition.type_mask & POSITION_TARGET_TYPEMASK_X_IGNORE) ? localPosition.x : qQNaN());
    y()->setRawValue(localNed && !(localPosition.type_mask & POSITION_TARGET_TYPEMASK_Y_IGNORE) ? localPosition.y : qQNaN());
    z()->setRawValue(localNed && !(localPosition.type_mask & POSITION_TARGET_TYPEMASK_Z_IGNORE) ? localPosition.z : qQNaN());
    vx()->setRawValue(localNed && !(localPosition.type_mask & POSITION_TARGET_TYPEMASK_VX_IGNORE) ? localPosition.vx : qQNaN());
    vy()->setRawValue(localNed && !(localPosition.type_mask & POSITION_TARGET_TYPEMASK_VY_IGNORE) ? localPosition.vy : qQNaN());
    vz()->setRawValue(localNed && !(localPosition.type_mask & POSITION_TARGET_TYPEMASK_VZ_IGNORE) ? localPosition.vz : qQNaN());

    _setTelemetryAvailable(true);
}
