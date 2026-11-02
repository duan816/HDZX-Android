#pragma once

#include <QtCore/QString>

enum class VehicleMessageStack {
    Any,
    ArduPilot,
    PX4,
};

struct VehicleMessageGuidance {
    QString translation;
    QString solution;
    QString explanation;

    bool isEmpty() const { return translation.isEmpty() && solution.isEmpty() && explanation.isEmpty(); }
};

class VehicleMessageCatalog
{
public:
    static VehicleMessageGuidance lookup(const QString &message, VehicleMessageStack stack = VehicleMessageStack::Any);
};
