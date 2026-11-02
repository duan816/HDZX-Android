#pragma once

#include <QtCore/QList>
#include <QtCore/QString>
#include <QtCore/QStringList>

// Only receipt of a message changes the current warning. Expiry never brings an
// older warning back to the foreground; the message history remains elsewhere.
class RecentVehicleWarnings
{
public:
    struct Entry { QString text; int severity; qint64 lastSeen; bool prearm; bool healthReport = false; };
    static constexpr qint64 lifetimeMs = 45000; // ArduPilot commonly sends PreArm batches ~31 seconds apart.
    static constexpr qint64 transientLifetimeMs = 10000;
    static constexpr int capacity = 20;
    bool add(const QString &text, int severity, bool prearm, qint64 now, bool healthReport = false, bool selectLatest = true)
    {
        if (text.trimmed().isEmpty()) return false;
        if (selectLatest) {
            _latestText = text;
            if (!prearm && !healthReport) _latestTransientText = text;
        }
        for (auto &entry : _entries) {
            if (entry.text == text) {
                const bool changed = entry.severity != severity || entry.prearm != prearm || entry.healthReport != healthReport;
                entry = {text, severity, now, prearm, healthReport};
                return selectLatest || changed;
            }
        }
        if (_entries.size() == capacity) _entries.removeFirst();
        _entries.append({text, severity, now, prearm, healthReport});
        return true;
    }
    bool contains(const QString &text) const {
        for (const auto &entry : _entries) if (entry.text == text) return true;
        return false;
    }
    bool syncHealth(const QStringList &active, qint64 now)
    {
        const bool wasHealth = latest() && latest()->healthReport;
        const bool removed = _entries.removeIf([&active](const Entry &entry) { return entry.healthReport && !active.contains(entry.text); }) > 0;
        for (auto &entry : _entries) if (entry.healthReport) entry.lastSeen = now;
        if (wasHealth && !latest()) {
            for (auto entry = _entries.crbegin(); entry != _entries.crend(); ++entry) {
                if (entry->healthReport) { _latestText = entry->text; break; }
            }
        }
        return removed;
    }
    bool expire(qint64 now)
    {
        return _entries.removeIf([now](const Entry &entry) {
            return !entry.healthReport && now - entry.lastSeen >= (entry.prearm ? lifetimeMs : transientLifetimeMs);
        }) > 0;
    }
    bool clearPrearm()
    {
        return _entries.removeIf([](const Entry &entry) { return entry.prearm && !entry.healthReport; }) > 0;
    }
    const Entry *latest() const
    {
        for (const auto &entry : _entries) if (entry.text == _latestText) return &entry;
        return nullptr;
    }
    const QList<Entry> &entries() const { return _entries; }
    const Entry *latestTransient() const
    {
        for (const auto &entry : _entries)
            if (!entry.prearm && !entry.healthReport && entry.text == _latestTransientText) return &entry;
        return nullptr;
    }
private:
    QList<Entry> _entries;
    QString _latestText;
    QString _latestTransientText;
};
