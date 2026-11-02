#include "StatusTextHandler.h"
#include "MAVLinkLib.h"
#include "VehicleMessageCatalog.h"
#include <QGCLoggingCategory.h>

#include <QtCore/QTimer>
#include <QtCore/QDateTime>

QGC_LOGGING_CATEGORY(StatusTextHandlerLog, "MAVLink.StatusTextHandler")

namespace {
QString preArmCauseChinese(const QString &htmlEscapedText)
{
    if (!htmlEscapedText.startsWith(QStringLiteral("PreArm:"), Qt::CaseInsensitive)) {
        return {};
    }

    const QString message = htmlEscapedText.sliced(htmlEscapedText.indexOf(u':') + 1).trimmed();
    const QString lower = message.toLower();
    struct CauseEntry { const char *needle; const char *cause; };
    static constexpr CauseEntry causes[] = {
        {"3d accel calibration needed", "未完成加速度计六面校准。"},
        {"accels calibrated requires reboot", "加速度计校准已完成，但飞控尚未重启。"},
        {"accels inconsistent", "多个加速度计的测量结果不一致。"},
        {"adsb out of memory", "飞控可用内存不足，无法运行 ADS-B 功能。"},
        {"accels not healthy", "至少一个加速度计没有提供有效数据。"},
        {"ahrs: waiting for home", "GPS 尚未获得有效定位，AHRS 正在等待确定 Home 点。"},
        {"battery below minimum arming capacity", "电池剩余容量低于 BATT_ARM_MAH 设置的解锁阈值。"},
        {"battery below minimum arming voltage", "电池电压低于 BATT_ARM_VOLT 设置的解锁阈值。"},
        {"battery unhealthy", "电池监测器没有提供有效数据。"},
        {"check fs_thr_value", "遥控器故障保护油门值与 RC3_MIN 过于接近。"},
        {"can’t check rally without position", "EKF 尚未获得有效位置估计，无法检查集结点。"},
        {"can't check rally without position", "EKF 尚未获得有效位置估计，无法检查集结点。"},
        {"check fence", "地理围栏初始化或检查失败。"},
        {"check mag field (xy", "罗盘水平磁场强度过大或过小。"},
        {"check mag field (z", "罗盘垂直磁场强度过大或过小。"},
        {"check mag field:", "罗盘磁场强度超出允许范围。"},
        {"compass calibrated requires reboot", "罗盘校准已经完成，但飞控尚未重启。"},
        {"compass calibration running", "罗盘校准仍在进行中。"},
        {"compass not healthy", "至少一个罗盘没有提供有效数据。"},
        {"compass offsets too high", "罗盘偏移量超过允许范围。"},
        {"compasses inconsistent", "多个罗盘的安装方向或磁场测量不一致。"},
        {"ekf attitude is bad", "EKF 没有获得可靠的姿态估计。"},
        {"ekf3 roll/pitch inconsistent", "EKF3 的横滚或俯仰估计不一致。"},
        {"ekf3 waiting for gps config data", "GPS 自动配置尚未完成。"},
        {"ekf3 yaw inconsistent", "EKF3 的航向角估计不一致。"},
        {"ground mag anomaly", "磁力计可能受到严重的地面磁场干扰。"},
        {"gps and ahrs differ", "GPS 位置与 AHRS/EKF 位置估计差异过大。"},
        {"gps blending unhealthy", "至少一个参与融合的 GPS 没有提供可靠数据。"},
        {"gps positions differ", "多个 GPS 报告的位置差异过大。"},
        {"still configuring this gps", "该 GPS 的自动配置尚未完成。"},
        {": bad fix", "GPS 定位质量不足。"},
        {": not healthy", "GPS 没有提供有效数据。"},
        {": primary but type 0", "该 GPS 被选为主 GPS，但接收机类型尚未配置。"},
        {": was not found", "没有检测到该 GPS，可能已断开或配置不正确。"},
        {"yaw not available", "已配置 GPS 航向，但当前没有有效的航向数据。"},
        {"gps glitching", "GPS 定位数据不稳定。"},
        {"gyros inconsistent", "多个陀螺仪的测量结果不一致。"},
        {"gyros not calibrated", "启动时陀螺仪校准未完成。"},
        {"gyros not healthy", "至少一个陀螺仪没有提供有效数据。"},
        {"hardware safety switch", "硬件安全开关尚未解除。"},
        {"internal errors", "飞控检测到内部错误。"},
        {"main loop slow", "飞控主循环运行过慢，可能存在 CPU 负载过高。"},
        {"param storage failed", "参数存储失败，可能存在存储器硬件故障。"},
        {"parameter storage full", "参数存储空间已满。"},
        {"pitch radio max too low", "遥控器俯仰通道最大值低于允许范围。"},
        {"pitch radio min too high", "遥控器俯仰通道最小值高于允许范围。"},
    };

    if (lower.startsWith(QStringLiteral("board ")) && lower.contains(QStringLiteral("out of range"))) {
        return QStringLiteral("飞控板供电电压超出允许范围。");
    }
    for (const CauseEntry &entry : causes) {
        if (lower.contains(QLatin1StringView(entry.needle))) {
            return QString::fromUtf8(entry.cause);
        }
    }
    return {};
}
}

StatusText::StatusText(MAV_COMPONENT componentid, MAV_SEVERITY severity, const QString &text)
    : m_compId(componentid)
    , m_severity(severity)
    , m_text(text)
{
    // qCDebug(StatusTextHandlerLog) << Q_FUNC_INFO << this;
}

bool StatusText::severityIsError() const
{
    switch (m_severity) {
        case MAV_SEVERITY_EMERGENCY:
        case MAV_SEVERITY_ALERT:
        case MAV_SEVERITY_CRITICAL:
        case MAV_SEVERITY_ERROR:
            return true;

        default:
            return false;
    }
}

StatusTextHandler::StatusTextHandler(QObject *parent)
    : QObject(parent)
    , m_chunkedStatusTextTimer(new QTimer(this))
{
    // qCDebug(StatusTextHandlerLog) << Q_FUNC_INFO << this;

    m_chunkedStatusTextTimer->setSingleShot(true);
    m_chunkedStatusTextTimer->setInterval(1000);
    (void) connect(m_chunkedStatusTextTimer, &QTimer::timeout, this, &StatusTextHandler::_chunkedStatusTextTimeout);
}

StatusTextHandler::~StatusTextHandler()
{
    clearMessages();

    // qCDebug(StatusTextHandlerLog) << Q_FUNC_INFO << this;
}

QString StatusTextHandler::getMessageText(const mavlink_message_t &message)
{
    // Warning: There is a bug in mavlink which causes mavlink_msg_statustext_get_text to work incorrect.
    // It ends up copying crap off the end of the buffer, so don't use it for now.

    mavlink_statustext_t statusText;
    mavlink_msg_statustext_decode(&message, &statusText);

    char buffer[MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN + 1];
    memcpy(buffer, statusText.text, MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN);
    buffer[MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN] = '\0';

    return QString(buffer);
}

QString StatusTextHandler::formattedMessages() const
{
    QString result;
    for (const StatusText *message: messages()) {
        (void) result.prepend(message->getFormattedText());
    }

    return result;
}

void StatusTextHandler::clearMessages()
{
    qDeleteAll(m_messages);
    m_messages.clear();

    m_errorCount = 0;
    m_warningCount = 0;
    m_normalCount = 0;

    _handleTextMessage(0);
}

void StatusTextHandler::resetAllMessages()
{
    const uint32_t count = messageCount();
    const MessageType type = m_messageType;

    m_errorCount = 0;
    m_warningCount = 0;
    m_normalCount = 0;
    m_messageCount = 0;
    m_messageType = MessageType::MessageNone;

    if (count != messageCount()) {
        emit messageCountChanged(0);
    }

    if (type != m_messageType) {
        emit messageTypeChanged();
    }
}

void StatusTextHandler::resetErrorLevelMessages()
{
    const uint32_t prevMessageCount = messageCount();
    const MessageType prevMessagetype = m_messageType;

    m_messageCount -= getErrorCount();
    m_errorCount = 0;

    if (getWarningCount() > 0) {
        m_messageType = MessageType::MessageWarning;
    } else if (getNormalCount() > 0) {
        m_messageType = MessageType::MessageNormal;
    } else {
        m_messageType = MessageType::MessageNone;
    }

    if (prevMessageCount != messageCount()) {
        emit messageCountChanged(messageCount());
    }

    if (prevMessagetype != m_messageType) {
        emit messageTypeChanged();
    }
}

void StatusTextHandler::handleHTMLEscapedTextMessage(MAV_COMPONENT compId, MAV_SEVERITY severity, const QString &text, const QString &description)
{
    QString htmlText(text);
    const VehicleMessageGuidance guidance = VehicleMessageCatalog::lookup(text, VehicleMessageStack::Any);
    QString effectiveDescription;
    bool guidanceIsHtml = false;
    if (!guidance.isEmpty()) {
        guidanceIsHtml = true;
        effectiveDescription = QStringLiteral("<span style=\"<#N>\">中文：%1")
                                   .arg(guidance.translation.toHtmlEscaped());
        if (!guidance.explanation.isEmpty()) {
            effectiveDescription += QStringLiteral("<br/>解释：%1").arg(guidance.explanation.toHtmlEscaped());
        }
        if (!guidance.solution.isEmpty()) {
            effectiveDescription += QStringLiteral("<br/>解决方法：%1").arg(guidance.solution.toHtmlEscaped());
        }
        effectiveDescription += QStringLiteral("</span>");
        if (!description.isEmpty()) {
            effectiveDescription += QStringLiteral("<br/>固件说明：%1").arg(description);
        }
    } else {
        effectiveDescription = description.isEmpty() ? preArmCauseChinese(text) : description;
        if (effectiveDescription.isEmpty() && severity <= MAV_SEVERITY_WARNING) {
            effectiveDescription = QStringLiteral("暂未收录这条报错的专用中文说明。请保留原文及固件版本，结合报错前后的消息和日志核对；当前不推断故障原因。");
        }
    }

    (void) htmlText.replace("\n", "<br/>");

    // TODO: handle text + description separately in the UI
    if (!effectiveDescription.isEmpty()) {
        QString htmlDescription(effectiveDescription);
        if (!guidanceIsHtml) {
            (void) htmlDescription.replace("\n", "<br/>");
        }
        (void) htmlText.append(QStringLiteral("<br/><small>"));
        (void) htmlText.append(htmlDescription);
        (void) htmlText.append(QStringLiteral("</small>"));
    }

    if (m_activeComponent == MAV_COMPONENT::MAV_COMPONENT_ENUM_END) {
        m_activeComponent = compId;
    }

    if (compId != m_activeComponent) {
        m_multiComp = true;
    }

    MessageType messageType = MessageType::MessageNone;

    // Color the output depending on the message severity. We have 3 distinct cases:
    // 1: If we have an ERROR or worse, make it bigger, bolder, and highlight it red.
    // 2: If we have a warning or notice, just make it bold and color it orange.
    // 3: Otherwise color it the standard color, white.
    QString style;
    switch (severity) {
        case MAV_SEVERITY_EMERGENCY:
        case MAV_SEVERITY_ALERT:
        case MAV_SEVERITY_CRITICAL:
        case MAV_SEVERITY_ERROR:
            style = QStringLiteral("<#E>");
            messageType = MessageType::MessageError;
            break;

        case MAV_SEVERITY_NOTICE:
        case MAV_SEVERITY_WARNING:
            style = QStringLiteral("<#I>");
            messageType = MessageType::MessageWarning;
            break;

        default:
            style = QStringLiteral("<#N>");
            messageType = MessageType::MessageNormal;
            break;
    }

    QString severityText;
    switch (severity) {
        case MAV_SEVERITY_EMERGENCY:
            severityText = tr("EMERGENCY");
            break;

        case MAV_SEVERITY_ALERT:
            severityText = tr("ALERT");
            break;

        case MAV_SEVERITY_CRITICAL:
            severityText = tr("Critical");
            break;

        case MAV_SEVERITY_ERROR:
            severityText = tr("Error");
            break;

        case MAV_SEVERITY_WARNING:
            severityText = tr("Warning");
            break;

        case MAV_SEVERITY_NOTICE:
            severityText = tr("Notice");
            break;

        case MAV_SEVERITY_INFO:
            severityText = tr("Info");
            break;

        case MAV_SEVERITY_DEBUG:
            severityText = tr("Debug");
            break;

        default:
            qCWarning(StatusTextHandlerLog) << Q_FUNC_INFO << "Invalid MAV_SEVERITY";
            break;
    }

    QString compString;
    if (m_multiComp) {
        compString = QString("COMP:%1").arg(compId);
    }

    const QString dateString = QDateTime::currentDateTime().toString("hh:mm:ss.zzz");

    const QString formatText = QString("<font style=\"%1\">[%2 %3] %4: %5</font><br/>").arg(style, dateString, compString, severityText, htmlText);

    StatusText* const message = new StatusText(compId, severity, text);
    message->setFormatedText(formatText);

    emit newFormattedMessage(formatText);

    (void) m_messages.append(message);
    const uint32_t count = m_messages.count();

    _handleTextMessage(count, messageType);

    if (message->severityIsError()) {
        emit newErrorMessage(message->getText());
    }
}

void StatusTextHandler::mavlinkMessageReceived(const mavlink_message_t &message)
{
    if (message.msgid != MAVLINK_MSG_ID_STATUSTEXT) {
        return;
    }

    _handleStatusText(message);
}

void StatusTextHandler::_handleStatusText(const mavlink_message_t &message)
{
    mavlink_statustext_t statustext;
    mavlink_msg_statustext_decode(&message, &statustext);

    const QString messageText = getMessageText(message);
    const bool includesNullTerminator = messageText.length() < MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN;

    const MAV_COMPONENT compId = static_cast<MAV_COMPONENT>(message.compid);
    if (m_chunkedStatusTextInfoMap.contains(compId) && (m_chunkedStatusTextInfoMap.value(compId).chunkId != statustext.id)) {
        // We have an incomplete chunked status still pending
        (void) m_chunkedStatusTextInfoMap.value(compId).rgMessageChunks.append(QString());
        _chunkedStatusTextCompleted(compId);
    }

    if (statustext.id == 0) {
        // Non-chunked status text. We still use common chunked text output mechanism.
        ChunkedStatusTextInfo_t chunkedInfo;
        chunkedInfo.chunkId = 0;
        chunkedInfo.severity = static_cast<MAV_SEVERITY>(statustext.severity);
        (void) chunkedInfo.rgMessageChunks.append(messageText);
        (void) m_chunkedStatusTextInfoMap.insert(compId, chunkedInfo);
    } else {
        if (m_chunkedStatusTextInfoMap.contains(compId)) {
            // A chunk sequence is in progress
            QStringList& chunks = m_chunkedStatusTextInfoMap[compId].rgMessageChunks;
            if (statustext.chunk_seq > chunks.size()) {
                // We are missing some chunks in between, fill them in as missing
                for (size_t i = chunks.size(); i < statustext.chunk_seq; i++) {
                    (void) chunks.append(QString());
                }
            }

            (void) chunks.append(messageText);
        } else {
            // Starting a new chunk sequence
            ChunkedStatusTextInfo_t chunkedInfo;
            chunkedInfo.chunkId = statustext.id;
            chunkedInfo.severity = static_cast<MAV_SEVERITY>(statustext.severity);
            (void) chunkedInfo.rgMessageChunks.append(messageText);
            (void) m_chunkedStatusTextInfoMap.insert(compId, chunkedInfo);
        }

        m_chunkedStatusTextTimer->start();
    }

    if ((statustext.id == 0) || includesNullTerminator) {
        m_chunkedStatusTextTimer->stop();
        _chunkedStatusTextCompleted(compId);
    }
}

void StatusTextHandler::_chunkedStatusTextTimeout()
{
    for (auto compId : m_chunkedStatusTextInfoMap.keys()) {
        auto& chunkedInfo = m_chunkedStatusTextInfoMap[compId];
        (void) chunkedInfo.rgMessageChunks.append(QString());
        _chunkedStatusTextCompleted(compId);
    }
}

void StatusTextHandler::_chunkedStatusTextCompleted(MAV_COMPONENT compId)
{
    const ChunkedStatusTextInfo_t& chunkedInfo = m_chunkedStatusTextInfoMap.value(compId);
    const MAV_SEVERITY severity = chunkedInfo.severity;

    QString messageText;
    for (const QString& chunk : std::as_const(chunkedInfo.rgMessageChunks)) {
        if (chunk.isEmpty()) {
            (void) messageText.append(tr(" ... ", "Indicates missing chunk from chunked STATUS_TEXT"));
        } else {
            (void) messageText.append(chunk);
        }
    }

    (void) m_chunkedStatusTextInfoMap.remove(compId);

    emit textMessageReceived(compId, severity, messageText, "");
}

void StatusTextHandler::_handleTextMessage(uint32_t newCount, MessageType messageType)
{
    if (newCount == 0) {
        resetAllMessages();
        return;
    }

    switch (messageType) {
        case MessageType::MessageNormal:
            m_normalCount++;
            break;

        case MessageType::MessageWarning:
            m_warningCount++;
            break;

        case MessageType::MessageError:
            m_errorCount++;
            m_errorCountTotal++;
            break;

        case MessageType::MessageNone:
        default:
            qCWarning(StatusTextHandlerLog) << Q_FUNC_INFO << "Invalid MessageType";
            break;
    }

    const uint32_t count = getErrorCount() + getWarningCount() + getNormalCount();
    if (count != messageCount()) {
        m_messageCount = count;
        emit messageCountChanged(messageCount());
    }

    // messageType represents the worst message which hasn't been viewed yet
    MessageType newMessageType = MessageType::MessageNone;
    if (getErrorCount() > 0) {
        newMessageType = MessageType::MessageError;
    } else if (getWarningCount() > 0) {
        newMessageType = MessageType::MessageWarning;
    } else if (getNormalCount() > 0) {
        newMessageType = MessageType::MessageNormal;
    }

    if (newMessageType != m_messageType) {
        m_messageType = newMessageType;
        emit messageTypeChanged();
    }
}
