#include "VehicleIdConflictManager.h"

#include <QtCore/QDateTime>
#include <algorithm>
#include <cmath>

#include "Fact.h"
#include "MAVLinkLib.h"

namespace {
FactMetaData::ValueType_t factType(uint8_t type)
{
    switch (type) {
        case MAV_PARAM_TYPE_UINT8:
            return FactMetaData::valueTypeUint8;
        case MAV_PARAM_TYPE_INT8:
            return FactMetaData::valueTypeInt8;
        case MAV_PARAM_TYPE_UINT16:
            return FactMetaData::valueTypeUint16;
        case MAV_PARAM_TYPE_INT16:
            return FactMetaData::valueTypeInt16;
        case MAV_PARAM_TYPE_UINT32:
            return FactMetaData::valueTypeUint32;
        case MAV_PARAM_TYPE_INT32:
            return FactMetaData::valueTypeInt32;
        default:
            return FactMetaData::valueTypeFloat;
    }
}
}  // namespace

VehicleIdConflictManager::VehicleIdConflictManager(QObject* parent) : QObject(parent)
{
    _clock.start();
    _pollTimer.setInterval(300);
    connect(&_pollTimer, &QTimer::timeout, this, &VehicleIdConflictManager::_poll);
    _pollTimer.start();
}

VehicleIdConflictManager::~VehicleIdConflictManager() = default;
QString VehicleIdConflictManager::identityForLink(QObject* link,int systemId) const {
    const auto entry=_find(link,systemId);return entry?QString::fromLatin1(entry->identity):QString();
}

qint64 VehicleIdConflictManager::_now() const
{
    return _testClock ? _testClock() : _clock.elapsed();
}

void VehicleIdConflictManager::setGroundStationId(int id)
{
    if (id <= 0 || id > 255 || id == _gcsId)
        return;
    _gcsId = id;
    for (const auto& entry : _entries) {
        if (entry->systemId == id && entry->role == Role::Primary) {
            entry->role = Role::Conflict;
            emit systemIdQuarantined(id);
        }
    }
    _resolve();
    _publish();
}

bool VehicleIdConflictManager::_isIssue(Role role)
{
    return role != Role::Primary && role != Role::Redundant;
}

VehicleIdConflictManager::EntryPtr VehicleIdConflictManager::_find(QObject* link, int id) const
{
    for (const auto& entry : _entries) {
        if (entry->link == link && (entry->systemId == id || (entry->desiredId > 0 && entry->desiredId == id)))
            return entry;
    }
    return {};
}

VehicleIdConflictManager::EntryPtr VehicleIdConflictManager::_byToken(const QString& token) const
{
    for (const auto& entry : _entries)
        if (entry->token == token && entry->link)
            return entry;
    return {};
}

VehicleIdConflictManager::EntryPtr VehicleIdConflictManager::_owner(int id, const Entry* except) const
{
    for (const auto& entry : _entries) {
        if (entry.get() != except && entry->link && entry->systemId == id && entry->role == Role::Primary)
            return entry;
    }
    return {};
}

bool VehicleIdConflictManager::_sameHardware(const Entry& first, const Entry& second) const
{
    if (!first.identity.isEmpty() && !second.identity.isEmpty())
        return first.identity == second.identity;
    return first.details.directUsb && second.details.directUsb && !first.details.usbIdentity.isEmpty() &&
           first.details.usbIdentity == second.details.usbIdentity;
}

QByteArray VehicleIdConflictManager::_hardwareIdentity(const mavlink_autopilot_version_t& version)
{
    const QByteArray uid2(reinterpret_cast<const char*>(version.uid2), MAVLINK_MSG_AUTOPILOT_VERSION_FIELD_UID2_LEN);
    if (std::any_of(uid2.cbegin(), uid2.cend(), [](char byte) { return byte != 0; }))
        return QByteArrayLiteral("uid2:") + uid2.toHex();
    return version.uid ? QByteArrayLiteral("uid:") + QByteArray::number(version.uid) : QByteArray();
}

bool VehicleIdConflictManager::_freshAndLocked(const Entry& entry) const
{
    const qint64 age = _now() - entry.heartbeatAt;
    return entry.link && entry.heartbeatAt >= 0 && age >= 0 && age <= 2500 && !entry.armed;
}

bool VehicleIdConflictManager::_singleControllerLink(const Entry& entry) const
{
    for (const auto& other : _entries) {
        if (other.get() != &entry && other->link == entry.link && other->systemId != entry.systemId)
            return false;
    }
    return entry.role != Role::Ambiguous;
}

bool VehicleIdConflictManager::busy() const
{
    return std::any_of(_entries.cbegin(), _entries.cend(), [](const EntryPtr& e) {
        return e->link && (e->role == Role::Writing || e->role == Role::AwaitRestart || e->role == Role::Uncertain);
    });
}

bool VehicleIdConflictManager::hasConflicts() const
{
    return std::any_of(_entries.cbegin(), _entries.cend(),
                       [](const EntryPtr& e) { return e->link && _isIssue(e->role); });
}

int VehicleIdConflictManager::_proposedId(const Entry& entry) const
{
    QSet<int> used{_gcsId, entry.systemId};
    for (const auto& e : _entries) {
        if (e->link)
            used.insert(e->systemId);
        if (e->desiredId > 0)
            used.insert(e->desiredId);
    }
    for (int id : _pendingRestart)
        used.insert(id);
    for (auto it = _observedIds.cbegin(); it != _observedIds.cend(); ++it)
        if (_now() - it.value() <= 15000)
            used.insert(it.key());
    const int maximum = entry.paramType == MAV_PARAM_TYPE_INT8 ? 127 : 254;
    for (int id = 1; id <= maximum; ++id)
        if (!used.contains(id))
            return id;
    return 0;
}

bool VehicleIdConflictManager::_canRepair(const Entry& entry) const
{
    if (entry.role != Role::Conflict || busy() || !entry.details.directUsb || !_singleControllerLink(entry) ||
        !_freshAndLocked(entry) || !entry.idFact || entry.idFact->rawValue().toInt() != entry.systemId ||
        entry.identity.isEmpty() || _proposedId(entry) == 0)
        return false;
    const auto owner = _owner(entry.systemId, &entry);
    return entry.systemId == _gcsId ||
           (owner && _freshAndLocked(*owner) && !owner->identity.isEmpty() && owner->identity != entry.identity);
}

QVariantList VehicleIdConflictManager::conflicts() const
{
    QVariantList rows;
    for (const auto& entry : _entries) {
        if (!entry->link || !_isIssue(entry->role))
            continue;
        QString reason = entry->status;
        if (entry->role == Role::Conflict) {
            if (!entry->details.directUsb || !_singleControllerLink(*entry))
                reason = tr("请通过 USB 分别连接飞控后分配编号");
            else if (!_freshAndLocked(*entry))
                reason = tr("等待新鲜心跳；请先锁定飞控");
            else if (!entry->idFact || entry->identity.isEmpty())
                reason = tr("正在读取硬件身份与编号参数");
            else if (const auto owner = _owner(entry->systemId, entry.get()); owner && !_freshAndLocked(*owner))
                reason = tr("请先锁定所有冲突飞控，并等待稳定心跳");
            else if (_proposedId(*entry) == 0)
                reason = tr("没有可用编号，请断开多余设备后重试");
            else
                reason = tr("编号重复，已隔离此端口；可自动分配未占用编号");
        }
        rows.append(
            QVariantMap{{QStringLiteral("token"), entry->token},
                        {QStringLiteral("port"), entry->details.name},
                        {QStringLiteral("systemId"), entry->systemId},
                        {QStringLiteral("newId"), entry->desiredId > 0 ? entry->desiredId : _proposedId(*entry)},
                        {QStringLiteral("identity"), QString::fromLatin1(entry->identity)},
                        {QStringLiteral("hardwareShort"),
                         QString::fromLatin1(entry->identity.startsWith("uid2:") ? entry->identity.mid(5, 24).right(8)
                                                                                 : entry->identity.right(8))},
                        {QStringLiteral("parameter"), entry->idFact ? entry->idFact->name() : QString()},
                        {QStringLiteral("status"), reason},
                        {QStringLiteral("canRepair"), _canRepair(*entry)},
                        {QStringLiteral("canRetry"), entry->role == Role::Pending || entry->role == Role::Conflict},
                        {QStringLiteral("canRestart"), entry->role == Role::AwaitRestart && entry->acknowledgement &&
                                                           entry->details.directUsb && _singleControllerLink(*entry) &&
                                                           _freshAndLocked(*entry)}});
    }
    return rows;
}

void VehicleIdConflictManager::_setResult(const QString& result)
{
    if (_lastResult != result) {
        _lastResult = result;
        emit lastResultChanged();
    }
}

void VehicleIdConflictManager::_publish()
{
    const QVariantList rows = conflicts();
    const bool currentBusy = busy();
    if (rows != _publishedRows || currentBusy != _publishedBusy) {
        _publishedRows = rows;
        _publishedBusy = currentBusy;
        emit conflictsChanged();
    }
}

void VehicleIdConflictManager::_quarantineSystem(Entry& entry)
{
    if (entry.role == Role::Ambiguous)
        return;
    entry.role = Role::Ambiguous;
    entry.status = tr("同一链路发现多个硬件身份，无法定向改号；请分别接 USB");
    _setResult(entry.status);
    emit systemIdQuarantined(entry.systemId);
}

void VehicleIdConflictManager::_resolve()
{
    for (const auto& entry : _entries) {
        if (!entry->link ||
            (entry->role != Role::Pending && entry->role != Role::Conflict && entry->role != Role::Redundant))
            continue;
        const auto owner = _owner(entry->systemId, entry.get());
        if (entry->systemId == _gcsId)
            entry->role = Role::Conflict;
        else if (!owner) {
            entry->role = Role::Primary;
            entry->status.clear();
        } else if (_sameHardware(*owner, *entry)) {
            entry->role = Role::Redundant;
            entry->status.clear();
        } else if ((!entry->identity.isEmpty() && !owner->identity.isEmpty()) ||
                   (entry->autopilot > 0 && owner->autopilot > 0 && entry->autopilot != owner->autopilot))
            entry->role = Role::Conflict;
        else
            entry->role = Role::Pending;
    }
}

int VehicleIdConflictManager::_decodeId(const mavlink_param_value_t& parameter, bool cast)
{
    double value = parameter.param_value;
    if (!cast) {
        mavlink_param_union_t data{};
        data.param_float = parameter.param_value;
        switch (parameter.param_type) {
            case MAV_PARAM_TYPE_UINT8:
                value = data.param_uint8;
                break;
            case MAV_PARAM_TYPE_INT8:
                value = data.param_int8;
                break;
            case MAV_PARAM_TYPE_UINT16:
                value = data.param_uint16;
                break;
            case MAV_PARAM_TYPE_INT16:
                value = data.param_int16;
                break;
            case MAV_PARAM_TYPE_UINT32:
                value = data.param_uint32;
                break;
            case MAV_PARAM_TYPE_INT32:
                value = data.param_int32;
                break;
            case MAV_PARAM_TYPE_REAL32:
                break;
            default:
                return 0;
        }
    } else if (parameter.param_type < MAV_PARAM_TYPE_UINT8 || parameter.param_type > MAV_PARAM_TYPE_REAL32 ||
               parameter.param_type == MAV_PARAM_TYPE_UINT64 || parameter.param_type == MAV_PARAM_TYPE_INT64)
        return 0;
    return std::isfinite(value) && value >= 1 && value <= 255 && std::floor(value) == value ? static_cast<int>(value)
                                                                                            : 0;
}

float VehicleIdConflictManager::_encodeId(int id, uint8_t type, bool cast)
{
    if (cast || type == MAV_PARAM_TYPE_REAL32)
        return static_cast<float>(id);
    mavlink_param_union_t data{};
    switch (type) {
        case MAV_PARAM_TYPE_UINT8:
            data.param_uint8 = static_cast<uint8_t>(id);
            break;
        case MAV_PARAM_TYPE_INT8:
            data.param_int8 = static_cast<int8_t>(id);
            break;
        case MAV_PARAM_TYPE_UINT16:
            data.param_uint16 = static_cast<uint16_t>(id);
            break;
        case MAV_PARAM_TYPE_INT16:
            data.param_int16 = static_cast<int16_t>(id);
            break;
        case MAV_PARAM_TYPE_UINT32:
            data.param_uint32 = static_cast<uint32_t>(id);
            break;
        case MAV_PARAM_TYPE_INT32:
            data.param_int32 = id;
            break;
        default:
            break;
    }
    return data.param_float;
}

bool VehicleIdConflictManager::acceptMessage(QObject* link, const LinkDetails& details,
                                             const mavlink_message_t& message)
{
    if (!link || message.sysid == 0) {
        for (const auto& entry : _entries)
            if (entry->link == link && _isIssue(entry->role))
                return false;
        return true;
    }
    _observedIds.insert(message.sysid, _now());
    if (_retiredIds.value(link).contains(message.sysid))
        return false;
    auto entry = _find(link, message.sysid);
    const bool heartbeat = message.msgid == MAVLINK_MSG_ID_HEARTBEAT && message.compid == MAV_COMP_ID_AUTOPILOT1;
    if (!entry) {
        if (!heartbeat && !_owner(message.sysid))
            return true;
        if (heartbeat) {
            mavlink_heartbeat_t packet{};
            mavlink_msg_heartbeat_decode(&message, &packet);
            if (packet.type == MAV_TYPE_GCS || packet.type == MAV_TYPE_ONBOARD_CONTROLLER ||
                packet.type == MAV_TYPE_GIMBAL || packet.type == MAV_TYPE_ADSB)
                return true;
        }
        entry = std::make_shared<Entry>();
        entry->token = QString::number(_nextToken++);
        entry->link = link;
        entry->details = details;
        entry->systemId = message.sysid;
        entry->role = _owner(message.sysid) || message.sysid == _gcsId ? Role::Pending : Role::Primary;
        entry->status = tr("第二路已隔离，正在确认是同机冗余链路还是另一台飞控");
        _entries.append(entry);
        if (!_trackedLinks.contains(link)) {
            _trackedLinks.insert(link);
            connect(link, &QObject::destroyed, this, [this, link]() { removeLink(link); });
        }
    }
    if (!details.parameterNames.isEmpty()) {
        entry->details.parameterNames = details.parameterNames;
        entry->details.numericCast = details.numericCast;
    }
    if (heartbeat) {
        mavlink_heartbeat_t packet{};
        mavlink_msg_heartbeat_decode(&message, &packet);
        entry->autopilot = packet.autopilot;
        entry->vehicleType = packet.type;
        entry->armed = (packet.base_mode & MAV_MODE_FLAG_SAFETY_ARMED) != 0;
        entry->heartbeatAt = _now();
        entry->lastHeartbeatId = message.sysid;
        if (entry->desiredId && message.sysid == entry->desiredId)
            entry->newHeartbeat = true;
    } else if (message.compid == MAV_COMP_ID_AUTOPILOT1 && message.msgid == MAVLINK_MSG_ID_AUTOPILOT_VERSION) {
        mavlink_autopilot_version_t version{};
        mavlink_msg_autopilot_version_decode(&message, &version);
        const QByteArray identity = _hardwareIdentity(version);
        if (!identity.isEmpty()) {
            if (!entry->identity.isEmpty() && entry->identity != identity)
                _quarantineSystem(*entry);
            else if (entry->identity.isEmpty()) {
                entry->identity = identity;
                entry->probes = 0;
                entry->probeAt = -1;
            }
            if (_pendingRestart.contains(identity)) {
                const int expected = _pendingRestart.value(identity);
                if (entry->systemId == expected) {
                    _setResult(tr("重新连接后已识别硬件身份，当前编号为 %1；正在核对参数").arg(expected));
                    entry->probes = 0;
                }
            }
        }
    } else if (message.compid == MAV_COMP_ID_AUTOPILOT1 && message.msgid == MAVLINK_MSG_ID_PARAM_VALUE) {
        mavlink_param_value_t parameter{};
        mavlink_msg_param_value_decode(&message, &parameter);
        const QString name = QString::fromLatin1(parameter.param_id, MAVLINK_MSG_PARAM_VALUE_FIELD_PARAM_ID_LEN)
                                 .section(QChar::Null, 0, 0);
        const int value = _decodeId(parameter, entry->details.numericCast);
        if (value && entry->details.parameterNames.contains(name)) {
            if (!entry->idFact) {
                entry->idFact = new Fact(MAV_COMP_ID_AUTOPILOT1, name, factType(parameter.param_type), this);
                entry->idFact->metaData()->setRawMin(1);
                entry->idFact->metaData()->setRawMax(255);
                entry->paramType = parameter.param_type;
                connect(entry->idFact, &Fact::containerRawValueChanged, this,
                        [this, token = entry->token](const QVariant& newValue) { _writeId(token, newValue); });
            }
            if (entry->idFact->name() == name && entry->paramType == parameter.param_type) {
                entry->idFact->containerSetRawValue(value);
                if (entry->desiredId == value && entry->writeAt >= 0)
                    entry->acknowledgement = true;
                if (_pendingRestart.contains(entry->identity) && value == entry->systemId) {
                    const int expected = _pendingRestart.take(entry->identity);
                    _setResult(value == expected ? tr("自动编号完成，重新连接后已确认 %1 号机").arg(value)
                                                 : tr("重新读取确认编号仍为 %1；没有自动再次写入").arg(value));
                }
            }
        }
    }
    if ((entry->role == Role::Writing || entry->role == Role::AwaitRestart || entry->role == Role::Uncertain) &&
        entry->desiredId && entry->acknowledgement && entry->newHeartbeat)
        _complete(*entry);
    _resolve();
    if (entry->role == Role::Pending || entry->role == Role::Conflict) {
        _probe(*entry);
        const auto owner = _owner(entry->systemId, entry.get());
        if (owner && owner->identity.isEmpty())
            _probe(*owner);
    } else if (_pendingRestart.contains(entry->identity))
        _probe(*entry);
    if (heartbeat || message.msgid == MAVLINK_MSG_ID_AUTOPILOT_VERSION || message.msgid == MAVLINK_MSG_ID_PARAM_VALUE)
        _publish();
    return (entry->role == Role::Primary || entry->role == Role::Redundant) && message.sysid == entry->systemId;
}

bool VehicleIdConflictManager::_send(Entry& entry, mavlink_message_t& message)
{
    return entry.link && _sender && _sender(entry.link, message);
}

void VehicleIdConflictManager::_probe(Entry& entry)
{
    if (!entry.link || entry.autopilot < 0 || entry.probes >= 4 ||
        (entry.probeAt >= 0 && _now() - entry.probeAt < 1800))
        return;
    if (!entry.identity.isEmpty() && entry.idFact && !_pendingRestart.contains(entry.identity))
        return;
    entry.probeAt = _now();
    ++entry.probes;
    mavlink_message_t message{};
    if (entry.identity.isEmpty()) {
        // Different command ID from normal initial-connect REQUEST_MESSAGE.
        mavlink_msg_command_long_pack_chan(_gcsId, MAV_COMP_ID_MISSIONPLANNER, entry.details.channel, &message,
                                           entry.systemId, MAV_COMP_ID_AUTOPILOT1,
                                           MAV_CMD_REQUEST_AUTOPILOT_CAPABILITIES, 0, 1, 0, 0, 0, 0, 0, 0);
        _send(entry, message);
        return;
    }
    for (const QString& name : entry.details.parameterNames) {
        const QByteArray bytes = name.toLatin1().left(MAVLINK_MSG_PARAM_REQUEST_READ_FIELD_PARAM_ID_LEN);
        char id[MAVLINK_MSG_PARAM_REQUEST_READ_FIELD_PARAM_ID_LEN]{};
        std::copy(bytes.cbegin(), bytes.cend(), id);
        mavlink_msg_param_request_read_pack_chan(_gcsId, MAV_COMP_ID_MISSIONPLANNER, entry.details.channel, &message,
                                                 entry.systemId, MAV_COMP_ID_AUTOPILOT1, id, -1);
        _send(entry, message);
    }
}

bool VehicleIdConflictManager::repair(const QString& token, int expectedNewId)
{
    const auto entry = _byToken(token);
    if (!entry || !_canRepair(*entry) || expectedNewId != _proposedId(*entry)) {
        _setResult(tr("连接、编号或解锁状态已变化，请重新确认；未写入参数"));
        return false;
    }
    const QVariantMap backup{{QStringLiteral("identity"), QString::fromLatin1(entry->identity)},
                             {QStringLiteral("port"), entry->details.name},
                             {QStringLiteral("parameter"), entry->idFact->name()},
                             {QStringLiteral("oldId"), entry->idFact->rawValue()},
                             {QStringLiteral("newId"), expectedNewId},
                             {QStringLiteral("utc"), QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)}};
    if (!_backupWriter || !_backupWriter(backup)) {
        _setResult(tr("原编号备份失败，未写入飞控；请检查本地存储权限"));
        return false;
    }
    if (!_freshAndLocked(*entry)) {
        _setResult(tr("备份期间心跳已过期，未写入参数；请重新确认"));
        return false;
    }
    entry->role = Role::Writing;
    entry->desiredId = expectedNewId;
    entry->acknowledgement = false;
    entry->newHeartbeat = false;
    entry->writeAt = _now();
    entry->status = tr("正在将 %1 从 %2 号改为 %3 号，等待回执和新编号心跳")
                        .arg(entry->details.name)
                        .arg(entry->systemId)
                        .arg(expectedNewId);
    _setResult(entry->status);
    entry->idFact->setRawValue(expectedNewId);
    _publish();
    return entry->role == Role::Writing;
}

void VehicleIdConflictManager::_writeId(const QString& token, const QVariant& value)
{
    const auto entry = _byToken(token);
    if (!entry || entry->role != Role::Writing || value.toInt() != entry->desiredId || !_freshAndLocked(*entry) ||
        !_singleControllerLink(*entry) || !entry->details.directUsb)
        return;
    mavlink_message_t message{};
    char name[MAVLINK_MSG_PARAM_SET_FIELD_PARAM_ID_LEN]{};
    const QByteArray bytes = entry->idFact->name().toLatin1().left(sizeof(name));
    std::copy(bytes.cbegin(), bytes.cend(), name);
    mavlink_msg_param_set_pack_chan(
        _gcsId, MAV_COMP_ID_MISSIONPLANNER, entry->details.channel, &message, entry->systemId, MAV_COMP_ID_AUTOPILOT1,
        name, _encodeId(value.toInt(), entry->paramType, entry->details.numericCast), entry->paramType);
    if (!_send(*entry, message)) {
        entry->role = Role::Uncertain;
        entry->status = tr("发送未确认，端口继续隔离；请重新连接核对编号，不会自动重复写入");
        _setResult(entry->status);
    }
}

void VehicleIdConflictManager::_complete(Entry& entry)
{
    const int oldId = entry.systemId;
    _retiredIds[entry.link].insert(oldId);
    entry.systemId = entry.desiredId;
    entry.desiredId = 0;
    const bool occupied = entry.systemId == _gcsId || static_cast<bool>(_owner(entry.systemId, &entry));
    entry.role = occupied ? Role::Conflict : Role::Primary;
    entry.status.clear();
    _pendingRestart.remove(entry.identity);
    _setResult(occupied ? tr("编号写入已确认，但 %1 号已被其他设备占用；此端口继续隔离，请重新分配").arg(entry.systemId)
                        : tr("自动编号完成：%1 已由 %2 号改为 %3 号，参数回执和新心跳均已确认")
                              .arg(entry.details.name)
                              .arg(oldId)
                              .arg(entry.systemId));
}

void VehicleIdConflictManager::_poll()
{
    bool issue = false;
    for (const auto& entry : _entries) {
        if (!entry->link)
            continue;
        if (entry->role == Role::Pending || entry->role == Role::Conflict)
            _probe(*entry);
        if (entry->role == Role::Writing && _now() - entry->writeAt >= 7000) {
            entry->role = entry->acknowledgement ? Role::AwaitRestart : Role::Uncertain;
            entry->status = entry->acknowledgement ? tr("编号参数已确认，等待新心跳；请重启这台飞控并自动重连")
                                                   : tr("未同时确认回执和新心跳；请重新连接核对，不会自动重复写入");
            _pendingRestart.insert(entry->identity, entry->desiredId);
            _setResult(entry->status);
        }
        issue |= _isIssue(entry->role);
    }
    if (issue)
        _publish();  // Updates freshness only when the visible state changes.
}

bool VehicleIdConflictManager::restartAssignedController(const QString& token)
{
    const auto entry = _byToken(token);
    if (!entry || entry->role != Role::AwaitRestart || !entry->acknowledgement || !_freshAndLocked(*entry) ||
        !entry->details.directUsb || !_singleControllerLink(*entry))
        return false;
    mavlink_message_t message{};
    mavlink_msg_command_long_pack_chan(_gcsId, MAV_COMP_ID_MISSIONPLANNER, entry->details.channel, &message,
                                       entry->lastHeartbeatId, MAV_COMP_ID_AUTOPILOT1,
                                       MAV_CMD_PREFLIGHT_REBOOT_SHUTDOWN, 0, 1, 0, 0, 0, 0, 0, 0);
    if (!_send(*entry, message))
        return false;
    entry->status = tr("已向指定 USB 飞控请求重启，等待自动重连和身份校验");
    _setResult(entry->status);
    _publish();
    return true;
}

void VehicleIdConflictManager::retryProbe(const QString& token)
{
    const auto entry = _byToken(token);
    if (!entry || (entry->role != Role::Pending && entry->role != Role::Conflict))
        return;
    entry->probes = 0;
    entry->probeAt = -1;
    _probe(*entry);
}

void VehicleIdConflictManager::removeLink(QObject* link)
{
    for (auto it = _entries.begin(); it != _entries.end();) {
        const auto& entry = *it;
        if (entry->link && entry->link != link) {
            ++it;
            continue;
        }
        if (entry->desiredId > 0 && !entry->identity.isEmpty()) {
            _pendingRestart.insert(entry->identity, entry->desiredId);
            _setResult(tr("改号设备已断开，重连后将核对真实编号；不会自动重写参数"));
        }
        if (entry->idFact)
            entry->idFact->deleteLater();
        it = _entries.erase(it);
    }
    _retiredIds.remove(link);
    _trackedLinks.remove(link);
    _resolve();
    _publish();
}
