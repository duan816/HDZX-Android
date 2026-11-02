#pragma once

#include <QtCore/QList>
#include <functional>
/// \brief Allows to configure a set of mavlink streams to a specific rate, and restore back to default.
///
/// Note that only one set is active at a time.

class MAVLinkStreamConfig
{
public:
    using SetMessageIntervalCb = std::function<void(int messageId, int rate)>;

    MAVLinkStreamConfig(const SetMessageIntervalCb &messageIntervalCb);
    ~MAVLinkStreamConfig();

    void setHighRateRateAndAttitude(bool includePidComponents = false, int rateHz = 100, int pidRateHz = 20);
    void setHighRateVelAndPos(int rateHz = 100);
    void setHighRateAltAirspeed();

    /// Keep the selected attitude-only rate after temporary PID streams are released (maximum 100 Hz).
    void enableNormalAttitude(int rateHz = 50);

    void restoreDefaults();

    void gotSetMessageIntervalAck();
private:
    enum class State {
        Idle,
        RestoringDefaults,
        Configuring
    };

    struct DesiredStreamRate {
        const int messageId = 0;
        const int rate = 0;
    };

    void restoreNextDefault();
    void nextDesiredRate();
    void setNextState(State state);

    State _state{State::Idle};
    QList<DesiredStreamRate> _desiredRates;
    QList<int> _changedIds;

    State _nextState{State::Idle};
    QList<DesiredStreamRate> _nextDesiredRates;

    bool _normalAttitudeEnabled = false;
    int _normalAttitudeInterval = 1000000 / 50;

    const SetMessageIntervalCb _messageIntervalCb;
};
