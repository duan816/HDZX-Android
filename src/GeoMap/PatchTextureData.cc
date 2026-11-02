/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "PatchTextureData.h"

PatchTextureData::PatchTextureData(QQuick3DObject* parent) : QQuick3DTextureData(parent) {}

void PatchTextureData::setImage(const QImage& image)
{
    if (image == _image) {
        return;
    }
    _image = image;
    emit imageChanged();
    _rebuild();
}

void PatchTextureData::_rebuild()
{
    if (_image.isNull()) {
        setSize(QSize());
        setTextureData(QByteArray());
        return;
    }

    const QImage converted = _image.convertToFormat(QImage::Format_RGBA8888);
    setSize(converted.size());
    setFormat(QQuick3DTextureData::RGBA8);
    // An RGBA container may still be completely opaque (notably composed LOD
    // fallback tiles). Marking it transparent disables normal terrain depth
    // writes and lets neighboring skirts paint over nearer ground.
    bool translucent = false;
    if (_image.hasAlphaChannel()) {
        for (int row = 0; row < converted.height() && !translucent; ++row) {
            const uchar* pixels = converted.constScanLine(row);
            for (int col = 0; col < converted.width(); ++col) {
                if (pixels[col * 4 + 3] != 255) {
                    translucent = true;
                    break;
                }
            }
        }
    }
    setHasTransparency(translucent);
    // Deep copy: the converted image's buffer dies with this scope
    setTextureData(QByteArray(reinterpret_cast<const char*>(converted.constBits()), converted.sizeInBytes()));
}
