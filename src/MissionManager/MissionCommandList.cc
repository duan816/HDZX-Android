#include "MissionCommandList.h"
#include "JsonParsing.h"
#include "MissionCommandUIInfo.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QFile>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>

QGC_LOGGING_CATEGORY(MissionCommandListLog, "MissionManager.MissionCommandList")

MissionCommandList::MissionCommandList(const QString& jsonFilename, bool baseCommandList, QObject* parent)
    : QObject(parent)
{
    _loadMavCmdInfoJson(jsonFilename, baseCommandList);
}

void MissionCommandList::_loadMavCmdInfoJson(const QString& jsonFilename, bool baseCommandList)
{
    if (jsonFilename.isEmpty()) {
        return;
    }

    qCDebug(MissionCommandListLog) << "Loading" << jsonFilename;

    QString errorString;
    int version;
    QJsonObject jsonObject = JsonParsing::openInternalQGCJsonFile(
        jsonFilename, qgcFileType, 1, 1, version, errorString,
        QStringList{"label", "enumStrings", "friendlyName", "description", "category"},
        QStringList{"rawName", "comment"});
    if (!errorString.isEmpty()) {
        qCWarning(MissionCommandListLog) << "Internal Error: " << errorString;
        return;
    }

    QJsonValue jsonValue = jsonObject.value(_mavCmdInfoJsonKey);
    if (!jsonValue.isArray()) {
        qCWarning(MissionCommandListLog) << jsonFilename << "mavCmdInfo not array";
        return;
    }

    // JSON translation replaces the friendly name. Preserve the original by numeric ID, not list order.
    QMap<int, QString> englishNames;
    if (baseCommandList) {
        QFile source(jsonFilename);
        if (source.open(QIODevice::ReadOnly)) {
            const auto entries = QJsonDocument::fromJson(source.readAll()).object().value(_mavCmdInfoJsonKey).toArray();
            for (const auto& entry : entries) {
                const auto command = entry.toObject();
                englishNames.insert(command.value("id").toInt(),
                                    command.value("friendlyName").toString(command.value("rawName").toString()));
            }
        }
    }

    // Iterate over MissionCommandUIInfo objects
    QJsonArray jsonArray = jsonValue.toArray();
    for(QJsonValue info: jsonArray) {
        if (!info.isObject()) {
            qCWarning(MissionCommandListLog) << jsonFilename << "mavCmdArray should contain objects";
            return;
        }

        MissionCommandUIInfo* uiInfo = new MissionCommandUIInfo(this);

        QString uiInfoErrorString;
        if (!uiInfo->loadJsonInfo(info.toObject(), baseCommandList, uiInfoErrorString)) {
            uiInfo->deleteLater();
            qCWarning(MissionCommandListLog) << jsonFilename << uiInfoErrorString;
            return;
        }
        uiInfo->_englishFriendlyName = englishNames.value(uiInfo->intCommand());

        // Update list of known categories
        QString newCategory = uiInfo->category();
        if (!newCategory.isEmpty() && !_categories.contains(newCategory)) {
            _categories.append(newCategory);
        }

        _infoMap[uiInfo->command()] = uiInfo;
    }

    // Build id list
    for (MAV_CMD id: _infoMap.keys()) {
        _ids << id;
    }
}

MissionCommandUIInfo* MissionCommandList::getUIInfo(MAV_CMD command) const
{
    if (!_infoMap.contains(command)) {
        return nullptr;
    }

    return _infoMap[command];
}
