#pragma once

#include <QtCore/QElapsedTimer>
#include <QtCore/QHash>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QTimer>
#include <QtQmlIntegration/QtQmlIntegration>

#include "MAVLinkMessageType.h"

class Vehicle;

// Tracks receipt/freshness only. Display values remain in the standard Facts.
class HQDashboardController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_MOC_INCLUDE("Vehicle.h")
    Q_PROPERTY(Vehicle *vehicle READ vehicle WRITE setVehicle NOTIFY vehicleChanged)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)

public:
    explicit HQDashboardController(QObject *parent = nullptr);
    Vehicle *vehicle() const;
    void setVehicle(Vehicle *vehicle);
    int revision() const { return _revision; }
    Q_INVOKABLE bool available(const QString &field) const;

signals:
    void vehicleChanged();
    void revisionChanged();

private:
    void _clearSamples();
    void _invalidateForeignMessage(const mavlink_message_t &message);
    void _messageReceived(const mavlink_message_t &message);
    void _mark(const QString &field, bool valid = true);
    QPointer<Vehicle> _vehicle;
    QElapsedTimer _clock;
    QTimer _refresh;
    QHash<QString, qint64> _received;
    QMetaObject::Connection _communicationLostConnection;
    QMetaObject::Connection _allLinksRemovedConnection;
    int _revision = 0;
    bool _altitudeSeen = false;
    bool _linksRemoved = false;
    bool _freshnessChanged = false;
};
