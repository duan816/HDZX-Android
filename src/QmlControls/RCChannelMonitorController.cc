#include "RCChannelMonitorController.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(RCChannelMonitorControllerLog, "QMLControls.RCChannelMonitorController")

RCChannelMonitorController::RCChannelMonitorController(QObject *parent)
    : FactPanelController(parent)
{
    // qCDebug(RCChannelMonitorControllerLog) << Q_FUNC_INFO << this;

    (void) connect(MultiVehicleManager::instance(), &MultiVehicleManager::activeVehicleChanged,
                   this, &RCChannelMonitorController::_activeVehicleChanged);
    _activeVehicleChanged(MultiVehicleManager::instance()->activeVehicle());
}

RCChannelMonitorController::~RCChannelMonitorController()
{
    // qCDebug(RCChannelMonitorControllerLog) << Q_FUNC_INFO << this;
}

void RCChannelMonitorController::setClampValues(bool clamp)
{
    if (_clampValues != clamp) {
        _clampValues = clamp;
        _connectToSignal();
        emit clampValuesChanged();
    }
}

void RCChannelMonitorController::_connectToSignal()
{
    if (!_rcVehicle) {
        return;
    }
    disconnect(_rcVehicle, &Vehicle::rcChannelsClampedChanged, this, &RCChannelMonitorController::channelValuesChanged);
    disconnect(_rcVehicle, &Vehicle::rcChannelsRawChanged, this, &RCChannelMonitorController::channelValuesChanged);
    if (!_monitoringEnabled) {
        return;
    }
    if (_clampValues) {
        (void) connect(_rcVehicle, &Vehicle::rcChannelsClampedChanged, this, &RCChannelMonitorController::channelValuesChanged);
    } else {
        (void) connect(_rcVehicle, &Vehicle::rcChannelsRawChanged, this, &RCChannelMonitorController::channelValuesChanged);
    }
}

void RCChannelMonitorController::setMonitoringEnabled(bool enabled)
{
    if (_monitoringEnabled == enabled) return;
    _monitoringEnabled = enabled;
    _connectToSignal();
    emit monitoringEnabledChanged();
}

void RCChannelMonitorController::_activeVehicleChanged(Vehicle *vehicle)
{
    if (_rcVehicle) {
        disconnect(_rcVehicle, nullptr, this, nullptr);
    }
    _rcVehicle = vehicle;
    _vehicle = vehicle ? vehicle : MultiVehicleManager::instance()->offlineEditingVehicle();
    if (vehicle) {
        connect(vehicle, &QObject::destroyed, this, [this, vehicle]() {
            if (_vehicle == vehicle) _vehicle = nullptr;
        });
    }
    _chanCount = 0;
    const QPointer<RCChannelMonitorController> guard(this);
    emit channelCountChanged(_chanCount);
    if (!guard) return;
    _connectToSignal();
}

void RCChannelMonitorController::channelValuesChanged(QVector<int> pwmValues)
{
    if (!_monitoringEnabled || !_rcVehicle) return;
    const QPointer<RCChannelMonitorController> guard(this);
    int channelCount = pwmValues.size();

    if (_chanCount != channelCount) {
        _chanCount = channelCount;
        emit channelCountChanged(_chanCount);
        if (!guard || !_monitoringEnabled) return;
    }

    for (int channel = 0; channel < channelCount; channel++) {
        emit channelValueChanged(channel, pwmValues[channel]);
        if (!guard || !_monitoringEnabled) return;
    }
}
