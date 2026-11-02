#include "AMapTileProjection.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <numbers>

// GCJ-02 forward equations adapted from wandergis/coordtransform (MIT).
// Copyright (c) 2015 记忆的残骸. Full license: resources/licenses/coordtransform-MIT.txt.
namespace AMapTileProjection {
namespace {
constexpr double pi = std::numbers::pi;
constexpr double a = 6378245.0;
constexpr double ee = 0.00669342162296594323;

double latitudeDelta(double x, double y)
{
    return -100 + 2 * x + 3 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * std::sqrt(std::abs(x)) +
           (20 * std::sin(6 * x * pi) + 20 * std::sin(2 * x * pi)) * 2 / 3 +
           (20 * std::sin(y * pi) + 40 * std::sin(y * pi / 3)) * 2 / 3 +
           (160 * std::sin(y * pi / 12) + 320 * std::sin(y * pi / 30)) * 2 / 3;
}

double longitudeDelta(double x, double y)
{
    return 300 + x + 2 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * std::sqrt(std::abs(x)) +
           (20 * std::sin(6 * x * pi) + 20 * std::sin(2 * x * pi)) * 2 / 3 +
           (20 * std::sin(x * pi) + 40 * std::sin(x * pi / 3)) * 2 / 3 +
           (150 * std::sin(x * pi / 12) + 300 * std::sin(x * pi / 30)) * 2 / 3;
}
}  // namespace

QPointF wgs84ToGcj02(const QPointF& coordinate)
{
    const double longitude = coordinate.x(), latitude = coordinate.y();
    if (!std::isfinite(longitude) || !std::isfinite(latitude))
        return {};
    if (longitude < 72.004 || longitude > 137.8347 || latitude < 0.8293 || latitude > 55.8271)
        return coordinate;
    const double rad = latitude * pi / 180;
    const double magic = 1 - ee * std::pow(std::sin(rad), 2);
    const double root = std::sqrt(magic);
    return coordinate +
           QPointF(longitudeDelta(longitude - 105, latitude - 35) * 180 / (a / root * std::cos(rad) * pi),
                   latitudeDelta(longitude - 105, latitude - 35) * 180 / (a * (1 - ee) / (magic * root) * pi));
}

QPointF sourcePixel(int x, int y, int zoom, double pixelX, double pixelY)
{
    const double count = std::ldexp(1.0, zoom);
    const double longitude = (x + pixelX / 256) / count * 360 - 180;
    const double latitude = std::atan(std::sinh(pi * (1 - 2 * (y + pixelY / 256) / count))) * 180 / pi;
    const QPointF shifted = wgs84ToGcj02(QPointF(longitude, latitude));
    const double world = 256 * std::ldexp(1.0, std::min(zoom, 18));
    const double rad = std::clamp(shifted.y(), -85.0511287798, 85.0511287798) * pi / 180;
    return QPointF((shifted.x() + 180) / 360 * world, (1 - std::asinh(std::tan(rad)) / pi) / 2 * world);
}

QPointF Mesh::at(double pixelX, double pixelY) const
{
    if (!isValid())
        return {};
    const double gx = std::clamp(pixelX / 16, 0.0, 16.0), gy = std::clamp(pixelY / 16, 0.0, 16.0);
    const int ix = std::min(15, static_cast<int>(gx)), iy = std::min(15, static_cast<int>(gy));
    const double fx = gx - ix, fy = gy - iy;
    return points[iy * 17 + ix] * (1 - fx) * (1 - fy) + points[iy * 17 + ix + 1] * fx * (1 - fy) +
           points[(iy + 1) * 17 + ix] * (1 - fx) * fy + points[(iy + 1) * 17 + ix + 1] * fx * fy;
}

Mesh mesh(int x, int y, int zoom)
{
    Mesh result;
    if (zoom < 0 || zoom > 23 || x < 0 || y < 0 || x >= (1 << zoom) || y >= (1 << zoom))
        return result;
    result.sourceZoom = std::min(zoom, 18);
    double left = std::numeric_limits<double>::max(), top = left;
    double right = -left, bottom = -left;
    for (int row = 0; row <= 16; ++row) {
        for (int column = 0; column <= 16; ++column) {
            const QPointF point = sourcePixel(x, y, zoom, column * 16, row * 16);
            if (!std::isfinite(point.x()) || !std::isfinite(point.y()))
                return {};
            result.points.append(point);
            left = std::min(left, point.x());
            right = std::max(right, point.x());
            top = std::min(top, point.y());
            bottom = std::max(bottom, point.y());
        }
    }
    const int count = 1 << result.sourceZoom;
    const int minX = static_cast<int>(std::floor((left - 0.5) / 256)),
              maxX = static_cast<int>(std::floor((right + 0.5) / 256));
    const int minY = std::clamp(static_cast<int>(std::floor((top - 0.5) / 256)), 0, count - 1);
    const int maxY = std::clamp(static_cast<int>(std::floor((bottom + 0.5) / 256)), 0, count - 1);
    if ((maxX - minX + 1) * (maxY - minY + 1) > 25)
        return {};
    for (int row = minY; row <= maxY; ++row)
        for (int column = minX; column <= maxX; ++column)
            result.tiles.append(QPoint(column, row));
    return result;
}

QImage render(const Mesh& mapping, const QHash<QPoint, QImage>& tiles)
{
    if (!mapping.isValid())
        return {};
    for (const QPoint& key : mapping.tiles) {
        const auto it = tiles.constFind(key);
        if (it == tiles.cend() || it->size() != QSize(256, 256) || it->format() != QImage::Format_RGB32)
            return {};
    }
    const int world = 256 * (1 << mapping.sourceZoom);
    auto sample = [&tiles, world](int x, int y) {
        y = std::clamp(y, 0, world - 1);
        const int tileX = static_cast<int>(std::floor(x / 256.0)), tileY = y / 256;
        const auto it = tiles.constFind(QPoint(tileX, tileY));
        if (it == tiles.cend())
            return QRgb(0);
        const int localX = ((x % 256) + 256) % 256;
        return reinterpret_cast<const QRgb*>(it->constScanLine(y % 256))[localX];
    };
    QImage image(256, 256, QImage::Format_RGB32);
    for (int row = 0; row < 256; ++row) {
        auto* line = reinterpret_cast<QRgb*>(image.scanLine(row));
        for (int column = 0; column < 256; ++column) {
            const QPointF point = mapping.at(column + 0.5, row + 0.5) - QPointF(0.5, 0.5);
            const int x = static_cast<int>(std::floor(point.x())), y = static_cast<int>(std::floor(point.y()));
            const double fx = point.x() - x, fy = point.y() - y;
            const QRgb colors[] = {sample(x, y), sample(x + 1, y), sample(x, y + 1), sample(x + 1, y + 1)};
            if (std::any_of(std::begin(colors), std::end(colors), [](QRgb c) { return qAlpha(c) == 0; }))
                return {};
            const double weights[] = {(1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy};
            double red = 0, green = 0, blue = 0;
            for (int i = 0; i < 4; ++i) {
                red += qRed(colors[i]) * weights[i];
                green += qGreen(colors[i]) * weights[i];
                blue += qBlue(colors[i]) * weights[i];
            }
            line[column] = qRgb(qRound(red), qRound(green), qRound(blue));
        }
    }
    return image;
}
}  // namespace AMapTileProjection
