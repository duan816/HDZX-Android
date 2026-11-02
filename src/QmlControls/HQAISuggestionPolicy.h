#pragma once

#include <algorithm>
#include <cmath>

#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QSet>
#include <QtCore/QStringList>

namespace HQAISuggestionPolicy {

inline QString hardwareError(const QVariantMap &hardware)
{
    const double frame = hardware.value(QStringLiteral("frame_mm")).toDouble();
    const double prop = hardware.value(QStringLiteral("prop_inches")).toDouble();
    if (!std::isfinite(frame) || frame <= 0 || frame > 20000 || !std::isfinite(prop) || prop <= 0 || prop > 100) {
        return QStringLiteral("请填写真实轴距和桨尺寸，不能用小型机默认值替代。");
    }
    const QString protocol = hardware.value(QStringLiteral("esc_protocol")).toString();
    if (protocol.isEmpty() || protocol == QStringLiteral("unknown")) return QStringLiteral("请确认电调控制协议。");
    if (hardware.value(QStringLiteral("rpm_source")).toString() == QStringLiteral("bidirectional_dshot")
        && (protocol != QStringLiteral("DShot") || !hardware.value(QStringLiteral("rpm_verified")).toBool())) {
        return QStringLiteral("双向 DShot RPM 来源需要 DShot 电调及已核实的真实回传；PWM 或单向 DShot 配置不满足条件。");
    }
    return {};
}

inline QString parse(const QByteArray &response, const QStringList &allowedNames, QJsonObject &result)
{
    QJsonParseError error;
    const auto envelope = QJsonDocument::fromJson(response, &error);
    if (error.error != QJsonParseError::NoError || !envelope.isObject()) return QStringLiteral("API 返回不是有效 JSON");
    const auto choices = envelope.object().value(QStringLiteral("choices")).toArray();
    if (choices.isEmpty()) return QStringLiteral("API 没有返回分析内容");
    const auto choice = choices.first().toObject();
    if (choice.value(QStringLiteral("finish_reason")).toString() != QStringLiteral("stop")) {
        return QStringLiteral("AI 回复未完整结束，请缩短问题后重新分析");
    }
    QString content = choice.value(QStringLiteral("message")).toObject().value(QStringLiteral("content")).toString().trimmed();
    if (content.startsWith(QStringLiteral("```json\n")) && content.endsWith(QStringLiteral("```")))
        content = content.mid(8, content.size()-11).trimmed();
    else if (content.startsWith(QStringLiteral("```\n")) && content.endsWith(QStringLiteral("```")))
        content = content.mid(4, content.size()-7).trimmed();
    if (content.size() > 100000) return QStringLiteral("AI 回复过长，已拒绝解析");
    const auto document = QJsonDocument::fromJson(content.toUtf8(), &error);
    if (error.error != QJsonParseError::NoError || !document.isObject()) return QStringLiteral("AI 回复不符合结构化格式");
    const auto object = document.object();
    if (!object.value(QStringLiteral("summary")).isString() || !object.value(QStringLiteral("changes")).isArray()
        || !object.value(QStringLiteral("questions")).isArray()) {
        // A useful narrative may still be shown, but malformed schemas must
        // never become writable parameter plans.
        result = QJsonObject{{"summary", object.value("summary").isString() ? object.value("summary").toString() : QString::fromUtf8(document.toJson(QJsonDocument::Indented))},
            {"diagnosis", "模型回复格式待复核"}, {"verdict", "insufficient_evidence"},
            {"questions", QJsonArray{"本次仅展示文字分析，未生成可写建议；可重新分析获取结构化结果。"}},
            {"changes", QJsonArray{}}, {"display_only_format", true}};
        return {};
    }
    const auto changes = object.value(QStringLiteral("changes")).toArray();
    if (object.contains("verdict") && !QStringList{"needs_changes", "insufficient_evidence", "no_change_supported"}.contains(object.value("verdict").toString())) return QStringLiteral("AI 结论分类无效");
    if (changes.size() > 20) return QStringLiteral("建议数量超过本次调参范围");
    QSet<QString> seen;
    for (const auto &item : changes) {
        const auto change = item.toObject();
        const auto name = change.value(QStringLiteral("name")).toString();
        const auto value = change.value(QStringLiteral("value"));
        if (!allowedNames.contains(name) || seen.contains(name)) return QStringLiteral("AI 建议包含未选择或重复的参数");
        if (!value.isDouble() || !std::isfinite(value.toDouble()) || !change.value(QStringLiteral("reason")).isString()) {
            return QStringLiteral("AI 建议的类型或理由无效");
        }
        seen.insert(name);
    }
    result = object;
    return {};
}

inline bool matches(double actual, double expected)
{
    return std::isfinite(actual) && std::isfinite(expected)
        && std::abs(actual - expected) <= std::max(1.0, std::abs(expected)) * 1e-6;
}

} // namespace HQAISuggestionPolicy
