#pragma once

#include <QtCore/QString>

namespace StoragePathPolicy {
inline bool writable(const QString& path)
{
    if (!path.startsWith('/') || path == "/" || path.contains('\\') || path.contains(':') ||
        path.contains(QChar::Null) || path.contains('\n') || path.contains('\r')) {
        return false;
    }
    for (const auto& part : path.split('/')) {
        if (part == "." || part == ".." || part.startsWith('@')) {
            return false;
        }
    }
    return true;
}
} // namespace StoragePathPolicy
