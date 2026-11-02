#pragma once
#include <QtCore/QHash>
#include <QtCore/QString>

// Suppress transport duplicates in a burst, never suppress a different fault.
// Call with monotonic elapsed milliseconds, not wall-clock time (midnight-safe).
class VehicleAlertSpeechGate
{
public:
    bool accept(const QString &text, qint64 now)
    {
        if (text.trimmed().isEmpty()) return false;
        const auto previous = _seen.constFind(text);
        if (previous != _seen.cend() && now - previous.value() < 1000) return false;
        if (_seen.size() >= 64 && previous == _seen.cend()) {
            auto oldest = _seen.begin();
            for (auto entry = _seen.begin(); entry != _seen.end(); ++entry)
                if (entry.value() < oldest.value()) oldest = entry;
            _seen.erase(oldest);
        }
        _seen.insert(text, now);
        return true;
    }
private:
    QHash<QString, qint64> _seen;
};
