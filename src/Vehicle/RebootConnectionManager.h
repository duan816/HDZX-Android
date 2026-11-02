#pragma once
#include <QtCore/QElapsedTimer>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QTimer>
#include <QtQmlIntegration/QtQmlIntegration>

#include "LinkConfiguration.h"
class Vehicle;

class RebootConnectionManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Owned by MultiVehicleManager")
    Q_MOC_INCLUDE("Vehicle.h")
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(int systemId READ systemId NOTIFY changed)
    Q_PROPERTY(int stage READ stage NOTIFY changed)
    Q_PROPERTY(Vehicle* progressVehicle READ progressVehicle NOTIFY changed)
public:
    explicit RebootConnectionManager(QObject* parent = nullptr);
    bool begin(Vehicle* vehicle);
    void commandRejected();

    bool active() const { return _active; }

    QString status() const { return _status; }

    int systemId() const { return _systemId; }

    int stage() const { return _stage; }

    Vehicle* progressVehicle() const;

    Q_INVOKABLE void cancel();
signals:
    void changed();

private:
    friend class RebootConnectionManagerTest;
    void _poll();
    void _update(int stage, const QString& text, bool active);
    void _setProgressVehicle(Vehicle* vehicle);
    QPointer<Vehicle> _original;
    QPointer<Vehicle> _progressVehicle;
    QMetaObject::Connection _progressVehicleDestroyed;
    SharedLinkConfigurationPtr _configuration;
    QString _identity;
    QString _status;
    int _systemId = 0;
    int _stage = 0;
    bool _active = false;
    QElapsedTimer _elapsed;
    qint64 _lastAttempt = 0;
    QTimer _timer;
};
