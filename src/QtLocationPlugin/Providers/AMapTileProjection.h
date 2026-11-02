#pragma once

#include <QtCore/QHash>
#include <QtCore/QPoint>
#include <QtCore/QPointF>
#include <QtCore/QVector>
#include <QtGui/QImage>

/// Resample GCJ-02 imagery into ordinary WGS-84 slippy tiles. No vehicle or mission coordinate is changed.
namespace AMapTileProjection {
QPointF wgs84ToGcj02(const QPointF& longitudeLatitude);
QPointF sourcePixel(int x, int y, int zoom, double pixelX, double pixelY);

struct Mesh
{
    int sourceZoom = 0;
    QVector<QPointF> points;
    QVector<QPoint> tiles;
    QPointF at(double pixelX, double pixelY) const;

    bool isValid() const { return points.size() == 289 && !tiles.isEmpty(); }
};

Mesh mesh(int x, int y, int zoom);
QImage render(const Mesh& mapping, const QHash<QPoint, QImage>& tiles);
}  // namespace AMapTileProjection
