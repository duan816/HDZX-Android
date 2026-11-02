#pragma once

#include "UnitTest.h"

class MAVLinkStreamConfigTest : public UnitTest
{
    Q_OBJECT

private slots:
    void _testInitialState();
    void _testSetHighRateRateAndAttitude();
    void _testPidComponentsOptional();
    void _testMonitorRatesBounded();
    void _testSelectableRates();
    void _testSetHighRateVelAndPos();
    void _testSetHighRateAltAirspeed();
    void _testRestoreDefaultsAfterConfigure();
    void _testRestoreDefaultsFromIdle();
    void _testInterruptConfigureWithNewRequest();
    void _testNormalAttitudeStartsWithoutPID();
    void _testPIDCloseRetainsNormalAttitude();
    void _testNormalEnableDuringPIDDoesNotReplaceMode();
    void _testNormalAttitudeSurvivesOtherModes();
    void _testSynchronousCommandFailure();
    void _testFastNormalAttitudeReturnsAfterPID();
    void _testNormalRateLimits();
};
