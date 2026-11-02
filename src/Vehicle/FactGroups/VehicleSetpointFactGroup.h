#pragma once

#include "FactGroup.h"
#include <QtCore/QElapsedTimer>
#include <array>

class VehicleSetpointFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact *roll       READ roll       CONSTANT)
    Q_PROPERTY(Fact *pitch      READ pitch      CONSTANT)
    Q_PROPERTY(Fact *yaw        READ yaw        CONSTANT)
    Q_PROPERTY(Fact *rollRate   READ rollRate   CONSTANT)
    Q_PROPERTY(Fact *pitchRate  READ pitchRate  CONSTANT)
    Q_PROPERTY(Fact *yawRate    READ yawRate    CONSTANT)

public:
    explicit VehicleSetpointFactGroup(QObject *parent = nullptr);

    Fact *roll() { return &_rollFact; }
    Fact *pitch() { return &_pitchFact; }
    Fact *yaw() { return &_yawFact; }
    Fact *rollRate() { return &_rollRateFact; }
    Fact *pitchRate() { return &_pitchRateFact; }
    Fact *yawRate() { return &_yawRateFact; }
    Q_INVOKABLE Fact* pidTerm(int axis, int term) const;
    Q_INVOKABLE bool pidTermsFresh(int axis) const;
    Q_INVOKABLE bool fresh() const { return _attitudeReceived.isValid() && _attitudeReceived.elapsed() < 1500; }

    // Overrides from FactGroup
    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) final;

private:
    std::array<std::array<Fact*, 4>, 3> _pidTerms{}; // Roll/Pitch/Yaw; P/I/D/FF, controller output units.
    std::array<QElapsedTimer, 3> _pidReceived;
    QElapsedTimer _attitudeReceived;
    Fact _rollFact = Fact(0, QStringLiteral("roll"), FactMetaData::valueTypeDouble);
    Fact _pitchFact = Fact(0, QStringLiteral("pitch"), FactMetaData::valueTypeDouble);
    Fact _yawFact = Fact(0, QStringLiteral("yaw"), FactMetaData::valueTypeDouble);
    Fact _rollRateFact = Fact(0, QStringLiteral("rollRate"), FactMetaData::valueTypeDouble);
    Fact _pitchRateFact = Fact(0, QStringLiteral("pitchRate"), FactMetaData::valueTypeDouble);
    Fact _yawRateFact = Fact(0, QStringLiteral("yawRate"), FactMetaData::valueTypeDouble);
};
