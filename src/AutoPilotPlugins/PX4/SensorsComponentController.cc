#include "SensorsComponentController.h"
#include "AppMessages.h"
#include "ParameterManager.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"
#include "QGCLoggingCategory.h"
#include "AudioOutput.h"

QGC_LOGGING_CATEGORY(SensorsComponentControllerLog, "AutoPilotPlugins.SensorsComponentController")

SensorsComponentController::SensorsComponentController(void)
    : _statusLog                                (nullptr)
    , _progressBar                              (nullptr)
    , _showOrientationCalArea                   (false)
    , _gyroCalInProgress                        (false)
    , _magCalInProgress                         (false)
    , _accelCalInProgress                       (false)
    , _airspeedCalInProgress                    (false)
    , _levelCalInProgress                       (false)
    , _orientationCalDownSideVisible            (false)
    , _orientationCalUpsideDownSideVisible      (false)
    , _orientationCalLeftSideVisible            (false)
    , _orientationCalRightSideVisible           (false)
    , _orientationCalNoseDownSideVisible        (false)
    , _orientationCalTailDownSideVisible        (false)
    , _orientationCalDownSideState              (SideCalStateIdle)
    , _orientationCalUpsideDownSideState        (SideCalStateIdle)
    , _orientationCalLeftSideState              (SideCalStateIdle)
    , _orientationCalRightSideState             (SideCalStateIdle)
    , _orientationCalNoseDownSideState          (SideCalStateIdle)
    , _orientationCalTailDownSideState          (SideCalStateIdle)
    , _unknownFirmwareVersion                   (false)
    , _waitingForCancel                         (false)
{
    connect(_vehicle, &Vehicle::sensorsParametersResetAck, this, &SensorsComponentController::_handleParametersReset);

    _calibrationStartTimer.setSingleShot(true);
    _calibrationStartTimer.setInterval(6000);
    connect(&_calibrationStartTimer, &QTimer::timeout, this, &SensorsComponentController::_handleCalibrationStartTimeout);

}

bool SensorsComponentController::usingUDPLink(void)
{
    SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (sharedLink) {
        return sharedLink->linkConfiguration()->type() == LinkConfiguration::TypeUdp;
    } else {
        return false;
    }
}

/// Appends the specified text to the status log area in the ui
void SensorsComponentController::_appendStatusLog(const QString& text)
{
    if (!_statusLog) {
        qWarning() << "Internal error";
        return;
    }

    QString varText = text;
    QMetaObject::invokeMethod(_statusLog,
                              "append",
                              Q_ARG(QString, varText));
}

bool SensorsComponentController::_startLogCalibration(void)
{
    if (!_vehicle) {
        QGC::showAppMessage(tr("No active vehicle is available for calibration."));
        return false;
    }

    // Do not arm the start-timeout when there is no transport at all. The
    // command cannot reach the flight controller in that state, so report it
    // immediately and avoid a second, misleading timeout message.
    if (!_vehicle->vehicleLinkManager()->primaryLink().lock()) {
        QGC::showAppMessage(tr("Calibration could not start because the vehicle link is unavailable."));
        return false;
    }

    _unknownFirmwareVersion = false;
    _hideAllCalAreas();
    _waitingForCancel = false;
    _magCalInProgress = false;
    _gyroCalInProgress = false;
    _accelCalInProgress = false;
    _airspeedCalInProgress = false;
    _levelCalInProgress = false;

    connect(_vehicle, &Vehicle::textMessageReceived, this, &SensorsComponentController::_handleUASTextMessage, Qt::UniqueConnection);
    _calibrationStartTimer.start();

    return true;
}

void SensorsComponentController::_startVisualCalibration(void)
{
    _setAllSidesState(SideCalStateIncomplete);

    if (_progressBar) {
        _progressBar->setProperty("value", 0);
    }
}

/// Returns the orientation preview side indicators to the neutral Idle state.
/// Called when the preview switches to a different sensor so completion state from
/// a previous calibration doesn't carry over.
void SensorsComponentController::resetSidesToIdle(void)
{
    if (calibrationActive()) {
        return;
    }
    _setAllSidesState(SideCalStateIdle);
}

void SensorsComponentController::_setAllSidesState(SideCalState state)
{
    _orientationCalDownSideState = state;
    _orientationCalUpsideDownSideState = state;
    _orientationCalLeftSideState = state;
    _orientationCalRightSideState = state;
    _orientationCalTailDownSideState = state;
    _orientationCalNoseDownSideState = state;

    emit orientationCalSidesStateChanged();
}

void SensorsComponentController::_stopCalibration(SensorsComponentController::StopCalibrationCode code)
{
    AudioOutput::instance()->stopCalibrationInstructions();
    _calibrationStartTimer.stop();
    disconnect(_vehicle, &Vehicle::textMessageReceived, this, &SensorsComponentController::_handleUASTextMessage);

    if (code == StopCalibrationSuccess) {
        _setAllSidesState(SideCalStateCompleted);

        if (_progressBar) {
            _progressBar->setProperty("value", 1);
        }
    } else {
        // Calibration results are discarded: return any partially completed sides
        // to the neutral idle preview state
        _setAllSidesState(SideCalStateIdle);

        if (_progressBar) {
            _progressBar->setProperty("value", 0);
        }
    }

    _waitingForCancel = false;
    emit waitingForCancelChanged();

    _refreshParams();

    switch (code) {
        case StopCalibrationSuccess:
            if (_orientationCalAreaHelpText) {
                _orientationCalAreaHelpText->setProperty("text", tr("Calibration complete"));
            }
            if (!_airspeedCalInProgress && !_levelCalInProgress) {
                emit resetStatusTextArea();
            }
            if (_magCalInProgress) {
                emit magCalComplete();
            }
            break;

        case StopCalibrationCancelled:
            emit resetStatusTextArea();
            _hideAllCalAreas();
            break;

        default:
            // Assume failed
            _hideAllCalAreas();
            QGC::showAppMessage(tr("Calibration failed. Calibration log will be displayed."));
            break;
    }

    _magCalInProgress = false;
    _accelCalInProgress = false;
    _gyroCalInProgress = false;
    _airspeedCalInProgress = false;
    _levelCalInProgress = false;

    emit calibrationActiveChanged();
}

void SensorsComponentController::_handleCalibrationStartTimeout(void)
{
    // A PX4 calibration command should produce a "calibration started" text
    // message quickly. If it does not, leave a useful diagnostic instead of
    // leaving the page apparently idle with no explanation.
    if (calibrationActive()) {
        return;
    }

    disconnect(_vehicle, &Vehicle::textMessageReceived, this, &SensorsComponentController::_handleUASTextMessage);
    _appendStatusLog(tr("PX4 did not acknowledge the calibration start within 6 seconds."));
    _appendStatusLog(tr("Check that the vehicle is disarmed, use a telemetry link instead of USB, and move away from metal or magnets."));
    QGC::showAppMessage(tr("PX4 did not start calibration. Check the vehicle state and telemetry link."));
    if (_orientationCalAreaHelpText) {
        _orientationCalAreaHelpText->setProperty("text", tr("PX4 did not start calibration. Check the vehicle state and telemetry link, then try again."));
    }
    _hideAllCalAreas();
}

void SensorsComponentController::calibrateGyro(void)
{
    if (_startLogCalibration()) {
        _vehicle->startCalibration(QGCMAVLink::CalibrationGyro);
    }
}

void SensorsComponentController::calibrateCompass(void)
{
    if (_startLogCalibration()) {
        AudioOutput::instance()->sayCalibrationInstruction(QStringLiteral("请按图示顺逆时针旋转无人机。"));
        _vehicle->startCalibration(QGCMAVLink::CalibrationMag);
    }
}

void SensorsComponentController::calibrateAccel(void)
{
    if (_startLogCalibration()) {
        _vehicle->startCalibration(QGCMAVLink::CalibrationAccel);
    }
}

void SensorsComponentController::calibrateLevel(void)
{
    if (_startLogCalibration()) {
        _vehicle->startCalibration(QGCMAVLink::CalibrationLevel);
    }
}

void SensorsComponentController::calibrateAirspeed(void)
{
    if (_startLogCalibration()) {
        _vehicle->startCalibration(QGCMAVLink::CalibrationPX4Airspeed);
    }
}

void SensorsComponentController::_handleUASTextMessage(int uasId, int compId, int severity, QString text, const QString &description)
{
    Q_UNUSED(compId);
    Q_UNUSED(severity);
    Q_UNUSED(description);

    if (uasId != _vehicle->id()) {
        return;
    }

    // Needed for level horizon calibration
    text.replace("&lt;", "<");
    text.replace("&gt;", ">");

    if (text.contains("progress <")) {
        QString percent = text.split("<").last().split(">").first();
        bool ok;
        int p = percent.toInt(&ok);
        if (ok) {
            if (_progressBar) {
                _progressBar->setProperty("value", (float)(p / 100.0));
            } else {
                qWarning() << "Internal error";
            }
        }
        return;
    }

    _appendStatusLog(text);
    qCDebug(SensorsComponentControllerLog) << text;

    if (_unknownFirmwareVersion) {
        // We don't know how to do visual cal with the version of firwmare
        return;
    }

    // PX4 normally prefixes messages with [cal]. Some telemetry bridges add
    // an INFO/commander prefix or change the capitalization, so locate the
    // tag instead of requiring it at byte zero. This keeps calibration UI
    // working across PX4 versions and MAVLink text-message transports.
    const int calTagIndex = text.indexOf("[cal]", 0, Qt::CaseInsensitive);
    if (calTagIndex >= 0) {
        text = text.mid(calTagIndex + 5).trimmed();
    } else {
        // A few serial/telemetry bridges strip the [cal] tag but keep an
        // INFO/commander prefix. Keep the meaningful calibration suffix.
        const int calibrationIndex = text.indexOf("calibration ", 0, Qt::CaseInsensitive);
        if (calibrationIndex < 0) {
            return;
        }
        text = text.mid(calibrationIndex).trimmed();
    }

    text = text.trimmed();
    const QString lowerText = text.toLower();
    if (lowerText.startsWith("calibration started:")) {
        _calibrationStartTimer.stop();
    }

    QString calStartPrefix("calibration started: ");
    if (lowerText.startsWith(calStartPrefix)) {
        const QString startDetails = text.mid(calStartPrefix.length()).simplified();

        // PX4 v1.x uses "<version> <type>" (for example "2 mag"), while
        // some bridges/firmware builds omit the version. Accept both forms
        // and reject only malformed or unknown calibration types.
        const QStringList parts = startDetails.split(' ', Qt::SkipEmptyParts);
        QString calType;
        bool versionOk = false;
        if (parts.size() >= 2) {
            (void) parts.first().toInt(&versionOk);
            calType = parts.at(1).toLower();
        } else if (parts.size() == 1) {
            calType = parts.first().toLower();
        }

        if (calType.isEmpty()) {
            _unknownFirmwareVersion = true;
            QString msg = tr("Unrecognized PX4 calibration start message, using log");
            _appendStatusLog(msg);
            qDebug() << msg;
            return;
        }

        _startVisualCalibration();

        if (calType == "accel" || calType == "mag" || calType == "gyro") {
            // _startVisualCalibration() above reset all side indicators to Incomplete

            // Reset all visibility
            _orientationCalDownSideVisible = false;
            _orientationCalUpsideDownSideVisible = false;
            _orientationCalLeftSideVisible = false;
            _orientationCalRightSideVisible = false;
            _orientationCalTailDownSideVisible = false;
            _orientationCalNoseDownSideVisible = false;

            if (_orientationCalAreaHelpText) {
                _orientationCalAreaHelpText->setProperty("text", tr("Place your vehicle into one of the Incomplete orientations shown below and hold it still"));
            }

            if (calType == "accel") {
                _accelCalInProgress = true;
                AudioOutput::instance()->sayCalibrationInstruction(QStringLiteral("请按图示放置无人机，等待地面站自动识别。"));
                _orientationCalDownSideVisible = true;
                _orientationCalUpsideDownSideVisible = true;
                _orientationCalLeftSideVisible = true;
                _orientationCalRightSideVisible = true;
                _orientationCalTailDownSideVisible = true;
                _orientationCalNoseDownSideVisible = true;
            } else if (calType == "mag") {

                // Work out what the autopilot is configured to
                int sides = 0;

                if (_vehicle->parameterManager()->parameterExists(ParameterManager::defaultComponentId, "CAL_MAG_SIDES")) {
                    // Read the requested calibration directions off the system
                    sides = _vehicle->parameterManager()->getParameter(ParameterManager::defaultComponentId, "CAL_MAG_SIDES")->rawValue().toFloat();
                } else {
                    // There is no valid setting, default to all six sides
                    sides = (1 << 5) | (1 << 4) | (1 << 3) | (1 << 2) | (1 << 1) | (1 << 0);
                }

                _magCalInProgress = true;
                _orientationCalTailDownSideVisible =   ((sides & (1 << 0)) > 0);
                _orientationCalNoseDownSideVisible =   ((sides & (1 << 1)) > 0);
                _orientationCalLeftSideVisible =       ((sides & (1 << 2)) > 0);
                _orientationCalRightSideVisible =      ((sides & (1 << 3)) > 0);
                _orientationCalUpsideDownSideVisible = ((sides & (1 << 4)) > 0);
                _orientationCalDownSideVisible =       ((sides & (1 << 5)) > 0);
            } else if (calType == "gyro") {
                _gyroCalInProgress = true;
                _orientationCalDownSideVisible = true;
            } else {
                qWarning() << "Unknown calibration message type" << calType << "version field present:" << versionOk;
            }
            emit orientationCalSidesVisibleChanged();
            _updateAndEmitShowOrientationCalArea(true);
        } else if (calType == "airspeed") {
            _airspeedCalInProgress = true;
        } else if (calType == "level") {
            _levelCalInProgress = true;
        }
        emit calibrationActiveChanged();
        return;
    }

    if (lowerText.endsWith("orientation detected")) {
        const QString side = lowerText.section(" ", 0, 0);
        qCDebug(SensorsComponentControllerLog) << "Side started" << side;

        if (side == "down") {
            _orientationCalDownSideState = SideCalStateInProgress;
        } else if (side == "up") {
            _orientationCalUpsideDownSideState = SideCalStateInProgress;
        } else if (side == "left") {
            _orientationCalLeftSideState = SideCalStateInProgress;
        } else if (side == "right") {
            _orientationCalRightSideState = SideCalStateInProgress;
        } else if (side == "front") {
            _orientationCalNoseDownSideState = SideCalStateInProgress;
        } else if (side == "back") {
            _orientationCalTailDownSideState = SideCalStateInProgress;
        }

        if (_magCalInProgress) {
            if (_orientationCalAreaHelpText) {
                _orientationCalAreaHelpText->setProperty("text", tr("Rotate the vehicle continuously as shown in the diagram until marked as Completed"));
            }
        } else {
            if (_orientationCalAreaHelpText) {
                _orientationCalAreaHelpText->setProperty("text", tr("Hold still in the current orientation"));
            }
        }

        emit orientationCalSidesStateChanged();
        return;
    }

    if (lowerText.endsWith("side done, rotate to a different side")) {
        const QString side = lowerText.section(" ", 0, 0);
        qCDebug(SensorsComponentControllerLog) << "Side finished" << side;

        if (side == "down") {
            _orientationCalDownSideState = SideCalStateCompleted;
        } else if (side == "up") {
            _orientationCalUpsideDownSideState = SideCalStateCompleted;
        } else if (side == "left") {
            _orientationCalLeftSideState = SideCalStateCompleted;
        } else if (side == "right") {
            _orientationCalRightSideState = SideCalStateCompleted;
        } else if (side == "front") {
            _orientationCalNoseDownSideState = SideCalStateCompleted;
        } else if (side == "back") {
            _orientationCalTailDownSideState = SideCalStateCompleted;
        }

        if (_orientationCalAreaHelpText) {
            _orientationCalAreaHelpText->setProperty("text", tr("Place you vehicle into one of the orientations shown below and hold it still"));
        }

        emit orientationCalSidesStateChanged();
        return;
    }

    if (lowerText.endsWith("side already completed")) {
        if (_orientationCalAreaHelpText) {
            _orientationCalAreaHelpText->setProperty("text", tr("Orientation already completed, place you vehicle into one of the incomplete orientations shown below and hold it still"));
        }
        return;
    }

    QString calCompletePrefix("calibration done:");
    if (lowerText.startsWith(calCompletePrefix)) {
        _stopCalibration(StopCalibrationSuccess);
        return;
    }

    if (lowerText.startsWith("calibration cancelled")) {
        _stopCalibration(_waitingForCancel ? StopCalibrationCancelled : StopCalibrationFailed);
        return;
    }

    if (lowerText.startsWith("calibration failed")) {
        _stopCalibration(StopCalibrationFailed);
        return;
    }
}

void SensorsComponentController::_refreshParams(void)
{
    _vehicle->parameterManager()->bulkRefresh(ParameterManager::defaultComponentId, {
        QStringLiteral("CAL_MAG0_ID"), QStringLiteral("CAL_MAG1_ID"), QStringLiteral("CAL_MAG2_ID"),
        QStringLiteral("CAL_MAG0_ROT"), QStringLiteral("CAL_MAG1_ROT"), QStringLiteral("CAL_MAG2_ROT"),
        QStringLiteral("CAL_*"),
        QStringLiteral("SENS_*"),
    }, false /* notifyFailure */);
}

void SensorsComponentController::_updateAndEmitShowOrientationCalArea(bool show)
{
    _showOrientationCalArea = show;
    emit showOrientationCalAreaChanged();
}

void SensorsComponentController::_hideAllCalAreas(void)
{
    _updateAndEmitShowOrientationCalArea(false);
}

void SensorsComponentController::cancelCalibration(void)
{
    // The firmware doesn't allow us to cancel calibration. The best we can do is wait
    // for it to timeout.
    _waitingForCancel = true;
    emit waitingForCancelChanged();
    _vehicle->stopCalibration(true /* showError */);
}

void SensorsComponentController::_handleParametersReset(bool success)
{
    if (success) {
        QGC::showAppMessage(tr("Reset successful"));

        QTimer::singleShot(1000, this, [this]() {
            _refreshParams();
        });
    }
    else {
        QGC::showAppMessage(tr("Reset failed"));
    }
}

void SensorsComponentController::resetFactoryParameters()
{
    auto compId = _vehicle->defaultComponentId();

    _vehicle->sendMavCommand(compId,
                             MAV_CMD_PREFLIGHT_STORAGE,
                             true,  // showError
                             3,     // Reset factory parameters
                             -1);   // Don't do anything with mission storage
}
