#include "VehicleEstimatorStatusFactGroup.h"
#include "Vehicle.h"

VehicleEstimatorStatusFactGroup::VehicleEstimatorStatusFactGroup(QObject *parent)
    : FactGroup(500, QStringLiteral(":/json/Vehicle/EstimatorStatusFactGroup.json"), parent)
{
    _addFact(&_rawFlagsFact);
    _addFact(&_goodAttitudeEstimateFact);
    _addFact(&_goodHorizVelEstimateFact);
    _addFact(&_goodVertVelEstimateFact);
    _addFact(&_goodHorizPosRelEstimateFact);
    _addFact(&_goodHorizPosAbsEstimateFact);
    _addFact(&_goodVertPosAbsEstimateFact);
    _addFact(&_goodVertPosAGLEstimateFact);
    _addFact(&_goodConstPosModeEstimateFact);
    _addFact(&_goodPredHorizPosRelEstimateFact);
    _addFact(&_goodPredHorizPosAbsEstimateFact);
    _addFact(&_gpsGlitchFact);
    _addFact(&_accelErrorFact);
    _addFact(&_velRatioFact);
    _addFact(&_horizPosRatioFact);
    _addFact(&_vertPosRatioFact);
    _addFact(&_magRatioFact);
    _addFact(&_haglRatioFact);
    _addFact(&_tasRatioFact);
    _addFact(&_horizPosAccuracyFact);
    _addFact(&_vertPosAccuracyFact);
}

void VehicleEstimatorStatusFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    if (vehicle && (message.sysid != vehicle->id() || message.compid != vehicle->compId())) {
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_EKF_STATUS_REPORT) {
        mavlink_ekf_status_report_t status{};
        mavlink_msg_ekf_status_report_decode(&message, &status);
        rawFlags()->setRawValue(status.flags);
        _setReportType(QStringLiteral("EKF_STATUS_REPORT"));
        // The first ten bits match ESTIMATOR_STATUS, but bit 10 is
        // UNINITIALIZED in ArduPilot, not GPS_GLITCH. Translate explicitly.
        uint16_t flags = (status.flags & EKF_UNINITIALIZED) ? 0 : (status.flags & 0x03ff);
        if (status.flags & EKF_GPS_GLITCHING) {
            flags |= ESTIMATOR_GPS_GLITCH;
        }
        _updateFlags(flags);
        velRatio()->setRawValue(status.velocity_variance);
        horizPosRatio()->setRawValue(status.pos_horiz_variance);
        vertPosRatio()->setRawValue(status.pos_vert_variance);
        magRatio()->setRawValue(status.compass_variance);
        haglRatio()->setRawValue(status.terrain_alt_variance);
        tasRatio()->setRawValue(message.len >= 26 ? status.airspeed_variance : qQNaN());
        // EKF_STATUS_REPORT does not contain position accuracy in metres.
        horizPosAccuracy()->setRawValue(qQNaN());
        vertPosAccuracy()->setRawValue(qQNaN());
        _setTelemetryAvailable(true);
        return;
    }
    if (message.msgid != MAVLINK_MSG_ID_ESTIMATOR_STATUS) {
        return;
    }

    mavlink_estimator_status_t estimatorStatus{};
    mavlink_msg_estimator_status_decode(&message, &estimatorStatus);

    rawFlags()->setRawValue(estimatorStatus.flags);
    _setReportType(QStringLiteral("ESTIMATOR_STATUS"));
    _updateFlags(estimatorStatus.flags);
    velRatio()->setRawValue(estimatorStatus.vel_ratio);
    horizPosRatio()->setRawValue(estimatorStatus.pos_horiz_ratio);
    vertPosRatio()->setRawValue(estimatorStatus.pos_vert_ratio);
    magRatio()->setRawValue(estimatorStatus.mag_ratio);
    haglRatio()->setRawValue(estimatorStatus.hagl_ratio);
    tasRatio()->setRawValue(estimatorStatus.tas_ratio);
    horizPosAccuracy()->setRawValue(estimatorStatus.pos_horiz_accuracy);
    vertPosAccuracy()->setRawValue(estimatorStatus.pos_vert_accuracy);

    _setTelemetryAvailable(true);
}

void VehicleEstimatorStatusFactGroup::_setReportType(const QString &reportType)
{
    if (_reportType != reportType) {
        _reportType = reportType;
        emit reportTypeChanged();
    }
}

void VehicleEstimatorStatusFactGroup::_updateFlags(uint16_t flags)
{
    goodAttitudeEstimate()->setRawValue(!!(flags & ESTIMATOR_ATTITUDE));
    goodHorizVelEstimate()->setRawValue(!!(flags & ESTIMATOR_VELOCITY_HORIZ));
    goodVertVelEstimate()->setRawValue(!!(flags & ESTIMATOR_VELOCITY_VERT));
    goodHorizPosRelEstimate()->setRawValue(!!(flags & ESTIMATOR_POS_HORIZ_REL));
    goodHorizPosAbsEstimate()->setRawValue(!!(flags & ESTIMATOR_POS_HORIZ_ABS));
    goodVertPosAbsEstimate()->setRawValue(!!(flags & ESTIMATOR_POS_VERT_ABS));
    goodVertPosAGLEstimate()->setRawValue(!!(flags & ESTIMATOR_POS_VERT_AGL));
    goodConstPosModeEstimate()->setRawValue(!!(flags & ESTIMATOR_CONST_POS_MODE));
    goodPredHorizPosRelEstimate()->setRawValue(!!(flags & ESTIMATOR_PRED_POS_HORIZ_REL));
    goodPredHorizPosAbsEstimate()->setRawValue(!!(flags & ESTIMATOR_PRED_POS_HORIZ_ABS));
    gpsGlitch()->setRawValue(!!(flags & ESTIMATOR_GPS_GLITCH));
    accelError()->setRawValue(!!(flags & ESTIMATOR_ACCEL_ERROR));
}
