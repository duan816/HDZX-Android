#include "MAVLinkStreamConfig.h"
#include "MAVLinkLib.h"
#include "QGCLoggingCategory.h"

#include <algorithm>

QGC_LOGGING_CATEGORY(MAVLinkStreamConfigLog, "MAVLink.MAVLinkStreamConfig")

MAVLinkStreamConfig::MAVLinkStreamConfig(const SetMessageIntervalCb &messageIntervalCb)
    : _messageIntervalCb(messageIntervalCb)
{
    // qCDebug(MAVLinkStreamConfigLog) << Q_FUNC_INFO << this;
}

MAVLinkStreamConfig::~MAVLinkStreamConfig()
{
    // qCDebug(MAVLinkStreamConfigLog) << Q_FUNC_INFO << this;
}

void MAVLinkStreamConfig::enableNormalAttitude(int rateHz)
{
    if (_normalAttitudeEnabled || rateHz <= 0) {
        return;
    }
    _normalAttitudeEnabled = true;
    _normalAttitudeInterval = 1000000 / std::min(rateHz, 100);
    // Connection completion must not replace a PID mode opened during parameter loading.
    if (_state == State::Idle && _changedIds.empty()) {
        _nextDesiredRates = QList<DesiredStreamRate>{{MAVLINK_MSG_ID_ATTITUDE_QUATERNION, _normalAttitudeInterval}};
        setNextState(State::Configuring);
    }
}

void MAVLinkStreamConfig::setHighRateRateAndAttitude(bool includePidComponents, int rateHz, int pidRateHz)
{
    const int requestedRate = 1000000 / std::clamp(rateHz, 1, 100);

    _nextDesiredRates = QList<DesiredStreamRate>{{
        {MAVLINK_MSG_ID_ATTITUDE_QUATERNION, requestedRate},
        {MAVLINK_MSG_ID_ATTITUDE_TARGET, requestedRate},
    }};
    if (includePidComponents) _nextDesiredRates.prepend({MAVLINK_MSG_ID_PID_TUNING, 1000000 / std::clamp(pidRateHz, 1, 100)});
    // we could check if we're already configured as requested

    setNextState(State::Configuring);
}

void MAVLinkStreamConfig::setHighRateVelAndPos(int rateHz)
{
    const int requestedRate = 1000000 / std::clamp(rateHz, 1, 100);
    _nextDesiredRates = QList<DesiredStreamRate>{{
        {MAVLINK_MSG_ID_LOCAL_POSITION_NED, requestedRate},
        {MAVLINK_MSG_ID_POSITION_TARGET_LOCAL_NED, requestedRate},
    }};
    setNextState(State::Configuring);
}

void MAVLinkStreamConfig::setHighRateAltAirspeed()
{
    static constexpr int requestedRate = static_cast<int>(1000000.0 / 100.0);
    _nextDesiredRates = QList<DesiredStreamRate>{{
        {MAVLINK_MSG_ID_NAV_CONTROLLER_OUTPUT, requestedRate},
        {MAVLINK_MSG_ID_VFR_HUD, requestedRate},
    }};
    setNextState(State::Configuring);
}

void MAVLinkStreamConfig::gotSetMessageIntervalAck()
{
    switch (_state) {
    case State::Configuring:
        nextDesiredRate();
        break;
    case State::RestoringDefaults:
        restoreNextDefault();
        break;
    default:
        break;
    }
}

void MAVLinkStreamConfig::setNextState(State state)
{
    _nextState = state;
    if (_state == State::Idle) {
        // first restore defaults no matter what the next state is
        _state = State::RestoringDefaults;
        restoreNextDefault();
    }
}

void MAVLinkStreamConfig::nextDesiredRate()
{
    if (_nextState != State::Idle) { // allow state to be interrupted by a new request
        _desiredRates.clear();
        _state = State::RestoringDefaults;
        restoreNextDefault();
        return;
    }

    if (_desiredRates.empty()) {
        _state = State::Idle;
        return;
    }

    const DesiredStreamRate rate = _desiredRates.last();
    _desiredRates.pop_back();
    _changedIds.push_back(rate.messageId);
    _messageIntervalCb(rate.messageId, rate.rate);
}

void MAVLinkStreamConfig::restoreDefaults()
{
    if (_normalAttitudeEnabled && !_changedIds.contains(MAVLINK_MSG_ID_ATTITUDE_QUATERNION)) {
        _changedIds.push_back(MAVLINK_MSG_ID_ATTITUDE_QUATERNION);
    }
    setNextState(State::RestoringDefaults);
}

void MAVLinkStreamConfig::restoreNextDefault()
{
    if (_changedIds.empty()) {
        // do we have a pending request?
        switch (_nextState) {
        case State::Configuring:
            _state = _nextState;
            _desiredRates = _nextDesiredRates;
            _nextDesiredRates.clear();
            _nextState = State::Idle;
            nextDesiredRate();
            break;
        case State::RestoringDefaults:
        case State::Idle:
            _nextState = State::Idle; // nothing to do, we just finished restoring
            _state = State::Idle;
            break;
        }
        return;
    }

    const int id = _changedIds.takeLast();
    const int interval = _normalAttitudeEnabled && id == MAVLINK_MSG_ID_ATTITUDE_QUATERNION ? _normalAttitudeInterval : 0;
    _messageIntervalCb(id, interval);
}
