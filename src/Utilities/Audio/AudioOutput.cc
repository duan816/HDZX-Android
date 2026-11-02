#include "AudioOutput.h"
#include "RecordedAlertPlayer.h"
#include "FlightModePresentation.h"
#include "Fact.h"
#include "AppMessages.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QRegularExpression>
#include <QtCore/QApplicationStatic>
#include <QtCore/QTimer>
#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QThread>
#include <QtTextToSpeech/QTextToSpeech>
#include <QtTextToSpeech/QVoice>

#include <algorithm>

QGC_LOGGING_CATEGORY(AudioOutputLog, "Utilities.AudioOutput");
// qt.speech.tts.flite
// qt.speech.tts.android

namespace {
QString normalizedEnglish(const QString &text)
{
    QString normalized = text.simplified().toCaseFolded();
    static const QRegularExpression prefix(QStringLiteral("^(?:(?:pre\\s*arm|arm|preflight fail|arming check)\\s*:\\s*)+"));
    normalized.remove(prefix);
    while (normalized.endsWith('.') || normalized.endsWith('!')) normalized.chop(1);
    return normalized.trimmed();
}
}

const QHash<QString, QString> AudioOutput::_textHash = {
    { "ERR",            "error" },
    { "POSCTL",         "Position Control" },
    { "ALTCTL",         "Altitude Control" },
    { "AUTO_RTL",       "auto return to launch" },
    { "RTL",            "return To launch" },
    { "ACCEL",          "accelerometer" },
    { "RC_MAP_MODE_SW", "RC mode switch" },
    { "REJ",            "rejected" },
    { "WP",             "waypoint" },
    { "CMD",            "command" },
    { "COMPID",         "component eye dee" },
    { "PARAMS",         "parameters" },
    { "ID",             "I.D." },
    { "ADSB",           "A.D.S.B." },
    { "EKF",            "E.K.F." },
    { "PREARM",         "pre arm" },
    { "PITOT",          "pee toe" },
    { "SERVOX_FUNCTION","Servo X Function" },
};

Q_APPLICATION_STATIC(AudioOutput, _audioOutput);

AudioOutput::AudioOutput(QObject *parent)
    : QObject(parent)
    // Auto-select a real engine, except under unit tests where the "none" backend avoids probing
    // system plugins (e.g. speechd) that emit critical load errors and trip the strict log check.
    , _engine(QGC::runningUnitTests()
                  ? new QTextToSpeech(QStringLiteral("none"), this)
#ifdef Q_OS_WIN
                  : new QTextToSpeech(QTextToSpeech::availableEngines().contains(QStringLiteral("sapi"))
                                          ? QStringLiteral("sapi") : QString(), this))
#else
                  : new QTextToSpeech(this))
#endif
{
    _audioThread = new QThread(this);
    _audioThread->setObjectName(QStringLiteral("HDZX recorded speech"));
    _alertPlayer = new RecordedAlertPlayer;
    _alertPlayer->moveToThread(_audioThread);
    connect(_audioThread, &QThread::finished, _alertPlayer, &QObject::deleteLater);
    connect(_alertPlayer, &RecordedAlertPlayer::started, this, [this](quint64 generation) {
        if (!_clipPending || generation != _clipGeneration) return;
        _clipStarted = true;
        _setSpeakingAlert(_pendingAlertPresentation);
        qCInfo(AudioOutputLog) << "Recorded speech started:" << _clipText;
        emit recordingStarted(_clipText);
    });
    connect(_alertPlayer, &RecordedAlertPlayer::completed, this, [this](quint64 generation, bool failed) {
        if (_clipPending && generation == _clipGeneration) _finishRecordedAlert(failed);
    });
    _audioThread->start();
    for (const auto& indexName : {QStringLiteral("index.json"), QStringLiteral("reviewed-index.json")}) {
        QFile index(QStringLiteral(":/audio/alerts/") + indexName);
        if (!index.open(QIODevice::ReadOnly)) continue;
        const auto entries = QJsonDocument::fromJson(index.readAll()).object();
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            _recordedAlerts.insert(it.key(), it.value().toString());
        }
    }
    QFile englishIndex(QStringLiteral(":/audio/alerts/english-index.json"));
    if (englishIndex.open(QIODevice::ReadOnly)) {
        const auto entries = QJsonDocument::fromJson(englishIndex.readAll()).object();
        static const QRegularExpression parameter(QStringLiteral(R"(\\\{\d+\\\}|%[-+.\d]*[diufsg])"));
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            const QString key = normalizedEnglish(_fixTextMessageForAudio(it.key()));
            _recordedEnglishAlerts.insert(key, it.value().toString());
            QString pattern = QRegularExpression::escape(key);
            pattern.replace(parameter, QStringLiteral(".+?"));
            _recordedEnglishPatterns.append({QRegularExpression(QStringLiteral("^%1$").arg(pattern)), it.value().toString()});
        }
    }
}

AudioOutput::~AudioOutput()
{
    _alertPlayer->disconnect(this);
    _audioThread->quit();
    if (!_audioThread->wait(3000)) {
        // Never destroy a running platform audio thread or terminate it forcibly.
        _audioThread->setParent(nullptr);
        connect(_audioThread, &QThread::finished, _audioThread, &QObject::deleteLater);
        qCWarning(AudioOutputLog) << "Audio worker is still stopping";
    }
}

AudioOutput *AudioOutput::instance()
{
    return _audioOutput();
}

void AudioOutput::init(Fact* volumeFact, Fact* mutedFact)
{
    Q_CHECK_PTR(volumeFact);
    Q_CHECK_PTR(mutedFact);

    if (_initialized) {
        return;
    }

    _volumeFact = volumeFact;
    _mutedFact = mutedFact;

    // Some QTextToSpeech backends (notably Android) initialize asynchronously, so finalize on Ready rather than bailing (Qt docs).
    (void) connect(_engine, &QTextToSpeech::stateChanged, this, [this](QTextToSpeech::State state) {
        if (state == QTextToSpeech::Speaking && _speechPending) _setSpeakingAlert(_pendingAlertPresentation);
        if (state == QTextToSpeech::State::Ready) {
            _speechPending = false;
            _speakCapable = _engine->engineCapabilities().testFlag(QTextToSpeech::Capability::Speak);
            QTimer::singleShot(0, this, &AudioOutput::_startNextSpeech);
        }
        qCDebug(AudioOutputLog) << "TTS State changed to:" << state;
    });

    (void) connect(_engine, &QTextToSpeech::errorOccurred, this, [this](QTextToSpeech::ErrorReason reason, const QString &errorString) {
        qCWarning(AudioOutputLog) << "TTS error occurred. Reason:" << reason << ", Message:" << errorString;
        _speechPending = false;
        _speakCapable = false;
        QTimer::singleShot(0, this, &AudioOutput::_startNextSpeech);
    });

    (void) connect(_engine, &QTextToSpeech::engineChanged, this, [this](const QString &engine) {
        qCDebug(AudioOutputLog) << "TTS Engine set to:" << engine;
        _applyEngineSettings();
    });

    // Recorded alerts must work even without an installed system TTS language/service.
    _finishInit();
    if (_engine->state() != QTextToSpeech::State::Ready) {
        // Some backends (notably Android) start in Error state while binding to the system TTS
        // service, then transition to Ready. Defer and only warn if the engine never becomes usable.
        qCDebug(AudioOutputLog) << "System TTS not ready; recorded alerts remain available. State:" << _engine->state();
        if (!QGC::runningUnitTests()) {
            // Skip under unit tests: the "none" backend never becomes Ready and the warning would trip the strict log check.
            QTimer::singleShot(kEngineInitWarnTimeout, this, [this]() {
                if (!_speakCapable) {
                    qCWarning(AudioOutputLog) << "No usable QTextToSpeech engine available. Engine:" << _engine->engine()
                                              << "State:" << _engine->state()
                                              << "Reason:" << _engine->errorReason() << _engine->errorString();
                }
            });
        }
    }
}

void AudioOutput::_finishInit()
{
    _initialized = true;
    _applyEngineSettings();

    (void) connect(_volumeFact, &Fact::valueChanged, this, [this]() {
        _setVolume();
    });

    (void) connect(_mutedFact, &Fact::valueChanged, this, [this]() {
        _setVolume();
    });

    if (AudioOutputLog().isDebugEnabled()) {
        (void) connect(_engine, &QTextToSpeech::localeChanged, this, [](const QLocale &locale) {
            qCDebug(AudioOutputLog) << "TTS Locale change to:" << locale;
        });
        (void) connect(_engine, &QTextToSpeech::volumeChanged, this, [](double volume) {
            qCDebug(AudioOutputLog) << "TTS Volume changed to:" << volume;
        });
        (void) connect(_engine, &QTextToSpeech::sayingWord, this, [](const QString &word, qsizetype id, qsizetype start, qsizetype length) {
            qCDebug(AudioOutputLog) << "TTS Saying:" << word << "ID:" << id << "Start:" << start << "Length:" << length;
        });
    }

    _setVolume();

    if (!QGC::runningUnitTests()) {
        const QString recording = _englishRecording(QStringLiteral("RC not found"), false);
        const auto source = QUrl(QStringLiteral("qrc:/audio/alerts/") + recording);
        if (!recording.isEmpty()) {
            QMetaObject::invokeMethod(_alertPlayer, [player = _alertPlayer, source]() {
                player->prepare(source);
            }, Qt::QueuedConnection);
        }
    }

    qCDebug(AudioOutputLog) << "AudioOutput initialized with volume:" << _volumeSetting() << "%";
}

double AudioOutput::_volumeSetting() const
{
    return std::clamp(_volumeFact->rawValue().toDouble(), 0.0, 100.0);
}

bool AudioOutput::_mutedSetting() const
{
    return _mutedFact->rawValue().toBool();
}

void AudioOutput::_applyEngineSettings()
{
    if (_engine->state() != QTextToSpeech::State::Ready) {
        return;
    }

    const QLocale defaultLocale("en_US");
    if (_engine->availableLocales().contains(defaultLocale)) {
        _engine->setLocale(defaultLocale);
    }

    // Pin an explicit voice so output doesn't depend on the engine's per-OS default.
    const QList<QVoice> voices = _engine->availableVoices();
    if (!voices.isEmpty()) {
        _engine->setVoice(voices.constFirst());
    }

    _speakCapable = _engine->engineCapabilities().testFlag(QTextToSpeech::Capability::Speak);
}

void AudioOutput::_setVolume()
{
    const bool muted = _mutedSetting();
    const double volume = muted ? 0.0 : _volumeSetting();

    // qFuzzyCompare fails near zero; adding 1.0 shifts values into a safe range
    if (qFuzzyCompare(1.0 + volume, 1.0 + _lastVolume)) {
        return;
    }
    _lastVolume = volume;

    // Must normalize volume to 0.0 - 1.0 for QTextToSpeech
    const double normalizedVolume = volume / 100.0;
    (void) QMetaObject::invokeMethod(_engine, [this, volume, normalizedVolume]() {
        if (volume == 0.0) {
            // Prevent any queued text from being spoken once muted
            _speechQueue.clear();
            _speechPending = false;
            _speechAlertKey.clear();
            _activeAlertKey.clear();
            _activeSpeechPairId = 0;
            _stopRecording();
            ++_speechGeneration;
            if (_engine->state() == QTextToSpeech::Speaking) _engine->stop(QTextToSpeech::BoundaryHint::Immediate);
        }
        QMetaObject::invokeMethod(_alertPlayer, [player = _alertPlayer, normalizedVolume]() { player->setVolume(normalizedVolume); }, Qt::QueuedConnection);
        _engine->setVolume(normalizedVolume);
    });
    qCDebug(AudioOutputLog) << "AudioOutput volume set to:" << volume << "%";
}

void AudioOutput::say(const QString &text, TextMods textMods)
{
    if (!_initialized) {
        if (!QGC::runningUnitTests()) {
            qCWarning(AudioOutputLog) << "AudioOutput not initialized. Call init() before using say().";
        }
        return;
    }

    if (_volumeSetting() <= 0.0 || _mutedSetting()) {
        return;
    }

    if (!_speakCapable && !_recordedAlerts.contains(text)
        && _englishRecording(_fixTextMessageForAudio(text), false).isEmpty()) {
        qCWarning(AudioOutputLog) << "Speech Not Supported:" << text;
        return;
    }

    QString outText = _fixTextMessageForAudio(text);

    if (textMods.testFlag(TextMod::Translate)) {
        outText = tr("%1").arg(outText);
    }

    if (outText.isEmpty()) {
        return;
    }

    // All queue mutation stays on the engine thread.
    (void) QMetaObject::invokeMethod(_engine, [this, outText]() {
        if (_speechQueue.size() < kMaxTextQueueSize) {
            static const QRegularExpression chineseCharacters(QStringLiteral("[\\x{3400}-\\x{9fff}]"));
            const bool chinese = chineseCharacters.match(outText).hasMatch();
            const bool recordedEnglish = !chinese && !_englishRecording(outText, false).isEmpty();
            _speechQueue.enqueue({outText, chinese, true, recordedEnglish});
            _startNextSpeech();
        }
    });
}

void AudioOutput::sayFlightMode(const QString &mode)
{
    const QString text = FlightModePresentation::speech(mode);
    QMetaObject::invokeMethod(this, [this, text]() {
        if (!_initialized || _mutedSetting() || _volumeSetting() <= 0.0 || !_recordedAlerts.contains(text)) return;
        // Retain only the newest mode and do not bury confirmation behind a
        // periodic prearm burst. Finish the current bilingual pair first.
        _speechQueue.removeIf([](const SpeechItem &item) {
            return item.modeAnnouncement;
        });
        if (_speechQueue.size() >= kMaxTextQueueSize) return;
        SpeechItem item{text, true, true};
        item.modeAnnouncement = true;
        item.expiresAt = _monotonicMilliseconds() + 8000;
        qsizetype index = 0;
        while (_activeSpeechPairId && index < _speechQueue.size() && _speechQueue[index].pairId == _activeSpeechPairId) ++index;
        _speechQueue.insert(index, item);
        _startNextSpeech();
    }, Qt::QueuedConnection);
}

void AudioOutput::sayNavigation(const QString &text, const QString &category)
{
    QMetaObject::invokeMethod(this, [this, text, category]() {
        if (!_initialized || _mutedSetting() || _volumeSetting() <= 0.0 || !_recordedAlerts.contains(text)) return;
        _speechQueue.removeIf([&category](const SpeechItem &item) { return item.navigationCategory == category; });
        if (_speechQueue.size() >= kMaxTextQueueSize) return;
        SpeechItem item{text, true, true};
        item.navigationCategory = category;
        item.expiresAt = _monotonicMilliseconds() + 8000;
        qsizetype index = 0;
        while (_activeSpeechPairId && index < _speechQueue.size() && _speechQueue[index].pairId == _activeSpeechPairId) ++index;
        _speechQueue.insert(index, item);
        _startNextSpeech();
    }, Qt::QueuedConnection);
}

void AudioOutput::sayBilingual(const QString &english, const QString &chinese)
{
    // Add the pair atomically on the audio thread so unrelated announcements cannot split it.
    (void) QMetaObject::invokeMethod(this, [this, english, chinese]() {
        if (!_initialized || _mutedSetting() || _volumeSetting() <= 0.0 || english.trimmed().isEmpty()) {
            return;
        }
        const qint64 now = _monotonicMilliseconds();
        _pruneExpiredVehicleAlerts(now);
        SpeechItem item;
        item.text = _fixTextMessageForAudio(english);
        item.bundledEnglish = true;
        item.genericFallback = chinese.isEmpty() && _englishRecording(item.text, false).isEmpty();
        // Different NOTICE texts may resolve to the same generic recording, with no useful translation.
        if (item.genericFallback && ((_lastGenericEnglishAt >= 0 && now - _lastGenericEnglishAt < kGenericEnglishCooldownMs)
            || std::any_of(_speechQueue.cbegin(), _speechQueue.cend(), [](const SpeechItem& queued) {
                return queued.genericFallback;
            }))) return;
        if (_speechQueue.size() + (chinese.isEmpty() ? 1 : 2) > kMaxTextQueueSize) return;
        item.pairId = ++_nextSpeechPairId;
        item.expiresAt = now + kVehicleAlertQueueLifetimeMs;
        _speechQueue.enqueue(item);
        if (!chinese.isEmpty()) {
            item.text = chinese;
            item.chinese = true;
            item.bundledEnglish = false;
            _speechQueue.enqueue(item);
        }
        _startNextSpeech();
    });
}

qint64 AudioOutput::_monotonicMilliseconds()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

void AudioOutput::_pruneExpiredVehicleAlerts(qint64 now)
{
    // Once English starts, let the Chinese half finish even if it crosses the queue deadline.
    _speechQueue.removeIf([this, now](const SpeechItem& item) {
        const bool activeAlert = !item.alertKey.isEmpty() && item.alertKey == _activeAlertKey;
        const bool activePair = item.pairId != 0 && item.pairId == _activeSpeechPairId;
        return item.expiresAt > 0 && !activeAlert && !activePair && item.expiresAt <= now;
    });
}

bool AudioOutput::_makeRoomForVehicleAlert(qsizetype count)
{
    while (_speechQueue.size() + count > kMaxTextQueueSize) {
        const auto removable = [this](const SpeechItem& item) {
            return !item.calibration && !item.firmware
                && (_activeAlertKey.isEmpty() || item.alertKey != _activeAlertKey)
                && (item.pairId == 0 || item.pairId != _activeSpeechPairId);
        };
        auto oldest = std::find_if(_speechQueue.cbegin(), _speechQueue.cend(), [&removable](const SpeechItem& item) {
            return removable(item) && item.genericFallback;
        });
        if (oldest == _speechQueue.cend()) {
            oldest = std::find_if(_speechQueue.cbegin(), _speechQueue.cend(), [&removable](const SpeechItem& item) {
                return removable(item) && item.alertKey.isEmpty();
            });
        }
        if (oldest == _speechQueue.cend()) oldest = std::find_if(_speechQueue.cbegin(), _speechQueue.cend(), removable);
        if (oldest == _speechQueue.cend()) return false;
        const QString alertKey = oldest->alertKey;
        const quint64 pairId = oldest->pairId;
        if (pairId != 0) {
            _speechQueue.removeIf([pairId](const SpeechItem& item) { return item.pairId == pairId; });
        } else if (alertKey.isEmpty()) {
            _speechQueue.removeAt(std::distance(_speechQueue.cbegin(), oldest));
        } else {
            // Evict the whole stale pair, never leave a translated half behind.
            _speechQueue.removeIf([&alertKey](const SpeechItem& item) { return item.alertKey == alertKey; });
        }
    }
    return true;
}

void AudioOutput::sayVehicleAlert(const QString &english, const QString &chinese, bool prearm, int vehicleId)
{
    (void) QMetaObject::invokeMethod(this, [this, english, chinese, prearm, vehicleId]() {
        if (!_initialized || _mutedSetting() || _volumeSetting() <= 0.0 || english.trimmed().isEmpty()) return;
        const qint64 now = _monotonicMilliseconds();
        const qint64 lifetime = prearm ? kPrearmAlertQueueLifetimeMs : kVehicleAlertQueueLifetimeMs;
        _pruneExpiredVehicleAlerts(now);
        const QString outText = _fixTextMessageForAudio(english);
        const QString key = (prearm ? QStringLiteral("prearm:") : QStringLiteral("alert:"))
            + normalizedEnglish(outText);
        if (key == _activeAlertKey) return;
        bool queued = false;
        for (auto& item : _speechQueue) {
            if (item.alertKey == key) {
                item.expiresAt = now + lifetime;
                queued = true;
            }
        }
        if (queued) return;
        if (!_makeRoomForVehicleAlert(chinese.isEmpty() ? 1 : 2)) return;
        SpeechItem item;
        item.text = outText;
        item.bundledEnglish = true;
        item.alertKey = key;
        item.alertEnglish = english;
        item.alertTranslation = chinese;
        item.vehicleId = vehicleId;
        item.alertPrearm = prearm;
        item.expiresAt = now + lifetime;
        item.pairId = ++_nextSpeechPairId;
        item.genericFallback = chinese.isEmpty() && _englishRecording(outText, false).isEmpty();
        // Keep an active pair together; specific faults precede unstarted generic and informational speech.
        const auto ordinary = std::find_if(_speechQueue.cbegin(), _speechQueue.cend(), [this, &item](const SpeechItem& queuedItem) {
            const bool activePair = queuedItem.pairId != 0 && queuedItem.pairId == _activeSpeechPairId;
            const bool activeAlert = !queuedItem.alertKey.isEmpty() && queuedItem.alertKey == _activeAlertKey;
            return !queuedItem.calibration && !queuedItem.firmware && !activePair && !activeAlert
                && (queuedItem.alertKey.isEmpty() || (!item.genericFallback && queuedItem.genericFallback));
        });
        const qsizetype insertion = std::distance(_speechQueue.cbegin(), ordinary);
        _speechQueue.insert(insertion, item);
        if (!chinese.isEmpty()) {
            item.text = chinese;
            item.chinese = true;
            item.bundledEnglish = false;
            _speechQueue.insert(insertion + 1, item);
        }
        _startNextSpeech();
    });
}

void AudioOutput::clearVehicleAlerts(bool prearmOnly)
{
    (void) QMetaObject::invokeMethod(this, [this, prearmOnly]() {
        _speechQueue.removeIf([prearmOnly](const SpeechItem& item) {
            return !item.alertKey.isEmpty() && (!prearmOnly || item.alertPrearm);
        });
        if (_clipPending && !_clipAlertKey.isEmpty() && (!prearmOnly || _clipAlertPrearm)) _stopRecording();
        if (_speechPending && !_speechAlertKey.isEmpty() && (!prearmOnly || _speechAlertPrearm)) {
            _speechPending = false;
            _speechAlertKey.clear();
            ++_speechGeneration;
            _engine->stop(QTextToSpeech::BoundaryHint::Immediate);
        }
        // The queue may continue with a setup instruction; clearing does not reload either engine.
        if (!_clipPending && !_speechPending && !_activeAlertKey.isEmpty()
            && (!prearmOnly || _activeAlertKey.startsWith(QStringLiteral("prearm:")))) {
            _activeAlertKey.clear();
            _activeSpeechPairId = 0;
        }
        _startNextSpeech();
    });
}

void AudioOutput::clearVehicleAlert(const QString &english)
{
    (void) QMetaObject::invokeMethod(this, [this, english]() {
        if (english.trimmed().isEmpty()) return;
        const QString text = normalizedEnglish(_fixTextMessageForAudio(english));
        const QString prearmKey = QStringLiteral("prearm:") + text;
        const QString alertKey = QStringLiteral("alert:") + text;
        const auto matches = [&prearmKey, &alertKey](const QString &key) {
            return key == prearmKey || key == alertKey;
        };
        _speechQueue.removeIf([&matches](const SpeechItem& item) { return matches(item.alertKey); });
        if (_clipPending && matches(_clipAlertKey)) _stopRecording();
        if (_speechPending && matches(_speechAlertKey)) {
            _speechPending = false;
            _speechAlertKey.clear();
            ++_speechGeneration;
            _engine->stop(QTextToSpeech::BoundaryHint::Immediate);
        }
        if (matches(_activeAlertKey)) {
            _activeAlertKey.clear();
            _activeSpeechPairId = 0;
        }
        _startNextSpeech();
    });
}

void AudioOutput::sayCalibrationInstruction(const QString &text)
{
    _sayInstruction(text, false);
}

void AudioOutput::sayFirmwareInstruction()
{
    _sayInstruction(QStringLiteral("现在请拔下飞控的 USB 连接线，再重新插入，进入引导程序模式。"), true);
}

void AudioOutput::_sayInstruction(const QString &text, bool firmware)
{
    (void) QMetaObject::invokeMethod(this, [this, text, firmware]() {
        if (!_initialized || _mutedSetting() || _volumeSetting() <= 0 || text.isEmpty()) return;
        _speechQueue.removeIf([firmware](const SpeechItem& item) { return firmware ? item.firmware : item.calibration; });
        if (_clipPending && (firmware ? _clipFirmware : _clipCalibration)) _stopRecording();
        SpeechItem instruction;
        instruction.text = text;
        instruction.chinese = true;
        instruction.calibration = !firmware;
        instruction.firmware = firmware;
        auto pairedTail = _speechQueue.begin();
        while (pairedTail != _speechQueue.end()
               && ((!_activeAlertKey.isEmpty() && pairedTail->alertKey == _activeAlertKey)
                   || (_activeSpeechPairId != 0 && pairedTail->pairId == _activeSpeechPairId))) ++pairedTail;
        _speechQueue.insert(pairedTail, instruction);
        _startNextSpeech();
    });
}

void AudioOutput::stopCalibrationInstructions()
{
    _stopInstructions(false);
}

void AudioOutput::stopFirmwareInstructions()
{
    _stopInstructions(true);
}

void AudioOutput::_stopInstructions(bool firmware)
{
    (void) QMetaObject::invokeMethod(this, [this, firmware]() {
        _speechQueue.removeIf([firmware](const SpeechItem& item) { return firmware ? item.firmware : item.calibration; });
        if (_clipPending && (firmware ? _clipFirmware : _clipCalibration)) _stopRecording();
        _startNextSpeech();
    });
}

void AudioOutput::_stopRecording()
{
    const bool pairedTail = !_clipAlertKey.isEmpty() && !_speechQueue.isEmpty()
        && _speechQueue.first().pairId == _activeSpeechPairId && _speechQueue.first().alertKey == _clipAlertKey;
    if (!pairedTail) _setSpeakingAlert({});
    _clipPending = false;
    _clipStarted = false;
    _clipAlertKey.clear();
    ++_clipGeneration;
    QMetaObject::invokeMethod(_alertPlayer, &RecordedAlertPlayer::stop, Qt::QueuedConnection);
}

void AudioOutput::resetForVehicleChange()
{
    _setSpeakingAlert({});
    // Warnings from a removed vehicle must not block or follow a newly connected vehicle.
    // Firmware prompts survive this transition: unplugging is part of that workflow.
    _speechQueue.removeIf([](const SpeechItem& item) { return !item.firmware; });
    if (!_clipFirmware || !_clipPending) {
        _stopRecording();
        QMetaObject::invokeMethod(_alertPlayer, &RecordedAlertPlayer::reset, Qt::QueuedConnection);
    }
    ++_speechGeneration;
    _speechPending = false;
    _speechAlertKey.clear();
    _activeAlertKey.clear();
    _activeSpeechPairId = 0;
    _lastGenericEnglishAt = -1;
    if (_engine->state() == QTextToSpeech::Speaking) _engine->stop(QTextToSpeech::BoundaryHint::Immediate);
    qCInfo(AudioOutputLog) << "Speech queue reset for vehicle connection change";
    _startNextSpeech();
}

QString AudioOutput::_englishRecording(const QString &text, bool fallback) const
{
    const QString key = normalizedEnglish(text);
    const QString exact = _recordedEnglishAlerts.value(key);
    if (!exact.isEmpty()) return exact;
    for (const auto& entry : _recordedEnglishPatterns) {
        if (entry.first.match(key).hasMatch()) return entry.second;
    }
    return fallback ? _recordedEnglishAlerts.value(QStringLiteral("__fallback__")) : QString();
}

bool AudioOutput::_selectVoice(bool chinese)
{
    const QLocale::Language language = chinese ? QLocale::Chinese : QLocale::English;
    const QLocale preferred(chinese ? "zh_CN" : "en_US");
    const auto locales = _engine->availableLocales();
    auto locale = std::find(locales.cbegin(), locales.cend(), preferred);
    if (locale == locales.cend()) {
        locale = std::find_if(locales.cbegin(), locales.cend(), [language](const QLocale &candidate) {
            return candidate.language() == language;
        });
    }
    if (locale == locales.cend()) {
        qCDebug(AudioOutputLog) << "No installed speech language:" << preferred;
        return false; // Never read Chinese using an English-only voice.
    }
    _engine->setLocale(*locale);
    const auto voices = _engine->availableVoices();
    const auto gender = chinese ? QVoice::Female : QVoice::Male;
    auto voice = std::find_if(voices.cbegin(), voices.cend(), [gender](const QVoice &candidate) {
        return candidate.gender() == gender;
    });
    if (voice == voices.cend() && !voices.isEmpty()) {
        voice = voices.cbegin();
    }
    if (voice != voices.cend()) {
        _engine->setVoice(*voice);
        qCDebug(AudioOutputLog) << "Speech voice:" << voice->name() << voice->locale();
    }
    _engine->setPitch(chinese ? 0.12 : 0.0);
    _engine->setRate(0.0);
    return true;
}

void AudioOutput::_startNextSpeech()
{
    if (_speechStarting || _speechPending || _clipPending || !_initialized) {
        return;
    }
    if (_mutedSetting() || _volumeSetting() <= 0.0) {
        _setSpeakingAlert({});
        _speechQueue.clear();
        _activeAlertKey.clear();
        _activeSpeechPairId = 0;
        return;
    }
    if (!_activeAlertKey.isEmpty()
        && std::none_of(_speechQueue.cbegin(), _speechQueue.cend(), [this](const SpeechItem& item) {
            return item.alertKey == _activeAlertKey;
        })) {
        _activeAlertKey.clear();
    }
    if (_activeSpeechPairId != 0
        && std::none_of(_speechQueue.cbegin(), _speechQueue.cend(), [this](const SpeechItem& item) {
            return item.pairId == _activeSpeechPairId;
        })) _activeSpeechPairId = 0;
    _pruneExpiredVehicleAlerts(_monotonicMilliseconds());
    _speechStarting = true;
    while (!_speechQueue.isEmpty()) {
        if (_engine->state() == QTextToSpeech::Error) {
            _speakCapable = false;
        }
        const auto item = _speechQueue.dequeue();
        const auto recording = item.chinese ? _recordedAlerts.value(item.text) : _englishRecording(item.text, item.bundledEnglish);
        if (item.useRecording && !recording.isEmpty()) {
            const bool genericEnglish = !item.chinese && item.bundledEnglish
                && _englishRecording(item.text, false).isEmpty();
            const qint64 now = _monotonicMilliseconds();
            if (genericEnglish && _lastGenericEnglishAt >= 0 && now - _lastGenericEnglishAt < kGenericEnglishCooldownMs) {
                continue; // Only coalesce the identical English fallback; each fault's Chinese half remains.
            }
            if (genericEnglish) _lastGenericEnglishAt = now;
            _clipPending = true;
            _clipStarted = false;
            _clipText = item.text;
            _clipChinese = item.chinese;
            _clipCalibration = item.calibration;
            _clipFirmware = item.firmware;
            _clipAlertKey = item.alertKey;
            _clipAlertPrearm = item.alertPrearm;
            _activeAlertKey = item.alertKey;
            _activeSpeechPairId = item.pairId;
            _pendingAlertPresentation = _alertPresentation(item);
            const auto generation = ++_clipGeneration;
            const auto source = QUrl(QStringLiteral("qrc:/audio/alerts/") + recording);
            const double volume = _volumeSetting() / 100.0;
            QMetaObject::invokeMethod(_alertPlayer, [player = _alertPlayer, generation, source, volume]() {
                player->play(generation, source, volume);
            }, Qt::QueuedConnection);
            // Also recover the queue if a platform audio call itself stops returning.
            QTimer::singleShot(std::chrono::seconds(105), this, [this, generation]() {
                if (_clipPending && generation == _clipGeneration) {
                    _finishRecordedAlert(true);
                }
            });
            break;
        }
        if (item.bundledEnglish) {
            qCWarning(AudioOutputLog) << "Bundled English alert unavailable; message remains visible:" << item.text;
            continue; // Keep the selected reference voice consistent across devices.
        }
        if (item.calibration || item.firmware) {
            qCWarning(AudioOutputLog) << "Setup instruction recording unavailable:" << item.text;
            continue;
        }
        if (_speakCapable && _engine->state() != QTextToSpeech::Ready) {
            _speechQueue.prepend(item);
            break;
        }
        if (_speakCapable && _selectVoice(item.chinese)) {
            // Only change locale/voice between utterances, never during active speech.
            // SAPI/Android may report Speaking asynchronously after say() returns.
            _speechPending = true;
            _pendingAlertPresentation = _alertPresentation(item);
            _speechAlertKey = item.alertKey;
            _speechAlertPrearm = item.alertPrearm;
            _activeAlertKey = item.alertKey;
            _activeSpeechPairId = item.pairId;
            const auto generation = ++_speechGeneration;
            qCDebug(AudioOutputLog) << "Speaking utterance:" << item.text;
            _engine->say(item.text);
            QTimer::singleShot(std::chrono::seconds(2), this, [this, generation]() {
                // A backend which silently fails to start must not block the recorded Chinese half.
                if (_speechPending && generation == _speechGeneration && _engine->state() == QTextToSpeech::Ready) {
                    _speechPending = false;
                    _startNextSpeech();
                }
            });
            const auto timeout = std::chrono::seconds(std::clamp<int>(static_cast<int>(item.text.size() / 8) + 10, 10, 90));
            QTimer::singleShot(timeout, this, [this, generation]() {
                if (_speechPending && generation == _speechGeneration) {
                    _speechPending = false;
                    _engine->stop(QTextToSpeech::BoundaryHint::Immediate);
                    QTimer::singleShot(0, this, &AudioOutput::_startNextSpeech);
                }
            });
            break;
        }
    }
    _speechStarting = false;
    if (!_clipPending && !_speechPending) {
        _setSpeakingAlert({});
        _activeAlertKey.clear();
        _activeSpeechPairId = 0;
    }
}

QVariantMap AudioOutput::_alertPresentation(const SpeechItem &item)
{
    if (item.alertKey.isEmpty()) return {};
    return {{QStringLiteral("text"), item.alertEnglish}, {QStringLiteral("translation"), item.alertTranslation},
            {QStringLiteral("vehicleId"), item.vehicleId}, {QStringLiteral("persistent"), item.alertPrearm}};
}

void AudioOutput::_setSpeakingAlert(const QVariantMap &alert)
{
    if (_speakingAlert == alert) return;
    _speakingAlert = alert;
    emit speakingAlertChanged();
}

void AudioOutput::_finishRecordedAlert(bool failed)
{
    if (!_clipPending) {
        return;
    }
    const QString text = _clipText;
    _stopRecording();
    if (failed) {
        qCWarning(AudioOutputLog) << "Recorded speech interrupted/unavailable; queue continues:" << text;
    }
    emit recordingFinished(text, failed);
    QTimer::singleShot(0, this, &AudioOutput::_startNextSpeech);
}

void AudioOutput::testAudioOutput()
{
    if (!_initialized) {
        qCWarning(AudioOutputLog) << "AudioOutput not initialized. Call init() before using testAudioOutput().";
        return;
    }

    // Main-thread only (QML-invoked).
    _speechQueue.clear();
    _speechPending = false;
    _speechAlertKey.clear();
    _activeAlertKey.clear();
    _activeSpeechPairId = 0;
    _stopRecording();
    ++_speechGeneration;
    if (_engine->state() == QTextToSpeech::Speaking) _engine->stop(QTextToSpeech::BoundaryHint::Immediate);

    sayBilingual(QStringLiteral("Audio test. Please check the volume."), QStringLiteral("语音测试。请检查音量。"));
}

QString AudioOutput::_fixTextMessageForAudio(const QString &string)
{
    QString result = string;
    result = _replaceAbbreviations(result);
    result = _replaceNegativeSigns(result);
    result = _replaceDecimalPoints(result);
    result = _replaceMeters(result);
    result = _convertMilliseconds(result);
    return result;
}

QString AudioOutput::_replaceAbbreviations(const QString &input)
{
    QStringList words = input.split(' ');
    for (QString &word : words) {
        const auto it = _textHash.constFind(word.toUpper());
        if (it != _textHash.constEnd()) {
            word = it.value();
        }
    }

    return words.join(' ');
}

QString AudioOutput::_replaceNegativeSigns(const QString &input)
{
    static const QRegularExpression negNumRegex(QStringLiteral("-\\s*(?=\\d)"));
    Q_ASSERT(negNumRegex.isValid());

    QString output = input;
    (void) output.replace(negNumRegex, "negative ");
    return output;
}

QString AudioOutput::_replaceDecimalPoints(const QString &input)
{
    static const QRegularExpression realNumRegex(QStringLiteral("([0-9]+)(\\.)([0-9]+)"));
    Q_ASSERT(realNumRegex.isValid());

    QString output = input;
    QRegularExpressionMatch realNumRegexMatch = realNumRegex.match(output);
    while (realNumRegexMatch.hasMatch()) {
        if (!realNumRegexMatch.captured(2).isNull()) {
            (void) output.replace(realNumRegexMatch.capturedStart(2), realNumRegexMatch.capturedEnd(2) - realNumRegexMatch.capturedStart(2), QStringLiteral(" point "));
        }
        realNumRegexMatch = realNumRegex.match(output);
    }

    return output;
}

QString AudioOutput::_replaceMeters(const QString &input)
{
    static const QRegularExpression realNumMeterRegex(QStringLiteral("[0-9]*\\.?[0-9]\\s?(m)([^A-Za-z]|$)"));
    Q_ASSERT(realNumMeterRegex.isValid());

    QString output = input;
    QRegularExpressionMatch realNumMeterRegexMatch = realNumMeterRegex.match(output);
    while (realNumMeterRegexMatch.hasMatch()) {
        if (!realNumMeterRegexMatch.captured(1).isNull()) {
            (void) output.replace(realNumMeterRegexMatch.capturedStart(1), realNumMeterRegexMatch.capturedEnd(1) - realNumMeterRegexMatch.capturedStart(1), QStringLiteral(" meters"));
        }
        realNumMeterRegexMatch = realNumMeterRegex.match(output);
    }

    return output;
}

QString AudioOutput::_convertMilliseconds(const QString &input)
{
    QString result = input;

    QString match;
    int number;
    if (_getMillisecondString(input, match, number) && (number >= 1000)) {
        QString newNumber;
        if (number < 60000) {
            const int seconds = number / 1000;
            const int ms = number - (seconds * 1000);
            newNumber = QStringLiteral("%1 second%2").arg(seconds).arg(seconds > 1 ? "s" : "");
            if (ms > 0) {
                (void) newNumber.append(QStringLiteral(" and %1 millisecond").arg(ms));
            }
        } else {
            const int minutes = number / 60000;
            const int seconds = (number - (minutes * 60000)) / 1000;
            newNumber = QStringLiteral("%1 minute%2").arg(minutes).arg(minutes > 1 ? "s" : "");
            if (seconds > 0) {
                (void) newNumber.append(QStringLiteral(" and %1 second%2").arg(seconds).arg(seconds > 1 ? "s" : ""));
            }
        }
        (void) result.replace(match, newNumber);
    }

    return result;
}

bool AudioOutput::_getMillisecondString(const QString &string, QString &match, int &number)
{
    static const QRegularExpression msRegex("((?<number>[0-9]+)ms)");
    Q_ASSERT(msRegex.isValid());

    bool result = false;

    QRegularExpressionMatch regexpMatch = msRegex.match(string);
    if (regexpMatch.hasMatch()) {
        match = regexpMatch.captured(0);
        const QString numberStr = regexpMatch.captured("number");
        number = numberStr.toInt();
        result = true;
    }

    return result;
}
