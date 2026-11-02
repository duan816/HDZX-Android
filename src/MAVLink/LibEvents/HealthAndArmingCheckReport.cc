#include "HealthAndArmingCheckReport.h"
#include "EventHandler.h"
#include "QmlObjectListModel.h"
#include "LibEvents.h"
#include "MAVLinkEnums.h"
#include "QGCLoggingCategory.h"
#include "VehicleMessageCatalog.h"
#include <QtCore/QSet>

QGC_LOGGING_CATEGORY(HealthAndArmingCheckReportLog, "MAVLink.LibEvents.HealthAndArmingCheckReport")

HealthAndArmingCheckProblem::HealthAndArmingCheckProblem(const QString& message, const QString& description, const QString& severity,
                                                         const QString& translation, const QString& solution,
                                                         const QString& explanation, QObject *parent)
    : QObject(parent)
    , _message(message)
    , _description(description)
    , _severity(severity)
    , _translation(translation)
    , _solution(solution)
    , _explanation(explanation)
{
    qCDebug(HealthAndArmingCheckReportLog) << this;
}

/*===========================================================================*/

HealthAndArmingCheckReport::HealthAndArmingCheckReport(QObject *parent)
    : QObject(parent)
    , _problemsForCurrentMode(new QmlObjectListModel(this))
{
    qCDebug(HealthAndArmingCheckReportLog) << this;
}

HealthAndArmingCheckReport::~HealthAndArmingCheckReport()
{
    _problemsForCurrentMode->clearAndDeleteContents();
}

void HealthAndArmingCheckReport::update(uint8_t compid, const EventHandler &eventHandler, int flightModeGroup)
{
    if (compid != MAV_COMP_ID_AUTOPILOT1) {
        return;
    }
    if (flightModeGroup == -1) {
        qCWarning(HealthAndArmingCheckReportLog) << "Flight mode group not set";
        return;
    }
    _supported = true;

    const events::HealthAndArmingChecks::Results &results = eventHandler.healthAndArmingChecks()->results();

    QSet<QString> previousProblems;
    for (int i = 0; i < _problemsForCurrentMode->count(); ++i) {
        const auto *problem = qobject_cast<HealthAndArmingCheckProblem *>(_problemsForCurrentMode->get(i));
        if (problem && !problem->severity().isEmpty()) {
            previousProblems.insert(problem->message());
        }
    }
    _problemsForCurrentMode->clearAndDeleteContents();
    _hasWarningsOrErrors = false;
    for (const auto& check : results.checks(flightModeGroup)) {
        QString severity = "";
        if (events::externalLogLevel(check.log_levels) <= events::Log::Error) {
            severity = "error";
            _hasWarningsOrErrors = true;
        } else if (events::externalLogLevel(check.log_levels) <= events::Log::Warning) {
            severity = "warning";
            _hasWarningsOrErrors = true;
        }

        const QString message = QString::fromStdString(check.message);
        const VehicleMessageGuidance guidance = VehicleMessageCatalog::lookup(message, VehicleMessageStack::PX4);
        QString description = QString::fromStdString(check.description);
        _problemsForCurrentMode->append(new HealthAndArmingCheckProblem(
            message,
            description.replace("\n", "<br/>"),
            severity,
            guidance.translation,
            guidance.solution,
            guidance.explanation,
            this));
        if (!severity.isEmpty() && !previousProblems.contains(message)) {
            emit newProblem(message, guidance.translation);
        }
    }

    _canArm = results.canArm(flightModeGroup);
    if (_missionModeGroup != -1) {
        // TODO: use results.canRun(_missionModeGroup) while armed
        _canStartMission = results.canArm(_missionModeGroup);
    }
    if (_takeoffModeGroup != -1) {
        _canTakeoff = results.canArm(_takeoffModeGroup);
    }

    const auto& healthComponents = results.healthComponents().health_components;

    // GPS state
    const auto gpsStateIter = healthComponents.find("gps");
    if (gpsStateIter != healthComponents.end()) {
        const events::HealthAndArmingChecks::HealthComponent& gpsState = gpsStateIter->second;
        if (gpsState.health.error || gpsState.arming_check.error) {
            _gpsState = "red";
        } else if (gpsState.health.warning || gpsState.arming_check.warning) {
            _gpsState = "yellow";
        } else {
            _gpsState = "green";
        }
    }

    emit updated();
}

void HealthAndArmingCheckReport::setModeGroups(int takeoffModeGroup, int missionModeGroup)
{
    _takeoffModeGroup = takeoffModeGroup;
    _missionModeGroup = missionModeGroup;
}
