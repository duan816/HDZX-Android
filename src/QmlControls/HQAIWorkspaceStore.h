#pragma once
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QRegularExpression>
#include <QtCore/QStandardPaths>
#include <QtCore/QSet>

// Two verified slots retain the previous valid revision if a save is interrupted.
// No cross-volume temporary-file rename; AppData may be redirected on Windows.
namespace HQAIWorkspaceStore {
inline QString &lastError() { static thread_local QString value; return value; }
inline QString directory() { return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)+"/ai-analysis-records"; }
inline bool validId(const QString &id) {
    static const QRegularExpression expression("^[a-f0-9-]{36}$");
    return expression.match(id).hasMatch();
}
inline QVariantMap readSlot(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly) || file.size()>500000) return {};
    const auto document=QJsonDocument::fromJson(file.readAll());
    return document.isObject()?document.object().toVariantMap():QVariantMap();
}
inline QVariantMap read(const QString &id) {
    if (!validId(id)) return {};
    const QString base=directory()+"/"+id;
    const auto a=readSlot(base+".a.json"), b=readSlot(base+".b.json");
    if (a.isEmpty() && b.isEmpty()) return readSlot(base+".json");
    return a.value("_revision").toULongLong()>=b.value("_revision").toULongLong()?a:b;
}
inline bool write(const QString &id, const QVariantMap &record) {
    lastError().clear();
    if (!validId(id) || !QDir().mkpath(directory())) { lastError()="Invalid record or directory"; return false; }
    const QString base=directory()+"/"+id;
    const auto a=readSlot(base+".a.json"), b=readSlot(base+".b.json");
    const quint64 ar=a.value("_revision").toULongLong(),br=b.value("_revision").toULongLong();
    const QString path=base+(ar<=br?".a.json":".b.json");
    auto saved=record; saved["_revision"]=std::max(ar,br)+1;
    const auto bytes=QJsonDocument::fromVariant(saved).toJson(QJsonDocument::Compact);
    if (bytes.size()>500000) { lastError()="Record exceeds local limit"; return false; }
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly) || file.write(bytes)!=bytes.size() || !file.flush()) { lastError()=file.errorString(); return false; }
    file.close();
    if (!file.open(QIODevice::ReadOnly) || file.readAll()!=bytes) { lastError()="Record verification failed; previous slot retained"; return false; }
    return true;
}
inline QVariantList records() {
    QVariantList result; QSet<QString> seen;
    const auto files=QDir(directory()).entryList({"*.json"},QDir::Files,QDir::Time);
    for(const auto &file:files) {
        const QString id=file.left(36);
        if (!validId(id)||seen.contains(id)) continue;
        seen.insert(id); const auto record=read(id);
        if (record.isEmpty()) continue;
        result.append(QVariantMap{{"id",id},{"name",record.value("log_name")},{"time",record.value("saved_at")},
            {"workspace",record.value("workspace")},{"diagnosis",record.value("diagnosis")}});
        if (result.size()>=200) break;
    }
    return result;
}
inline bool remove(const QString &id) {
    if(!validId(id)) return false;
    bool found=false,ok=true;
    for(const QString suffix:{".a.json",".b.json",".json"}) {
        const QString path=directory()+"/"+id+suffix;
        if(QFile::exists(path)){ found=true; if(!QFile::remove(path)) ok=false; }
    }
    return found&&ok;
}
}
