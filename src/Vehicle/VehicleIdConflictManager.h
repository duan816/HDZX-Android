#pragma once

#include <QtCore/QElapsedTimer>
#include <QtCore/QHash>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QSet>
#include <QtCore/QTimer>
#include <QtCore/QVariantList>
#include <QtQmlIntegration/QtQmlIntegration>
#include <functional>
#include <memory>

#include "MAVLinkMessageType.h"

class Fact;
typedef struct __mavlink_param_value_t mavlink_param_value_t;
typedef struct __mavlink_autopilot_version_t mavlink_autopilot_version_t;

/// Quarantines duplicate identities before Vehicle creation/telemetry dispatch.
/// Only confirmed, single-controller USB endpoints can receive an ID write.
class VehicleIdConflictManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Owned by MultiVehicleManager")
    Q_PROPERTY(QVariantList conflicts READ conflicts NOTIFY conflictsChanged)
    Q_PROPERTY(bool hasConflicts READ hasConflicts NOTIFY conflictsChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY conflictsChanged)
    Q_PROPERTY(QString lastResult READ lastResult NOTIFY lastResultChanged)

public:
    struct LinkDetails
    {
        QString name;
        QString usbIdentity;
        QStringList parameterNames;
        bool directUsb = false;
        bool numericCast = false;
        uint8_t channel = 0;
    };

    using MessageSender = std::function<bool(QObject*, mavlink_message_t&)>;
    using BackupWriter = std::function<bool(const QVariantMap&)>;

    explicit VehicleIdConflictManager(QObject* parent = nullptr);
    ~VehicleIdConflictManager() override;

    void setMessageSender(MessageSender sender) { _sender = std::move(sender); }

    void setBackupWriter(BackupWriter writer) { _backupWriter = std::move(writer); }

    void setGroundStationId(int id);
    bool acceptMessage(QObject* link, const LinkDetails& details, const mavlink_message_t& message);
    void removeLink(QObject* link);
    QString identityForLink(QObject* link,int systemId) const;

    QVariantList conflicts() const;
    bool hasConflicts() const;
    bool busy() const;

    QString lastResult() const { return _lastResult; }

    Q_INVOKABLE bool repair(const QString& token, int expectedNewId);
    Q_INVOKABLE bool restartAssignedController(const QString& token);
    Q_INVOKABLE void retryProbe(const QString& token);

signals:
    void conflictsChanged();
    void lastResultChanged();
    void systemIdQuarantined(int systemId);

private:
    friend class VehicleIdConflictManagerTest;
    enum class Role
    {
        Primary,
        Pending,
        Redundant,
        Conflict,
        Ambiguous,
        Writing,
        AwaitRestart,
        Uncertain
    };

    struct Entry
    {
        QString token;
        QPointer<QObject> link;
        LinkDetails details;
        int systemId = 0;
        int autopilot = -1;
        int vehicleType = -1;
        int desiredId = 0;
        int lastHeartbeatId = 0;
        bool armed = true;
        bool acknowledgement = false;
        bool newHeartbeat = false;
        qint64 heartbeatAt = -1;
        qint64 probeAt = -1;
        qint64 writeAt = -1;
        int probes = 0;
        QByteArray identity;
        QPointer<Fact> idFact;
        uint8_t paramType = 0;
        Role role = Role::Primary;
        QString status;
    };

    using EntryPtr = std::shared_ptr<Entry>;
    qint64 _now() const;
    EntryPtr _find(QObject* link, int systemId) const;
    EntryPtr _byToken(const QString& token) const;
    EntryPtr _owner(int systemId, const Entry* except = nullptr) const;
    bool _sameHardware(const Entry& first, const Entry& second) const;
    bool _freshAndLocked(const Entry& entry) const;
    bool _canRepair(const Entry& entry) const;
    bool _singleControllerLink(const Entry& entry) const;
    int _proposedId(const Entry& entry) const;
    void _resolve();
    void _probe(Entry& entry);
    void _writeId(const QString& token, const QVariant& value);
    void _complete(Entry& entry);
    void _poll();
    void _setResult(const QString& result);
    void _publish();
    void _quarantineSystem(Entry& entry);
    bool _send(Entry& entry, mavlink_message_t& message);
    static int _decodeId(const mavlink_param_value_t& parameter, bool numericCast);
    static float _encodeId(int id, uint8_t type, bool numericCast);
    static QByteArray _hardwareIdentity(const mavlink_autopilot_version_t& version);
    static bool _isIssue(Role role);

    QList<EntryPtr> _entries;
    QHash<QObject*, QSet<int>> _retiredIds;
    QSet<QObject*> _trackedLinks;
    QHash<QByteArray, int> _pendingRestart;
    QHash<int, qint64> _observedIds;
    QVariantList _publishedRows;
    bool _publishedBusy = false;
    QTimer _pollTimer;
    QElapsedTimer _clock;
    std::function<qint64()> _testClock;
    MessageSender _sender;
    BackupWriter _backupWriter;
    int _gcsId = 255;
    quint64 _nextToken = 1;
    QString _lastResult;
};
