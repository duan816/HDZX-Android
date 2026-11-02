#pragma once

#include <QtCore/QObject>
#include <QtCore/QUrl>
#include <QtCore/QByteArray>
#ifdef Q_OS_WIN
#include <QtCore/QHash>
#include <QtCore/QList>
#include <QtCore/QElapsedTimer>
#include <QtMultimedia/QAudioFormat>
#include <QtMultimedia/qaudio.h>
#include <optional>
#endif
#ifdef Q_OS_ANDROID
#include <QtCore/QJniObject>
#endif

class QSoundEffect;
class QMediaDevices;
class QTimer;
class QAudioSink;
class QBuffer;

// Lives entirely on the audio worker thread, including resource loading and device recovery.
class RecordedAlertPlayer : public QObject
{
    Q_OBJECT
    friend class AudioOutputTest;
    friend class HDZXAudioReview;
public:
    explicit RecordedAlertPlayer(QObject *parent = nullptr);
    ~RecordedAlertPlayer() override;

public slots:
    void prepare(const QUrl &source);
    void play(quint64 generation, const QUrl &source, double volume);
    void stop();
    void reset();
    void setVolume(double volume);

signals:
    void started(quint64 generation);
    void completed(quint64 generation, bool failed);

private:
    void _ensurePlayer();
    void _startIfReady();
    void _finish(bool failed);
    void _discardPlayer();
    void _audioOutputsChanged();
    static int _durationMs(const QUrl &source);
#ifdef Q_OS_WIN
    struct PcmClip {
        QAudioFormat format;
        QByteArray samples;
    };
    static std::optional<PcmClip> _decodeWave(const QByteArray &wave);
    std::optional<PcmClip> _loadPcm(const QUrl &source);
    void _rememberPcm(const QUrl &source, const PcmClip &clip);
    bool _ensurePcmSink(const QAudioFormat &format);
    void _sinkStateChanged(QtAudio::State state);
    QAudioSink *_pcmSink = nullptr;
    QBuffer *_pcmBuffer = nullptr;
    QHash<QUrl, PcmClip> _pcmCache;
    QList<QUrl> _pcmLru;
    qsizetype _pcmCacheBytes = 0;
    quint64 _playbackSerial = 0;
    QElapsedTimer _pcmClock;
#endif
#ifdef Q_OS_ANDROID
    static QString _androidRecordingPath(const QUrl &source);
    QJniObject _androidPlayer;
    QTimer *_playbackPoll = nullptr;
#endif

    QSoundEffect *_player = nullptr;
    QMediaDevices *_devices = nullptr;
    QTimer *_deadline = nullptr;
    quint64 _generation = 0;
    bool _started = false;
    int _duration = 0;
    QByteArray _outputId;
    QUrl _source;
    QUrl _preparedSource;
    double _volume = 1.0;
    int _recoveries = 0;
};
