#include "FactPanelController.h"
#include "AutoPilotPlugin.h"
#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "QGCApplication.h"
#include "QGCLoggingCategory.h"
#include "Vehicle.h"

#include <QtQml/QQmlEngine>

QGC_LOGGING_CATEGORY(FactPanelControllerLog, "FactSystem.FactPanelController")

FactPanelController::FactPanelController(QObject *parent)
    : QObject(parent)
    , _vehicle(MultiVehicleManager::instance()->activeVehicle())
{
    // qCDebug(FactPanelControllerLog) << Q_FUNC_INFO << this;

    if (!_vehicle) {
        _vehicle = MultiVehicleManager::instance()->offlineEditingVehicle();
    }

    _missingParametersTimer.setInterval(500);
    _missingParametersTimer.setSingleShot(true);
    (void) connect(&_missingParametersTimer, &QTimer::timeout, this, &FactPanelController::_checkForMissingParameters);
    if (_vehicle) {
        (void) connect(_vehicle, &QObject::destroyed, this, [this, observedVehicle = _vehicle]() {
            if (_vehicle != observedVehicle) return;
            _missingParametersTimer.stop();
            _missingParameterWaitList.clear();
            _vehicle = nullptr;
        });
    }
}

FactPanelController::~FactPanelController()
{
    // qCDebug(FactPanelControllerLog) << Q_FUNC_INFO << this;
}

void FactPanelController::_reportMissingParameter(int componentId, const QString &name) const
{
    if (!_vehicle) {
        qCWarning(FactPanelControllerLog) << "Cannot report missing parameter after vehicle removal:" << name;
        return;
    }

    if (componentId == ParameterManager::defaultComponentId) {
        componentId = _vehicle->defaultComponentId();
    }

    qgcApp()->reportMissingParameter(componentId, name);
    qCWarning(FactPanelControllerLog) << "Missing parameter:" << componentId << name;
}

bool FactPanelController::_allParametersExists(int componentId, const QStringList &names) const
{
    bool noMissingFacts = true;

    for (const QString &name : names) {
        if (_vehicle && !_vehicle->parameterManager()->parameterExists(componentId, name)) {
            _reportMissingParameter(componentId, name);
            noMissingFacts = false;
        }
    }

    return noMissingFacts;
}

Fact *FactPanelController::getParameterFact(int componentId, const QString &name, bool reportMissing) const
{
    if (_vehicle && _vehicle->parameterManager()->parameterExists(componentId, name)) {
        Fact *const fact = _vehicle->parameterManager()->getParameter(componentId, name);
        QQmlEngine::setObjectOwnership(fact, QQmlEngine::CppOwnership);
        return fact;
    }

    if (reportMissing) {
        _reportMissingParameter(componentId, name);
    }

    return nullptr;
}

bool FactPanelController::parameterExists(int componentId, const QString &name) const
{
    return (_vehicle ? _vehicle->parameterManager()->parameterExists(componentId, name) : false);
}

void FactPanelController::getMissingParameters(const QStringList &rgNames)
{
    if (!_vehicle) {
        qCWarning(FactPanelControllerLog) << "Ignoring missing-parameter request after vehicle removal";
        return;
    }

    for (const QString &name: rgNames) {
        _missingParameterWaitList.append(name);
        _vehicle->parameterManager()->refreshParameter(MAV_COMP_ID_AUTOPILOT1, name);
    }

    _missingParametersTimer.start();
}

void FactPanelController::_checkForMissingParameters()
{
    if (!_vehicle) {
        _missingParameterWaitList.clear();
        return;
    }

    const QStringList waitList = _missingParameterWaitList;
    for (const QString &name: waitList) {
        if (_vehicle->parameterManager()->parameterExists(MAV_COMP_ID_AUTOPILOT1, name)) {
            (void) _missingParameterWaitList.removeOne(name);
        }
    }

    if (_missingParameterWaitList.isEmpty()) {
        emit missingParametersAvailable();
    } else {
        _missingParametersTimer.start();
    }
}
