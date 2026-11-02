#pragma once

#include <QtCore/QObject>
#include <QtCore/QQueue>
#include <QtCore/QHash>
#include <QtCore/QRegularExpression>
#include <QtCore/QVariantMap>

#include <chrono>

class QTextToSpeech;
class RecordedAlertPlayer;
class QThread;
class Fact;
class AudioOutputTest;

/// \brief The AudioOutput class provides functionality for audio output using text-to-speech.
///
class AudioOutput : public QObject
{
    Q_OBJECT

    friend AudioOutputTest;
    friend class HDZXAudioReview;

public:
    /// Enumeration for text modification options.
    enum class TextMod {
        None = 0,
        Translate = 1 << 0,
    };
    Q_FLAG(TextMod)
    Q_DECLARE_FLAGS(TextMods, TextMod)

    /// Constructs an AudioOutput object.
    ///     @param parent The parent QObject.
    explicit AudioOutput(QObject *parent = nullptr);

    /// Destructor for the AudioOutput class.
    ~AudioOutput();

    /// Gets the singleton instance of AudioOutput.
    ///     @return The singleton instance.
    static AudioOutput *instance();

    /// Initialize the Singleton
    void init(Fact *volumeFact, Fact *mutedFact);

    /// Reads the specified text with optional text modifications.
    ///     @param text The text to be read.
    ///     @param textMods The text modifications to apply.
    void say(const QString &text, TextMods textMods = TextMod::None);
    void sayBilingual(const QString &english, const QString &chinese);
    void sayFlightMode(const QString &mode);
    void sayNavigation(const QString &text, const QString &category);
    /// Queues a fresh vehicle alert once, keeping its English/Chinese pair together.
    void sayVehicleAlert(const QString &english, const QString &chinese, bool prearm = false, int vehicleId = -1);
    QVariantMap speakingAlert() const { return _speakingAlert; }
    /// Stops resolved alerts without interrupting setup instructions or ordinary announcements.
    void clearVehicleAlerts(bool prearmOnly = false);
    /// Stops one resolved alert in either prearm or in-flight form, preserving other faults.
    void clearVehicleAlert(const QString &english);
    void sayCalibrationInstruction(const QString &text);
    void stopCalibrationInstructions();
    void resetForVehicleChange();
    void sayFirmwareInstruction();
    void stopFirmwareInstructions();

    /// Tests the audio output. Will stop current output before test
    void testAudioOutput();

signals:
    void speakingAlertChanged();
    void recordingStarted(const QString &text);
    void recordingFinished(const QString &text, bool failed);

private:
    QTextToSpeech *_engine = nullptr;
    RecordedAlertPlayer *_alertPlayer = nullptr;
    QThread *_audioThread = nullptr;
    QHash<QString, QString> _recordedAlerts;
    QHash<QString, QString> _recordedEnglishAlerts;
    QList<QPair<QRegularExpression, QString>> _recordedEnglishPatterns;
    bool _clipPending = false;
    bool _clipStarted = false;
    QString _clipText;
    bool _clipChinese = true;
    bool _clipCalibration = false;
    bool _clipFirmware = false;
    QString _clipAlertKey;
    bool _clipAlertPrearm = false;
    quint64 _clipGeneration = 0;
    bool _initialized = false;
    bool _speakCapable = false;
    Fact *_volumeFact = nullptr;
    Fact *_mutedFact = nullptr;
    double _lastVolume = -1.0;
    struct SpeechItem {
        QString text;
        bool chinese = false;
        bool useRecording = true;
        bool bundledEnglish = false;
        bool calibration = false;
        bool firmware = false;
        QString alertKey;
        bool alertPrearm = false;
        qint64 expiresAt = 0;
        quint64 pairId = 0;
        bool genericFallback = false;
        QString alertEnglish;
        QString alertTranslation;
        int vehicleId = -1;
        bool modeAnnouncement = false;
        QString navigationCategory;
    };
    QQueue<SpeechItem> _speechQueue;
    bool _speechStarting = false;
    bool _speechPending = false;
    QString _speechAlertKey;
    bool _speechAlertPrearm = false;
    QString _activeAlertKey;
    quint64 _activeSpeechPairId = 0;
    quint64 _nextSpeechPairId = 0;
    qint64 _lastGenericEnglishAt = -1;
    QVariantMap _speakingAlert;
    QVariantMap _pendingAlertPresentation;
    void _setSpeakingAlert(const QVariantMap &alert);
    static QVariantMap _alertPresentation(const SpeechItem &item);
    quint64 _speechGeneration = 0;
    void _startNextSpeech();
    bool _selectVoice(bool chinese);
    QString _englishRecording(const QString &text, bool fallback = true) const;
    void _finishRecordedAlert(bool failed);
    void _stopRecording();
    void _sayInstruction(const QString &text, bool firmware);
    void _stopInstructions(bool firmware);
    void _pruneExpiredVehicleAlerts(qint64 now);
    bool _makeRoomForVehicleAlert(qsizetype count);
    static qint64 _monotonicMilliseconds();

    /// Returns the current volume (0.0 - 100.0) from the settings Fact.
    double _volumeSetting() const;

    /// Returns the current muted state from the settings Fact.
    bool _mutedSetting() const;

    /// Sets the TTS engine volume from the current Fact value.
    void _setVolume();

    /// Applies engine-dependent settings (locale, cached capabilities) for the current engine.
    void _applyEngineSettings();

    /// Wires volume/mute Facts independently of system TTS availability.
    void _finishInit();

    static const QHash<QString, QString> _textHash;

    static constexpr qsizetype kMaxTextQueueSize = 20;
    static constexpr qint64 kVehicleAlertQueueLifetimeMs = 15000;
    // Keep simultaneous PreArm faults through the check window without replaying stale history.
    static constexpr qint64 kPrearmAlertQueueLifetimeMs = 45000;
    static constexpr qint64 kGenericEnglishCooldownMs = 15000;

    /// Grace period for async TTS backends (e.g. Android service binding) to reach Ready before warning.
    static constexpr std::chrono::seconds kEngineInitWarnTimeout{10};

    /// Fixes text messages for audio output.
    ///     @param string The text message to fix.
    ///     @return The fixed text message.
    static QString _fixTextMessageForAudio(const QString &string);

    /// Replaces predefined abbreviations with their corresponding full forms.
    ///     @param input The input string containing abbreviations.
    ///     @return A string with abbreviations replaced by their full forms.
    static QString _replaceAbbreviations(const QString &input);

    /// Replaces negative signs with the word "negative".
    static QString _replaceNegativeSigns(const QString &input);

    /// Replaces decimal points with the word "point".
    static QString _replaceDecimalPoints(const QString &input);

    /// Replaces "m" (meters) with the word "meters" following numbers.
    static QString _replaceMeters(const QString &input);

    /// Converts millisecond values to a more readable format (seconds and minutes).
    static QString _convertMilliseconds(const QString &input);

    /// Extracts a millisecond value from the given string.
    ///     @param string The string to extract from.
    ///     @param match The extracted millisecond string.
    ///     @param number The extracted number.
    ///     @return True if extraction is successful, false otherwise.
    static bool _getMillisecondString(const QString &string, QString &match, int &number);

};
Q_DECLARE_OPERATORS_FOR_FLAGS(AudioOutput::TextMods)
