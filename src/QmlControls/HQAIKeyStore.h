#pragma once
#include <QtCore/QString>
namespace HQAIKeyStore {
bool supported();
QString read(const QString &service);
bool write(const QString &service, const QString &key);
bool remove(const QString &service);
}
