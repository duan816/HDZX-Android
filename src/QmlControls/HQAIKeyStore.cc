#include "HQAIKeyStore.h"
#ifdef Q_OS_WIN
#include <windows.h>
#include <wincred.h>
#elif defined(Q_OS_ANDROID)
#include <QtCore/QJniObject>
#include <QtCore/QCoreApplication>
#endif

namespace HQAIKeyStore {
bool supported()
{
#if defined(Q_OS_WIN) || defined(Q_OS_ANDROID)
    return true;
#else
    return false;
#endif
}
QString read(const QString &service)
{
#ifdef Q_OS_WIN
    const auto target = service.toStdWString();
    PCREDENTIALW credential = nullptr;
    if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &credential)) return {};
    const QString value = QString::fromUtf8(reinterpret_cast<const char *>(credential->CredentialBlob), credential->CredentialBlobSize);
    CredFree(credential);
    return value;
#elif defined(Q_OS_ANDROID)
    return QJniObject::callStaticObjectMethod("org/hquavcenter/hqgroundcontrol/AIKeyStore", "read",
        "(Landroid/content/Context;Ljava/lang/String;)Ljava/lang/String;",
        QNativeInterface::QAndroidApplication::context().object(), QJniObject::fromString(service).object()).toString();
#else
    Q_UNUSED(service)
    return {};
#endif
}
bool write(const QString &service, const QString &key)
{
    if (key.isEmpty()) return remove(service);
    if (key.size() > 1024 || key.contains('\n') || key.contains('\r')) return false;
#ifdef Q_OS_WIN
    auto target = service.toStdWString();
    auto bytes = key.toUtf8();
    CREDENTIALW credential{};
    credential.Type = CRED_TYPE_GENERIC;
    credential.TargetName = target.data();
    credential.CredentialBlobSize = static_cast<DWORD>(bytes.size());
    credential.CredentialBlob = reinterpret_cast<LPBYTE>(bytes.data());
    credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
    const bool ok = CredWriteW(&credential, 0);
    SecureZeroMemory(bytes.data(), bytes.size());
    return ok;
#elif defined(Q_OS_ANDROID)
    return QJniObject::callStaticMethod<jboolean>("org/hquavcenter/hqgroundcontrol/AIKeyStore", "write",
        "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)Z",
        QNativeInterface::QAndroidApplication::context().object(), QJniObject::fromString(service).object(), QJniObject::fromString(key).object());
#else
    Q_UNUSED(service)
    return false;
#endif
}
bool remove(const QString &service)
{
#ifdef Q_OS_WIN
    const auto target = service.toStdWString();
    return CredDeleteW(target.c_str(), CRED_TYPE_GENERIC, 0) || GetLastError() == ERROR_NOT_FOUND;
#elif defined(Q_OS_ANDROID)
    return QJniObject::callStaticMethod<jboolean>("org/hquavcenter/hqgroundcontrol/AIKeyStore", "remove",
        "(Landroid/content/Context;Ljava/lang/String;)Z",
        QNativeInterface::QAndroidApplication::context().object(), QJniObject::fromString(service).object());
#else
    Q_UNUSED(service)
    return false;
#endif
}
}
