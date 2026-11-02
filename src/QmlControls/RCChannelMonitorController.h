#pragma once

#include "FactPanelController.h"

#include <QtCore/QPointer>

#include <QtQmlIntegration/QtQmlIntegration>

class RCChannelMonitorController : public FactPanelController
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int channelCount READ channelCount NOTIFY channelCountChanged)
    Q_PROPERTY(bool clampValues READ clampValues WRITE setClampValues NOTIFY clampValuesChanged)
    Q_PROPERTY(bool monitoringEnabled READ monitoringEnabled WRITE setMonitoringEnabled NOTIFY monitoringEnabledChanged)

public:
    explicit RCChannelMonitorController(QObject *parent = nullptr);
    ~RCChannelMonitorController();

    int channelCount() const { return _chanCount; }
    bool clampValues() const { return _clampValues; }
    void setClampValues(bool clamp);
    bool monitoringEnabled() const { return _monitoringEnabled; }
    void setMonitoringEnabled(bool enabled);

signals:
    void channelCountChanged(int channelCount);
    void channelValueChanged(int channel, int rcValue);
    void clampValuesChanged();
    void monitoringEnabledChanged();

private slots:
    void channelValuesChanged(QVector<int> pwmValues);
    void _activeVehicleChanged(Vehicle *vehicle);

private:
    void _connectToSignal();

    int _chanCount = 0;
    bool _clampValues = true;
    bool _monitoringEnabled = true;
    QPointer<Vehicle> _rcVehicle;
};
