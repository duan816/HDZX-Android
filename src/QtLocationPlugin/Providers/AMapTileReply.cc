#include "AMapTileReply.h"

#include <QtConcurrent/QtConcurrentRun>
#include <QtCore/QBuffer>
#include <QtCore/QCache>
#include <QtCore/QFutureWatcher>
#include <QtCore/QMutex>
#include <QtCore/QMutexLocker>
#include <QtCore/QThreadPool>
#include <QtCore/QTimer>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkRequest>
#include <algorithm>
#include <cstring>

namespace {
QMutex rawCacheMutex;
QCache<quint64, QImage> rawCache(64);

QThreadPool* projectionPool()
{
    static QThreadPool pool;
    static const bool configured = [] {
        pool.setMaxThreadCount(2);
        return true;
    }();
    Q_UNUSED(configured);
    return &pool;
}

quint64 cacheKey(int x, int y, int zoom)
{
    return (quint64(zoom) << 58) | (quint64(x) << 29) | quint64(y);
}
}  // namespace

AMapTileReply::AMapTileReply(QNetworkAccessManager* manager, const QNetworkRequest& request, int x, int y, int zoom,
                             QObject* parent)
    : QNetworkReply(parent), _manager(manager), _mapping(AMapTileProjection::mesh(x, y, zoom))
{
    setRequest(request);
    setUrl(request.url());
    setOperation(QNetworkAccessManager::GetOperation);
    open(QIODevice::ReadOnly | QIODevice::Unbuffered);
    QTimer::singleShot(0, this, &AMapTileReply::_start);
    QTimer::singleShot(30000, this, [this] {
        if (!_done)
            _fail(TimeoutError, tr("高德图块加载超时"));
    });
}

AMapTileReply::~AMapTileReply()
{
    _done = true;
    for (const auto& reply : std::as_const(_requests))
        if (reply) {
            reply->disconnect(this);
            reply->abort();
        }
}

QUrl AMapTileReply::tileUrl(int x, int y, int zoom)
{
    return QUrl(
        QStringLiteral("https://webst01.is.autonavi.com/appmaptile?style=6&lang=zh_cn&size=1&scale=1&x=%1&y=%2&z=%3")
            .arg(x)
            .arg(y)
            .arg(zoom));
}

void AMapTileReply::_start()
{
    if (_done)
        return;
    if (!_manager || !_mapping.isValid()) {
        _fail(ContentNotFoundError, tr("高德图块坐标无效"));
        return;
    }
    _remaining = _mapping.tiles.size();
    const int count = 1 << _mapping.sourceZoom;
    for (const QPoint& key : std::as_const(_mapping.tiles)) {
        const int x = ((key.x() % count) + count) % count;
        const quint64 id = cacheKey(x, key.y(), _mapping.sourceZoom);
        {
            QMutexLocker lock(&rawCacheMutex);
            if (const auto* image = rawCache.object(id)) {
                _images.insert(key, *image);
                --_remaining;
                continue;
            }
        }
        QNetworkRequest rawRequest = request();
        rawRequest.setUrl(tileUrl(x, key.y(), _mapping.sourceZoom));
        rawRequest.setRawHeader("Referer", "https://www.amap.com/");
        rawRequest.setTransferTimeout(15000);
        auto* reply = _manager->get(rawRequest);
        reply->setParent(this);
        _requests.append(reply);
        connect(reply, &QNetworkReply::finished, this, [this, reply, key, id] {
            reply->deleteLater();
            if (_done)
                return;
            const QByteArray bytes = reply->readAll();
            if (reply->error() != NoError || bytes.size() > 4 * 1024 * 1024) {
                _fail(reply->error() == NoError ? ProtocolFailure : reply->error(), tr("高德卫星图块请求失败"));
                return;
            }
            QImage image = QImage::fromData(bytes);
            if (image.size() != QSize(256, 256)) {
                _fail(ProtocolFailure, tr("高德返回了无效影像，未写入地图缓存"));
                return;
            }
            image = image.convertToFormat(QImage::Format_RGB32);
            {
                QMutexLocker lock(&rawCacheMutex);
                rawCache.insert(id, new QImage(image));
            }
            _images.insert(key, image);
            if (--_remaining == 0)
                _complete();
        });
    }
    if (_remaining == 0)
        _complete();
}

void AMapTileReply::_complete()
{
    if (_done || _rendering)
        return;
    _rendering = true;
    auto* watcher = new QFutureWatcher<QByteArray>(this);
    connect(watcher, &QFutureWatcher<QByteArray>::finished, this, [this, watcher] {
        watcher->deleteLater();
        if (_done)
            return;
        _data = watcher->result();
        if (_data.isEmpty()) {
            _fail(ProtocolFailure, tr("高德影像坐标校正失败，未使用未校正图块"));
            return;
        }
        _done = true;
        setAttribute(QNetworkRequest::HttpStatusCodeAttribute, 200);
        setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("image/png"));
        setHeader(QNetworkRequest::ContentLengthHeader, _data.size());
        setFinished(true);
        emit readyRead();
        emit finished();
    });
    // Pixel resampling and PNG encoding must not stall flight telemetry or UI input.
    watcher->setFuture(QtConcurrent::run(projectionPool(), [mapping = _mapping, images = _images] {
        const QImage image = AMapTileProjection::render(mapping, images);
        QByteArray data;
        QBuffer buffer(&data);
        if (image.isNull() || !buffer.open(QIODevice::WriteOnly) || !image.save(&buffer, "PNG"))
            return QByteArray();
        return data;
    }));
}

void AMapTileReply::_fail(NetworkError code, const QString& message)
{
    if (_done)
        return;
    _done = true;
    for (const auto& reply : std::as_const(_requests))
        if (reply)
            reply->abort();
    setError(code, message);
    setFinished(true);
    emit errorOccurred(code);
    emit finished();
}

void AMapTileReply::abort()
{
    _fail(OperationCanceledError, tr("地图图块请求已取消"));
}

qint64 AMapTileReply::bytesAvailable() const
{
    return _data.size() - _offset + QNetworkReply::bytesAvailable();
}

qint64 AMapTileReply::readData(char* data, qint64 maximum)
{
    const qint64 count = std::min(maximum, qint64(_data.size() - _offset));
    if (count <= 0)
        return _done ? -1 : 0;
    std::memcpy(data, _data.constData() + _offset, static_cast<size_t>(count));
    _offset += count;
    return count;
}
