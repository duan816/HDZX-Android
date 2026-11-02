#pragma once

#include <QtCore/QPointer>
#include <QtCore/QVector>
#include <QtNetwork/QNetworkReply>

#include "AMapTileProjection.h"

class QNetworkAccessManager;

class AMapTileReply final : public QNetworkReply
{
    Q_OBJECT
public:
    AMapTileReply(QNetworkAccessManager* manager, const QNetworkRequest& request, int x, int y, int zoom,
                  QObject* parent = nullptr);
    ~AMapTileReply() override;
    void abort() override;
    qint64 bytesAvailable() const override;
    static QUrl tileUrl(int x, int y, int zoom);

protected:
    qint64 readData(char* data, qint64 maximum) override;

private:
    void _start();
    void _complete();
    void _fail(NetworkError error, const QString& message);
    QPointer<QNetworkAccessManager> _manager;
    AMapTileProjection::Mesh _mapping;
    QHash<QPoint, QImage> _images;
    QVector<QPointer<QNetworkReply>> _requests;
    QByteArray _data;
    qint64 _offset = 0;
    int _remaining = 0;
    bool _done = false;
    bool _rendering = false;
};
