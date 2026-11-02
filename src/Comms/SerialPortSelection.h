#pragma once

#include <QtCore/QList>
#include <QtCore/QMap>
#include <QtCore/QStringList>
#include <algorithm>

namespace SerialPortSelection {

// Use interface roles before deduplicating a composite USB device. Port numbers
// and operating-system enumeration order do not identify the MAVLink interface.
template<typename PortInfo>
QList<PortInfo> mavlinkAutoConnectPorts(QList<PortInfo> ports)
{
    ports.removeIf([](const PortInfo& port) {
        return port.description().contains(QStringLiteral("SLCAN"), Qt::CaseInsensitive);
    });
    std::stable_sort(ports.begin(), ports.end(), [](const PortInfo& left, const PortInfo& right) {
        return left.description().contains(QStringLiteral("MAVLink"), Qt::CaseInsensitive)
            && !right.description().contains(QStringLiteral("MAVLink"), Qt::CaseInsensitive);
    });
    QMap<QPair<quint16, quint16>, QStringList> seen;
    ports.removeIf([&seen](const PortInfo& port) {
        if (!port.hasVendorIdentifier() || !port.hasProductIdentifier()
            || port.serialNumber().isEmpty() || port.serialNumber() == QLatin1String("0")) return false;
        const QPair<quint16, quint16> id{port.vendorIdentifier(), port.productIdentifier()};
        const bool duplicate = seen[id].contains(port.serialNumber());
        seen[id].append(port.serialNumber());
        return duplicate && !port.description().contains(QStringLiteral("NMEA"), Qt::CaseInsensitive);
    });
    return ports;
}

template<typename PortInfo>
QString displayName(const PortInfo& port)
{
    const QString description = !port.description().trimmed().isEmpty() ? port.description().trimmed() : port.manufacturer().trimmed();
    const QString name = port.portName().trimmed();
    if (description.isEmpty()) return name.isEmpty() ? port.systemLocation().trimmed() : name;
    const QString suffix = QStringLiteral("(%1)").arg(name);
    return description.endsWith(suffix, Qt::CaseInsensitive) ? description : QStringLiteral("%1 %2").arg(description, suffix);
}

}
