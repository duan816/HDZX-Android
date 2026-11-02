#include "RecordedAlertPlayer.h"

#include <QtCore/QDataStream>
#include <QtCore/QFile>
#include <QtCore/QTimer>
#include <QtMultimedia/QMediaDevices>
#include <QtMultimedia/QAudioDevice>
#include <QtMultimedia/QSoundEffect>
#ifdef Q_OS_WIN
#include <QtCore/QBuffer>
#include <QtCore/QtEndian>
#include <QtMultimedia/QAudioSink>
#endif
#ifdef Q_OS_ANDROID
#include <QtCore/QCryptographicHash>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QSaveFile>
#include <QtCore/QStandardPaths>
#endif

#include <algorithm>

RecordedAlertPlayer::RecordedAlertPlayer(QObject *parent)
    : QObject(parent), _deadline(new QTimer(this))
{
    _deadline->setSingleShot(true);
    connect(_deadline, &QTimer::timeout, this, [this]() {
        // Device/backend failures can omit playingChanged(false). Never leave the queue locked.
#ifdef Q_OS_ANDROID
        _finish(true);
#elif defined(Q_OS_WIN)
        _finish(!_started || !_pcmSink || _pcmSink->state() != QtAudio::IdleState
                || _pcmSink->error() != QtAudio::NoError);
#else
        _finish(!_started || !_player || _player->isPlaying());
#endif
    });
#ifdef Q_OS_WIN
    _pcmBuffer = new QBuffer(this);
#endif
#ifdef Q_OS_ANDROID
    _playbackPoll = new QTimer(this);
    _playbackPoll->setInterval(30);
    connect(_playbackPoll, &QTimer::timeout, this, [this]() {
        if (!_generation || !_started) return;
        const int status = _androidPlayer.isValid() ? _androidPlayer.callMethod<jint>("status") : -1;
        if (status != 1) _finish(status < 0);
    });
#endif
}

RecordedAlertPlayer::~RecordedAlertPlayer()
{
#if defined(Q_OS_ANDROID) || defined(Q_OS_WIN)
    _discardPlayer();
#endif
}

void RecordedAlertPlayer::_ensurePlayer()
{
#ifdef Q_OS_ANDROID
    // Android crash traces show the Qt sound backend's socket notifier failing
    // on disconnect. Keep native MediaPlayer and all JNI calls on this worker.
    if (!_androidPlayer.isValid()) _androidPlayer = QJniObject("org/mavlink/qgroundcontrol/RecordedSpeechPlayer");
#else
    if (!_devices) {
        _devices = new QMediaDevices(this);
        _outputId = QMediaDevices::defaultAudioOutput().id();
        connect(_devices, &QMediaDevices::audioOutputsChanged, this, &RecordedAlertPlayer::_audioOutputsChanged);
    }
#ifndef Q_OS_WIN
    if (_player) return;
    _player = new QSoundEffect(this);
    connect(_player, &QSoundEffect::statusChanged, this, [this]() {
        if (_player->status() == QSoundEffect::Error) {
            // Queue completion outside a QSoundEffect setter/notification stack.
            const auto generation = _generation;
            QTimer::singleShot(0, this, [this, generation]() {
                if (generation && generation == _generation) _finish(true);
            });
        } else {
            _startIfReady();
        }
    });
    connect(_player, &QSoundEffect::playingChanged, this, [this]() {
        if (_generation && _started && !_player->isPlaying()) _finish(false);
    });
#endif
#endif
}

#ifdef Q_OS_WIN
std::optional<RecordedAlertPlayer::PcmClip> RecordedAlertPlayer::_decodeWave(const QByteArray &wave)
{
    // Read RIFF chunks instead of assuming a 44-byte header: ffmpeg adds LIST,
    // and other valid WAV writers add JUNK or extended fmt chunks.
    constexpr qsizetype maxWaveBytes = 4 * 1024 * 1024;
    if (wave.size() < 12 || wave.size() > maxWaveBytes || wave.first(4) != "RIFF"
        || wave.sliced(8, 4) != "WAVE") return std::nullopt;
    const auto u16 = [&wave](qsizetype offset) { return qFromLittleEndian<quint16>(wave.constData() + offset); };
    const auto u32 = [&wave](qsizetype offset) { return qFromLittleEndian<quint32>(wave.constData() + offset); };
    const quint64 end = quint64(u32(4)) + 8;
    if (end < 12 || end > quint64(wave.size())) return std::nullopt;
    std::optional<QAudioFormat> format;
    QByteArray samples;
    quint64 offset = 12;
    while (offset < end) {
        if (end - offset < 8) return std::nullopt;
        const auto name = wave.sliced(qsizetype(offset), 4);
        const quint64 length = u32(qsizetype(offset + 4));
        const quint64 start = offset + 8;
        const quint64 paddedLength = length + (length & 1);
        if (paddedLength > end - start) return std::nullopt;
        if (name == "fmt ") {
            if (format || length < 16 || u16(qsizetype(start)) != 1) return std::nullopt;
            const quint16 channels = u16(qsizetype(start + 2));
            const quint32 rate = u32(qsizetype(start + 4));
            const quint16 block = u16(qsizetype(start + 12));
            if ((channels != 1 && channels != 2) || rate < 8000 || rate > 192000
                || u16(qsizetype(start + 14)) != 16 || block != channels * 2
                || u32(qsizetype(start + 8)) != rate * block) return std::nullopt;
            format.emplace();
            format->setSampleRate(int(rate));
            format->setChannelCount(channels);
            format->setSampleFormat(QAudioFormat::Int16);
        } else if (name == "data") {
            if (!samples.isEmpty() || !length) return std::nullopt;
            samples = wave.sliced(qsizetype(start), qsizetype(length));
        }
        offset = start + paddedLength;
    }
    if (!format || samples.isEmpty() || samples.size() % format->bytesPerFrame() != 0
        || format->durationForBytes(samples.size()) > 90000000) return std::nullopt;
    return PcmClip{*format, std::move(samples)};
}

void RecordedAlertPlayer::_rememberPcm(const QUrl &source, const PcmClip &clip)
{
    constexpr qsizetype maxCacheBytes = 2 * 1024 * 1024;
    constexpr qsizetype maxCacheClips = 4;
    if (clip.samples.size() > maxCacheBytes) return;
    if (_pcmCache.contains(source)) _pcmCacheBytes -= _pcmCache.value(source).samples.size();
    _pcmLru.removeAll(source);
    _pcmCache.insert(source, clip);
    _pcmCacheBytes += clip.samples.size();
    _pcmLru.append(source);
    while (_pcmCacheBytes > maxCacheBytes || _pcmLru.size() > maxCacheClips) {
        _pcmCacheBytes -= _pcmCache.take(_pcmLru.takeFirst()).samples.size();
    }
}

std::optional<RecordedAlertPlayer::PcmClip> RecordedAlertPlayer::_loadPcm(const QUrl &source)
{
    const auto cached = _pcmCache.constFind(source);
    if (cached != _pcmCache.cend()) {
        _pcmLru.removeAll(source);
        _pcmLru.append(source);
        return *cached;
    }
    const QString filename = source.scheme() == QLatin1String("qrc") ? QLatin1Char(':') + source.path() : source.toLocalFile();
    QFile file(filename);
    if (!file.open(QIODevice::ReadOnly) || file.size() > 4 * 1024 * 1024) return std::nullopt;
    const auto clip = _decodeWave(file.readAll());
    if (clip) _rememberPcm(source, *clip);
    return clip;
}

bool RecordedAlertPlayer::_ensurePcmSink(const QAudioFormat &format)
{
    // QSoundEffect in Qt 6.10 migrates its shared RT engine back to qApp and
    // holds a mutex across sink resume/suspend. Direct QAudioSink stays here.
    if (_pcmSink && _pcmSink->format() == format) return true;
    _discardPlayer();
    const auto device = QMediaDevices::defaultAudioOutput();
    if (device.isNull() || !device.isFormatSupported(format)) return false;
    _pcmSink = new QAudioSink(device, format, this);
    _pcmSink->setBufferSize(format.bytesForDuration(60000));
    connect(_pcmSink, &QAudioSink::stateChanged, this, &RecordedAlertPlayer::_sinkStateChanged);
    return true;
}

void RecordedAlertPlayer::_sinkStateChanged(QtAudio::State state)
{
    if (!_generation || !_started || (state != QtAudio::IdleState && state != QtAudio::StoppedState)) return;
    const bool failed = !_pcmSink || _pcmSink->error() != QtAudio::NoError || state == QtAudio::StoppedState;
    const auto generation = _generation;
    const auto serial = _playbackSerial;
    // start/reset can emit synchronously. Finish outside that setter, and ignore
    // old callbacks after stop, vehicle reset or a device-recovery replay.
    QTimer::singleShot(0, this, [this, generation, serial, failed] {
        if (_generation != generation || _playbackSerial != serial) return;
        // Idle may be emitted inside start(). Compute the remaining tail only
        // after start returns, excluding slow device-open time from playback.
        const int drainDelay = failed || !_pcmClock.isValid() ? 0
            : int(std::clamp<qint64>(_duration + 60 - _pcmClock.elapsed(), 0, _duration + 60));
        if (!drainDelay) { _finish(failed); return; }
        QTimer::singleShot(drainDelay, this, [this, generation, serial] {
            if (_generation == generation && _playbackSerial == serial) _finish(false);
        });
    });
}
#endif

void RecordedAlertPlayer::prepare(const QUrl &source)
{
    // Open the backend and decode a reference sample on this worker before
    // the first alert. No play() call, generation or playback notification.
    if (source.isEmpty()) return;
    _preparedSource = source;
    if (_generation) return;
    _ensurePlayer();
#ifdef Q_OS_ANDROID
    const auto path = QJniObject::fromString(_androidRecordingPath(source));
    if (_androidPlayer.isValid() && !path.toString().isEmpty())
        _androidPlayer.callMethod<jboolean>("prepare", "(Ljava/lang/String;)Z", path.object<jstring>());
#elif defined(Q_OS_WIN)
    if (const auto clip = _loadPcm(source)) _ensurePcmSink(clip->format);
#else
    _player->setSource(source);
#endif
}

void RecordedAlertPlayer::play(quint64 generation, const QUrl &source, double volume)
{
    stop();
    _ensurePlayer();
    _generation = generation;
    _source = source;
    _volume = volume;
    _recoveries = 0;
#ifndef Q_OS_WIN
    _duration = _durationMs(source);
#endif
#ifdef Q_OS_ANDROID
    _deadline->start(10000);
    _startIfReady();
#elif defined(Q_OS_WIN)
    const auto clip = _loadPcm(source);
    if (!clip || !_ensurePcmSink(clip->format)) { _finish(true); return; }
    _pcmBuffer->setData(clip->samples);
    if (!_pcmBuffer->open(QIODevice::ReadOnly)) { _finish(true); return; }
    _duration = std::clamp<int>(static_cast<int>(clip->format.durationForBytes(clip->samples.size()) / 1000), 200, 90000);
    _pcmSink->setVolume(static_cast<float>(std::clamp(volume, 0.0, 1.0)));
    _startIfReady();
#else
    _player->setVolume(static_cast<float>(std::clamp(volume, 0.0, 1.0)));
    _deadline->start(10000);
    _player->setSource(source);
    // Replaying an already loaded URL does not emit statusChanged again.
    _startIfReady();
#endif
}

void RecordedAlertPlayer::_startIfReady()
{
#ifdef Q_OS_ANDROID
    if (!_generation || _started) return;
    const auto path = QJniObject::fromString(_androidRecordingPath(_source));
    if (!_androidPlayer.isValid() || path.toString().isEmpty()
        || !_androidPlayer.callMethod<jboolean>("start", "(Ljava/lang/String;F)Z", path.object<jstring>(),
                                               static_cast<jfloat>(std::clamp(_volume, 0.0, 1.0)))) {
        _finish(true);
        return;
    }
    _started = true;
    _deadline->start(_duration + 2000);
    _playbackPoll->start();
    emit started(_generation);
#elif defined(Q_OS_WIN)
    if (!_generation || _started || !_pcmSink || !_pcmBuffer->isOpen()) return;
    _started = true;
    _pcmSink->start(_pcmBuffer);
    if (_pcmSink->error() != QtAudio::NoError || _pcmSink->state() == QtAudio::StoppedState) {
        _finish(true);
        return;
    }
    _pcmClock.start();
    _deadline->start(_duration + 2000);
    emit started(_generation);
#else
    if (!_generation || _started || !_player || _player->status() != QSoundEffect::Ready) return;
    _started = true;
    _deadline->start(_duration + 2000);
    _player->play();
    emit started(_generation);
#endif
}

void RecordedAlertPlayer::_finish(bool failed)
{
    if (!_generation) return;
    const auto generation = _generation;
    stop();
    if (failed) _discardPlayer();
    emit completed(generation, failed);
}

void RecordedAlertPlayer::stop()
{
    _generation = 0;
    _started = false;
    _deadline->stop();
#ifdef Q_OS_ANDROID
    _playbackPoll->stop();
    if (_androidPlayer.isValid()) _androidPlayer.callMethod<void>("stop");
#elif defined(Q_OS_WIN)
    ++_playbackSerial;
    _pcmClock.invalidate();
    if (_pcmSink) _pcmSink->reset();
    _pcmBuffer->close();
    _pcmBuffer->setData(QByteArray());
#else
    if (_player) _player->stop();
#endif
}

void RecordedAlertPlayer::reset()
{
    stop();
    // Switching aircraft invalidates speech, not the healthy output device.
    // Device changes and playback errors still recreate the player below.
#ifdef Q_OS_ANDROID
    if (_androidPlayer.isValid() && _androidPlayer.callMethod<jint>("status") < 0) _discardPlayer();
#elif defined(Q_OS_WIN)
    // reset() discards the old clip, retaining the worker-owned sink and decoded cache.
#else
    if (_player && _player->status() == QSoundEffect::Error) _discardPlayer();
#endif
}

void RecordedAlertPlayer::setVolume(double volume)
{
    _volume = volume;
#ifdef Q_OS_ANDROID
    if (_androidPlayer.isValid()) _androidPlayer.callMethod<void>("setVolume", "(F)V", static_cast<jfloat>(std::clamp(volume, 0.0, 1.0)));
#elif defined(Q_OS_WIN)
    if (_pcmSink) _pcmSink->setVolume(static_cast<float>(std::clamp(volume, 0.0, 1.0)));
#else
    if (_player) _player->setVolume(static_cast<float>(std::clamp(volume, 0.0, 1.0)));
#endif
}

void RecordedAlertPlayer::_audioOutputsChanged()
{
    const auto output = QMediaDevices::defaultAudioOutput().id();
    // Enumeration/volume notifications for an unchanged default must not interrupt speech.
    if (output == _outputId) return;
    _outputId = output;
    const auto generation = _generation;
    if (!generation) {
        _discardPlayer();
        prepare(_preparedSource);
        return;
    }
    if (output.isEmpty() || _recoveries >= 2) { _finish(true); return; }
    const auto source = _source;
    const double volume = _volume;
    const int recoveries = _recoveries + 1;
    reset();
    _discardPlayer();
    play(generation, source, volume);
    _recoveries = recoveries;
}

void RecordedAlertPlayer::_discardPlayer()
{
#ifdef Q_OS_ANDROID
    if (_androidPlayer.isValid()) _androidPlayer.callMethod<void>("release");
    _androidPlayer = QJniObject();
#elif defined(Q_OS_WIN)
    if (!_pcmSink) return;
    _pcmSink->disconnect(this);
    _pcmSink->reset();
    _pcmSink->deleteLater();
    _pcmSink = nullptr;
#else
    if (!_player) return;
    _player->disconnect(this);
    _player->deleteLater();
    _player = nullptr;
#endif
}

#ifdef Q_OS_ANDROID
QString RecordedAlertPlayer::_androidRecordingPath(const QUrl &source)
{
    const QString filename = source.scheme() == QLatin1String("qrc") ? QLatin1Char(':') + source.path() : source.toLocalFile();
    QFile file(filename);
    if (!file.open(QIODevice::ReadOnly)) return {};
    const QByteArray data = file.readAll();
    if (data.isEmpty()) return {};
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/recorded-speech");
    if (!QDir().mkpath(directory)) return {};
    const QString path = directory + QLatin1Char('/') + QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex()) + QStringLiteral(".wav");
    if (QFile::exists(path) && QFileInfo(path).size() == data.size()) return path;
    QSaveFile target(path);
    if (!target.open(QIODevice::WriteOnly) || target.write(data) != data.size() || !target.commit()) return {};
    return path;
}
#endif

int RecordedAlertPlayer::_durationMs(const QUrl &source)
{
    const QString filename = source.scheme() == QLatin1String("qrc") ? QLatin1Char(':') + source.path() : source.toLocalFile();
    QFile file(filename);
    if (!file.open(QIODevice::ReadOnly) || file.size() < 44) return 90000;
    // Bundled recordings are PCM WAV. Byte rate is in the RIFF fmt header.
    if (file.read(4) != "RIFF" || !file.seek(8) || file.read(4) != "WAVE"
        || file.read(4) != "fmt " || !file.seek(28)) return 90000;
    QDataStream stream(&file);
    stream.setByteOrder(QDataStream::LittleEndian);
    quint32 byteRate = 0;
    stream >> byteRate;
    return byteRate ? static_cast<int>(std::clamp<qint64>(file.size() * 1000 / byteRate, 200, 90000)) : 90000;
}
