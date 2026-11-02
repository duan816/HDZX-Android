#pragma once
#include "AMapTileReply.h"
#include "MapProvider.h"

class AMapSatelliteProvider final : public MapProvider
{
public:
    AMapSatelliteProvider()
        : MapProvider(QStringLiteral("高德 Satellite"), QStringLiteral("https://www.amap.com/"), QStringLiteral("png"),
                      QGC_AVERAGE_TILE_SIZE, MapProvider::SatelliteMapDay)
    {}

    bool isAmapProvider() const override { return true; }

private:
    QString _getURL(int x, int y, int zoom) const override { return AMapTileReply::tileUrl(x, y, zoom).toString(); }
};
