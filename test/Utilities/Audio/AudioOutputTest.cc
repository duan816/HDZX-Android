#include "AudioOutputTest.h"

#include "AudioOutput.h"
#include "RecordedAlertPlayer.h"
#include "Fact.h"
#include <QtCore/QTimer>
#include <QtCore/QThread>
#ifdef Q_OS_WIN
#include <QtCore/QCoreApplication>
#include <QtCore/QDataStream>
#include <QtCore/QEvent>
#include <QtCore/QtEndian>
#endif
#include <QtTest/QSignalSpy>

#include <memory>

#ifdef Q_OS_WIN
namespace {
QByteArray pcmWave(bool ancillary = false)
{
    QByteArray chunks;
    auto chunk = [&chunks](const char *name, const QByteArray &bytes) {
        chunks.append(name, 4);
        const quint32 size = qToLittleEndian(quint32(bytes.size()));
        chunks.append(reinterpret_cast<const char *>(&size), 4);
        chunks.append(bytes);
        if (bytes.size() & 1) chunks.append(char(0));
    };
    QByteArray fmt;
    QDataStream stream(&fmt, QIODevice::WriteOnly);
    stream.setByteOrder(QDataStream::LittleEndian);
    stream << quint16(1) << quint16(1) << quint32(24000) << quint32(48000) << quint16(2) << quint16(16);
    if (ancillary) chunk("JUNK", QByteArray("odd"));
    chunk("fmt ", fmt);
    if (ancillary) chunk("LIST", QByteArray("metadata!"));
    chunk("data", QByteArray::fromHex("00000100ffff0020"));
    QByteArray wave("RIFF");
    const quint32 size = qToLittleEndian(quint32(chunks.size() + 4));
    wave.append(reinterpret_cast<const char *>(&size), 4);
    wave.append("WAVE");
    wave.append(chunks);
    return wave;
}
}

void AudioOutputTest::_testPcmWaveAncillaryChunksAndExactPayload()
{
    const auto decoded = RecordedAlertPlayer::_decodeWave(pcmWave(true));
    QVERIFY(decoded.has_value());
    QCOMPARE(decoded->format.sampleRate(), 24000);
    QCOMPARE(decoded->format.channelCount(), 1);
    QCOMPARE(decoded->format.sampleFormat(), QAudioFormat::Int16);
    QCOMPARE(decoded->samples, QByteArray::fromHex("00000100ffff0020"));
    QCOMPARE(decoded->format.framesForBytes(decoded->samples.size()), 4);
}

void AudioOutputTest::_testPcmWaveRejectsTruncationAndUnsupportedFormat()
{
    const auto valid = pcmWave();
    for (qsizetype size = 0; size < valid.size(); ++size)
        QVERIFY(!RecordedAlertPlayer::_decodeWave(valid.first(size)).has_value());
    for (const auto &change : {qMakePair(20, 3), qMakePair(22, 0), qMakePair(32, 3), qMakePair(34, 8)}) {
        auto malformed = valid;
        malformed[change.first] = char(change.second);
        QVERIFY(!RecordedAlertPlayer::_decodeWave(malformed).has_value());
    }
    auto badRate = valid;
    badRate[28] = char(0);
    QVERIFY(!RecordedAlertPlayer::_decodeWave(badRate).has_value());
    auto overflowingChunk = valid;
    overflowingChunk.replace(40, 4, QByteArray::fromHex("ffffffff"));
    QVERIFY(!RecordedAlertPlayer::_decodeWave(overflowingChunk).has_value());
}

void AudioOutputTest::_testPcmCacheBoundedAndRetainedAcrossVehicleReset()
{
    RecordedAlertPlayer player;
    auto clip = RecordedAlertPlayer::_decodeWave(pcmWave()).value();
    clip.samples = QByteArray(600 * 1024, '\0');
    for (int i = 0; i < 6; ++i) player._rememberPcm(QUrl(QStringLiteral("qrc:/clip%1.wav").arg(i)), clip);
    QVERIFY(player._pcmCacheBytes <= 2 * 1024 * 1024);
    QCOMPARE(player._pcmCache.size(), 3);
    QVERIFY(!player._pcmCache.contains(QUrl("qrc:/clip0.wav")));
    QVERIFY(player._pcmCache.contains(QUrl("qrc:/clip5.wav")));
    player.reset();
    QCOMPARE(player._pcmCache.size(), 3);
    QVERIFY(player._loadPcm(QUrl("qrc:/clip3.wav")).has_value());
    player._rememberPcm(QUrl("qrc:/new.wav"), clip);
    QVERIFY(player._pcmCache.contains(QUrl("qrc:/clip3.wav")));
    QVERIFY(!player._pcmCache.contains(QUrl("qrc:/clip4.wav")));
    clip.samples = QByteArray(2 * 1024 * 1024 + 2, '\0');
    player._rememberPcm(QUrl("qrc:/oversize.wav"), clip);
    QVERIFY(!player._pcmCache.contains(QUrl("qrc:/oversize.wav")));
    RecordedAlertPlayer small;
    clip.samples = QByteArray(8, '\0');
    for (int i = 0; i < 6; ++i) small._rememberPcm(QUrl(QStringLiteral("qrc:/small%1.wav").arg(i)), clip);
    QCOMPARE(small._pcmCache.size(), 4);
}

void AudioOutputTest::_testPcmQueuedCompletionCannotCompleteNewGeneration()
{
    RecordedAlertPlayer player;
    QSignalSpy completed(&player, &RecordedAlertPlayer::completed);
    player._generation = 41;
    player._started = true;
    player._sinkStateChanged(QtAudio::StoppedState);
    QCOMPARE(completed.count(), 0); // Completion never re-enters an audio setter.
    player.reset();
    player._generation = 41; // Device recovery can replay with the same public generation.
    player._started = true;
    QCoreApplication::sendPostedEvents(&player, QEvent::MetaCall);
    QCOMPARE(player._generation, quint64(41));
    QCOMPARE(completed.count(), 0);
    player._sinkStateChanged(QtAudio::StoppedState);
    QTRY_COMPARE(completed.count(), 1);
    QCOMPARE(completed.first().first().toULongLong(), quint64(41));
    QVERIFY(completed.first().at(1).toBool());
    QCOMPARE(player._generation, quint64(0));
}
#endif

void AudioOutputTest::_testSpeakingWarningFollowsPlaybackNotReceipt()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    const QString battery = QStringLiteral("PreArm: Battery 1 unhealthy");
    const QString radio = QStringLiteral("PreArm: RC not found");
    output.sayVehicleAlert(battery, QStringLiteral("电池监测器数据异常。"), true, 201);
    output.sayVehicleAlert(radio, QStringLiteral("未检测到遥控器输入。"), true, 201);
    QVERIFY(output.speakingAlert().isEmpty());
    auto start = [&output](quint64 generation) {
        const auto item = output._speechQueue.dequeue();
        output._clipPending = true;
        output._clipGeneration = generation;
        output._clipAlertKey = item.alertKey;
        output._activeSpeechPairId = item.pairId;
        output._pendingAlertPresentation = output._alertPresentation(item);
        emit output._alertPlayer->started(generation - 1);
        emit output._alertPlayer->started(generation);
    };
    start(11);
    QCOMPARE(output.speakingAlert().value("text").toString(), battery);
    QCOMPARE(output.speakingAlert().value("vehicleId").toInt(), 201);
    emit output._alertPlayer->completed(11, false);
    QCOMPARE(output.speakingAlert().value("text").toString(), battery); // Paired Chinese has not started yet.
    start(21);
    QCOMPARE(output.speakingAlert().value("text").toString(), battery);
    QCOMPARE(output.speakingAlert().value("translation").toString(), QStringLiteral("电池监测器数据异常。"));
    emit output._alertPlayer->completed(21, false);
    QVERIFY(output.speakingAlert().isEmpty()); // RC is only queued, not audible yet.
    start(31);
    QCOMPARE(output.speakingAlert().value("text").toString(), radio);
    output.clearVehicleAlert(radio);
    QVERIFY(output.speakingAlert().isEmpty());
}

void AudioOutputTest::_testSpeakingWarningClearsForResetMuteAndNonAlert()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    const QVariantMap warning{{"text", QStringLiteral("RC not found")}, {"vehicleId", 201}};
    output._setSpeakingAlert(warning);
    output.resetForVehicleChange();
    QVERIFY(output.speakingAlert().isEmpty());
    output._setSpeakingAlert(warning);
    output._clipPending = true; output._clipGeneration = 17;
    output._pendingAlertPresentation.clear();
    emit output._alertPlayer->started(17); // Setup/ordinary speech does not inherit a vehicle fault.
    QVERIFY(output.speakingAlert().isEmpty());
    output._clipPending = false;
    output._setSpeakingAlert(warning);
    muted.setRawValue(true);
    output._speechStarting = false;
    output._startNextSpeech();
    QVERIFY(output.speakingAlert().isEmpty());
}

void AudioOutputTest::_testVehicleChangeClearsStalledClip()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(80); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output._clipPending = true; output._clipStarted = true; output._clipGeneration = 9;
    output.sayBilingual(QStringLiteral("Old vehicle warning"), QStringLiteral("旧提示"));
    output.resetForVehicleChange();
    QVERIFY(!output._clipPending);
    QVERIFY(!output._clipStarted);
    QVERIFY(output._clipGeneration > 9);
    QVERIFY(output._speechQueue.isEmpty());
    output.sayBilingual(QStringLiteral("New vehicle warning"), QStringLiteral("新提示"));
    QCOMPARE(output._speechQueue.size(), 2);
}

void AudioOutputTest::_testStalePlaybackCompletionIgnored()
{
    AudioOutput output;
    output._speechStarting = true;
    output._clipPending = true; output._clipStarted = true; output._clipGeneration = 9;
    QSignalSpy finished(&output, &AudioOutput::recordingFinished);
    emit output._alertPlayer->completed(8, false);
    QVERIFY(output._clipPending);
    QCOMPARE(finished.count(), 0);
    emit output._alertPlayer->completed(9, true);
    QVERIFY(!output._clipPending);
    QCOMPARE(finished.count(), 1);
}

void AudioOutputTest::_testModeAnnouncementWithoutSystemTts()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speakCapable = false; output._speechStarting = true;
    output.sayFlightMode(QStringLiteral("Stabilize"));
    QTRY_COMPARE(output._speechQueue.size(), 1);
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("Stabilize，自稳模式。"));
    QVERIFY(output._speechQueue.front().modeAnnouncement);
    output.sayFlightMode(QStringLiteral("Loiter"));
    QTRY_COMPARE(output._speechQueue.front().text, QStringLiteral("Loiter，定点模式。"));
    QCOMPARE(output._speechQueue.size(), 1);
    QVERIFY(output._recordedAlerts.contains(output._speechQueue.front().text));
    QVERIFY(output._speechQueue.front().alertKey.isEmpty());
    output.sayFlightMode(QStringLiteral("Altitude Hold"));
    QTRY_COMPARE(output._speechQueue.front().text, QStringLiteral("AltHold，定高模式。"));
    QVERIFY(output._recordedAlerts.contains(output._speechQueue.front().text));
    output._speechQueue.clear();
    muted.setRawValue(true);
    output.sayFlightMode(QStringLiteral("RTL"));
    QVERIFY(output._speechQueue.isEmpty());
}

void AudioOutputTest::_testNavigationAnnouncementsUseRecordingsAndCoalesce()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speakCapable = false; output._speechStarting = true;
    output.sayNavigation(QStringLiteral("RTK固定解。"), QStringLiteral("rtk"));
    QTRY_COMPARE(output._speechQueue.size(), 1);
    output.sayNavigation(QStringLiteral("RTK固定解丢失。"), QStringLiteral("rtk"));
    QTRY_COMPARE(output._speechQueue.front().text, QStringLiteral("RTK固定解丢失。"));
    QCOMPARE(output._speechQueue.size(), 1);
    output.sayNavigation(QStringLiteral("返航点已刷新，请留意返航位置。"), QStringLiteral("home"));
    QTRY_COMPARE(output._speechQueue.size(), 2);
    for (const auto &item : output._speechQueue) {
        QVERIFY(item.chinese && item.useRecording);
        QVERIFY(output._recordedAlerts.contains(item.text));
        QVERIFY(item.expiresAt > 0);
    }
    output.resetForVehicleChange();
    QVERIFY(output._speechQueue.isEmpty());
}

void AudioOutputTest::_testFirmwarePromptSurvivesDisconnect()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(80); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayFirmwareInstruction();
    QCOMPARE(output._speechQueue.size(), 1);
    QVERIFY(output._speechQueue.front().firmware);
    output._clipPending = true; output._clipStarted = true;
    output._clipFirmware = true; output._clipGeneration = 9;
    output.resetForVehicleChange();
    QVERIFY(output._clipPending);
    QCOMPARE(output._clipGeneration, quint64(9));
    QCOMPARE(output._speechQueue.size(), 1);
    output.stopFirmwareInstructions();
    QVERIFY(!output._clipPending);
    QVERIFY(output._speechQueue.isEmpty());
}

void AudioOutputTest::_testPlaybackWatchdogReleasesQueue()
{
    RecordedAlertPlayer player;
    QSignalSpy completed(&player, &RecordedAlertPlayer::completed);
    player._generation = 71;
    player._started = true; // Simulate an output device disappearing without a completion signal.
    QVERIFY(QMetaObject::invokeMethod(player._deadline, "timeout", Qt::DirectConnection));
    QCOMPARE(completed.count(), 1);
    QCOMPARE(completed.first().first().toULongLong(), quint64(71));
    QVERIFY(completed.first().at(1).toBool());
    QCOMPARE(player._generation, quint64(0));
}

void AudioOutputTest::_testBilingualQueue()
{
    AudioOutput output;
    Fact volume;
    Fact muted;
    volume.setRawValue(80);
    muted.setRawValue(false);
    output._volumeFact = &volume;
    output._mutedFact = &muted;
    output._initialized = true;
    output._speakCapable = false; // Chinese recordings still queue when system TTS is unavailable.
    // The test's none backend cannot speak; inspect ordering without using an audio device.
    output._speechStarting = true;
    output.sayBilingual(QStringLiteral("PreArm: Hardware safety switch"), QStringLiteral("硬件安全开关未触发"));
    QCOMPARE(output._speechQueue.size(), 2);
    QCOMPARE(output._speechQueue.at(0).chinese, false);
    QVERIFY(output._speechQueue.at(0).bundledEnglish);
    QCOMPARE(output._speechQueue.at(1).chinese, true);
    QCOMPARE(output._speechQueue.at(1).text, QStringLiteral("硬件安全开关未触发"));
    muted.setRawValue(true);
    output.sayBilingual(QStringLiteral("Compass inconsistent"), QStringLiteral("罗盘不一致"));
    QCOMPARE(output._speechQueue.size(), 2);
}

void AudioOutputTest::_testCalibrationQueueReplacement()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(80); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayBilingual(QStringLiteral("Warning"), QStringLiteral("警告"));
    output.sayCalibrationInstruction(QStringLiteral("飞控向左。"));
    output.sayCalibrationInstruction(QStringLiteral("飞控向右。"));
    QCOMPARE(output._speechQueue.size(), 3);
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("飞控向右。"));
    QVERIFY(output._speechQueue.front().calibration);
    output.stopCalibrationInstructions();
    QCOMPARE(output._speechQueue.size(), 2);
    QVERIFY(!output._speechQueue.front().calibration);
}

void AudioOutputTest::_testRecordedSpeechWithoutTts()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(80); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true; output._speakCapable = false;
    QVERIFY(!output._recordedAlerts.isEmpty());
    const QString text = output._recordedAlerts.constBegin().key();
    output.say(text);
    QCOMPARE(output._speechQueue.size(), 1);
    QCOMPARE(output._speechQueue.front().text, text);
    output.say(QStringLiteral("Compass inconsistent"));
    QCOMPARE(output._speechQueue.size(), 2);
    QVERIFY(output._speechQueue.back().bundledEnglish);
}

void AudioOutputTest::_testEnglishReferenceMapping()
{
    AudioOutput output;
    if (!output._recordedEnglishAlerts.contains(QStringLiteral("__fallback__"))) QSKIP("English voice bundle not installed");
    QVERIFY(!output._englishRecording(QStringLiteral("PreArm: Battery 2 unhealthy")).isEmpty());
    QCOMPARE(output._englishRecording(QStringLiteral("unrecognised firmware alert 4921")),
        output._recordedEnglishAlerts.value(QStringLiteral("__fallback__")));
    const auto direct = output._recordedEnglishAlerts.value(QStringLiteral("battery {1} unhealthy"));
    if (!direct.isEmpty()) QCOMPARE(output._englishRecording(QStringLiteral("PreArm: Battery 2 unhealthy")), direct);
}

void AudioOutputTest::_testVehicleAlertQueueDeduplicates()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("PreArm: Battery 1 unhealthy"), QStringLiteral("电池异常"), true);
    const QString key = output._speechQueue.front().alertKey;
    output._speechQueue.front().expiresAt = AudioOutput::_monotonicMilliseconds() + 100;
    output.sayVehicleAlert(QStringLiteral("PreArm: Battery 1 unhealthy."), QStringLiteral("电池异常"), true);
    QCOMPARE(output._speechQueue.size(), 2);
    QCOMPARE(output._speechQueue.front().alertKey, key);
    QCOMPARE(output._speechQueue.back().alertKey, key);
    QCOMPARE(output._speechQueue.front().expiresAt, output._speechQueue.back().expiresAt);
    QVERIFY(output._speechQueue.front().expiresAt > AudioOutput::_monotonicMilliseconds() + 10000);
    QVERIFY(output._speechQueue.front().bundledEnglish);
    QVERIFY(output._speechQueue.back().chinese);
    // The same text occurring as an in-flight fault is not cleared with prearm checks.
    output.sayVehicleAlert(QStringLiteral("Battery 1 unhealthy"), QStringLiteral("电池异常"));
    QCOMPARE(output._speechQueue.size(), 4);
    QVERIFY(output._speechQueue.back().alertKey != key);
}

void AudioOutputTest::_testVehicleAlertAlreadySpeakingDeduplicates()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("PreArm: RC not found"), QStringLiteral("未检测到遥控器"), true);
    const auto english = output._speechQueue.dequeue();
    output._clipPending = true;
    output._clipAlertKey = english.alertKey;
    output._clipAlertPrearm = true;
    output._activeAlertKey = english.alertKey;
    output.sayVehicleAlert(QStringLiteral("PreArm: RC not found"), QStringLiteral("未检测到遥控器"), true);
    QCOMPARE(output._speechQueue.size(), 1);
    QVERIFY(output._speechQueue.front().chinese);
    output.clearVehicleAlerts();
    QVERIFY(!output._clipPending);
    QVERIFY(output._speechQueue.isEmpty());
}

void AudioOutputTest::_testVehicleAlertRetainsLatestWhenFull()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayFirmwareInstruction();
    output.sayCalibrationInstruction(QStringLiteral("飞控向左。"));
    for (int i = 0; i < 9; ++i) {
        output.sayVehicleAlert(QStringLiteral("Fault %1").arg(i), QStringLiteral("故障%1").arg(i));
    }
    QCOMPARE(output._speechQueue.size(), AudioOutput::kMaxTextQueueSize);
    output.sayVehicleAlert(QStringLiteral("Newest fault"), QStringLiteral("最新故障"));
    QCOMPARE(output._speechQueue.size(), AudioOutput::kMaxTextQueueSize);
    QVERIFY(output._speechQueue.at(0).calibration);
    QVERIFY(output._speechQueue.at(1).firmware);
    QCOMPARE(output._speechQueue.back().text, QStringLiteral("最新故障"));
    QHash<QString, int> counts;
    for (const auto& item : output._speechQueue) {
        if (!item.alertKey.isEmpty()) ++counts[item.alertKey];
        QVERIFY(item.text != QStringLiteral("Fault 0"));
        QVERIFY(item.text != QStringLiteral("故障0"));
    }
    for (int count : counts) QCOMPARE(count, 2);

    output.clearVehicleAlerts();
    output.stopCalibrationInstructions();
    output.stopFirmwareInstructions();
    for (int i = 0; i < 10; ++i) output.sayBilingual(QStringLiteral("Ordinary notice"), QStringLiteral("普通提示"));
    QCOMPARE(output._speechQueue.size(), AudioOutput::kMaxTextQueueSize);
    output.sayVehicleAlert(QStringLiteral("New fault"), QStringLiteral("新故障"));
    QCOMPARE(output._speechQueue.size(), AudioOutput::kMaxTextQueueSize);
    QCOMPARE(output._speechQueue.at(0).text, QStringLiteral("New fault"));
    QCOMPARE(output._speechQueue.at(1).text, QStringLiteral("新故障"));
}

void AudioOutputTest::_testVehicleAlertPrecedesOrdinaryAnnouncements()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayBilingual(QStringLiteral("Ordinary notice"), QStringLiteral("普通提示"));
    output.sayCalibrationInstruction(QStringLiteral("飞控向左。"));
    output.sayVehicleAlert(QStringLiteral("First fault"), QStringLiteral("首个故障"));
    output.sayVehicleAlert(QStringLiteral("Second fault"), QStringLiteral("第二个故障"));
    QVERIFY(output._speechQueue.at(0).calibration);
    QCOMPARE(output._speechQueue.at(1).text, QStringLiteral("First fault"));
    QCOMPARE(output._speechQueue.at(2).text, QStringLiteral("首个故障"));
    QCOMPARE(output._speechQueue.at(3).text, QStringLiteral("Second fault"));
    QCOMPARE(output._speechQueue.at(4).text, QStringLiteral("第二个故障"));
    QCOMPARE(output._speechQueue.at(5).text, QStringLiteral("Ordinary notice"));
}

void AudioOutputTest::_testVehicleAlertExpiresBeforePlayback()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("Expired fault"), QStringLiteral("过期故障"));
    for (auto& item : output._speechQueue) item.expiresAt = 1;
    output._speechStarting = false;
    output._startNextSpeech();
    QVERIFY(output._speechQueue.isEmpty());
    QVERIFY(!output._clipPending);
    QVERIFY(!output._speechPending);
    output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("New fault"), QStringLiteral("新故障"));
    for (auto& item : output._speechQueue) item.expiresAt = 1;
    output.sayVehicleAlert(QStringLiteral("Newest fault"), QStringLiteral("最新故障"));
    QCOMPARE(output._speechQueue.size(), 2);
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("Newest fault"));
}

void AudioOutputTest::_testStartedVehicleAlertRetainsTranslatedHalf()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("First fault"), QStringLiteral("首个故障"));
    output._activeAlertKey = output._speechQueue.dequeue().alertKey;
    output._speechQueue.front().expiresAt = 1;
    for (int i = 0; i < 12; ++i) {
        output.sayVehicleAlert(QStringLiteral("Other fault %1").arg(i), QStringLiteral("其他故障%1").arg(i));
    }
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("首个故障"));
    output.sayCalibrationInstruction(QStringLiteral("飞控向右。"));
    QCOMPARE(output._speechQueue.at(0).text, QStringLiteral("首个故障"));
    QVERIFY(output._speechQueue.at(1).calibration);
}

void AudioOutputTest::_testClearPrearmPreservesFaultsAndInstructions()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("PreArm: RC not found"), QStringLiteral("遥控器异常"), true);
    output.sayVehicleAlert(QStringLiteral("EKF fault"), QStringLiteral("估计器故障"));
    output.sayCalibrationInstruction(QStringLiteral("飞控向左。"));
    output.sayFirmwareInstruction();
    output.sayBilingual(QStringLiteral("Ordinary notice"), QStringLiteral("普通提示"));
    output.clearVehicleAlerts(true);
    QCOMPARE(output._speechQueue.size(), 6);
    for (const auto& item : output._speechQueue) QVERIFY(!item.alertPrearm);
    output.clearVehicleAlerts();
    QCOMPARE(output._speechQueue.size(), 4);
    QVERIFY(output._speechQueue.at(0).firmware);
    QVERIFY(output._speechQueue.at(1).calibration);
    QCOMPARE(output._speechQueue.at(2).text, QStringLiteral("Ordinary notice"));
}

void AudioOutputTest::_testClearVehicleAlertsStopsMatchingClip()
{
    AudioOutput output;
    output._speechStarting = true;
    output._clipPending = true; output._clipGeneration = 12;
    output._clipAlertKey = QStringLiteral("alert:EKF fault"); output._activeAlertKey = output._clipAlertKey;
    output.clearVehicleAlerts(true);
    QVERIFY(output._clipPending);
    QCOMPARE(output._clipGeneration, quint64(12));
    output.clearVehicleAlerts();
    QVERIFY(!output._clipPending);
    QVERIFY(output._clipGeneration > 12);
    QVERIFY(output._activeAlertKey.isEmpty());
    output._clipPending = true; output._clipFirmware = true;
    output.clearVehicleAlerts();
    QVERIFY(output._clipPending);
    output._stopRecording();
}

void AudioOutputTest::_testVehicleAlertQuietThenNewAlert()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("RC not found"), QStringLiteral("遥控器异常"), true);
    output.clearVehicleAlerts();
    output._speechStarting = false;
    output._startNextSpeech();
    output._startNextSpeech();
    QVERIFY(output._speechQueue.isEmpty());
    QVERIFY(!output._clipPending);
    output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("RC not found"), QStringLiteral("遥控器异常"), true);
    QCOMPARE(output._speechQueue.size(), 2);
    muted.setRawValue(true);
    output.sayVehicleAlert(QStringLiteral("Muted fault"), QStringLiteral("静音故障"));
    QCOMPARE(output._speechQueue.size(), 2);
}

void AudioOutputTest::_testVehicleAlertReconnectAcceptsSameAlert()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("PreArm: RC not found"), QStringLiteral("遥控器异常"), true);
    output._activeAlertKey = output._speechQueue.dequeue().alertKey;
    output._clipAlertKey = output._activeAlertKey;
    output._clipPending = true;
    output.sayFirmwareInstruction();
    output.resetForVehicleChange();
    QVERIFY(!output._clipPending);
    QVERIFY(output._activeAlertKey.isEmpty());
    QCOMPARE(output._speechQueue.size(), 1);
    QVERIFY(output._speechQueue.front().firmware);
    output.sayVehicleAlert(QStringLiteral("PreArm: RC not found"), QStringLiteral("遥控器异常"), true);
    QCOMPARE(output._speechQueue.size(), 3);
}

void AudioOutputTest::_testResolvedVehicleAlertPreservesOtherQueues()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayCalibrationInstruction(QStringLiteral("飞控向左。"));
    output.sayFirmwareInstruction();
    output.sayVehicleAlert(QStringLiteral("Fault A"), QStringLiteral("故障甲"), true);
    output.sayVehicleAlert(QStringLiteral("PreArm: Fault B"), QStringLiteral("故障乙"), true);
    output.sayVehicleAlert(QStringLiteral("Fault B"), QStringLiteral("故障乙"));
    output.sayVehicleAlert(QStringLiteral("Fault C"), QStringLiteral("故障丙"));
    output.sayBilingual(QStringLiteral("Ordinary notice"), QStringLiteral("普通提示"));
    QCOMPARE(output._speechQueue.size(), 12);
    output.clearVehicleAlert(QStringLiteral("PreArm: FAULT B."));
    QCOMPARE(output._speechQueue.size(), 8);
    QVERIFY(output._speechQueue.at(0).firmware);
    QVERIFY(output._speechQueue.at(1).calibration);
    QCOMPARE(output._speechQueue.at(2).text, QStringLiteral("Fault A"));
    QCOMPARE(output._speechQueue.at(3).text, QStringLiteral("故障甲"));
    QCOMPARE(output._speechQueue.at(4).text, QStringLiteral("Fault C"));
    QCOMPARE(output._speechQueue.at(5).text, QStringLiteral("故障丙"));
    QCOMPARE(output._speechQueue.at(6).text, QStringLiteral("Ordinary notice"));
    output.clearVehicleAlert(QStringLiteral("  "));
    QCOMPARE(output._speechQueue.size(), 8);
    output.clearVehicleAlert(QStringLiteral("Fault B"));
    QCOMPARE(output._speechQueue.size(), 8);
}

void AudioOutputTest::_testResolvedVehicleAlertStopsMatchingClip()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("Fault B"), QStringLiteral("故障乙"), true);
    const auto english = output._speechQueue.dequeue();
    output._activeAlertKey = english.alertKey;
    output._activeSpeechPairId = english.pairId;
    output._clipAlertKey = output._activeAlertKey;
    output._clipPending = true; output._clipStarted = true; output._clipGeneration = 84;
    output.sayVehicleAlert(QStringLiteral("Fault A"), QStringLiteral("故障甲"), true);
    output.sayVehicleAlert(QStringLiteral("Fault C"), QStringLiteral("故障丙"));
    output.clearVehicleAlert(QStringLiteral("Fault B"));
    QVERIFY(!output._clipPending);
    QVERIFY(!output._clipStarted);
    QVERIFY(output._clipGeneration > 84);
    QVERIFY(output._activeAlertKey.isEmpty());
    QCOMPARE(output._activeSpeechPairId, quint64(0));
    QCOMPARE(output._speechQueue.size(), 4);
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("Fault A"));
    QCOMPARE(output._speechQueue.back().text, QStringLiteral("故障丙"));
    // A late completion from the stopped clip must not change remaining work.
    QSignalSpy finished(&output, &AudioOutput::recordingFinished);
    emit output._alertPlayer->completed(84, false);
    QCOMPARE(finished.count(), 0);
    QCOMPARE(output._speechQueue.size(), 4);
}

void AudioOutputTest::_testResolvedVehicleAlertPreservesOtherClip()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("Fault A"), QStringLiteral("故障甲"));
    const auto english = output._speechQueue.dequeue();
    output._activeAlertKey = english.alertKey;
    output._activeSpeechPairId = english.pairId;
    output._clipAlertKey = output._activeAlertKey;
    output._clipPending = true; output._clipGeneration = 44;
    output.sayVehicleAlert(QStringLiteral("Fault B"), QStringLiteral("故障乙"));
    output.clearVehicleAlert(QStringLiteral("Fault B"));
    QVERIFY(output._clipPending);
    QCOMPARE(output._clipGeneration, quint64(44));
    QCOMPARE(output._activeAlertKey, output._clipAlertKey);
    QCOMPARE(output._activeSpeechPairId, english.pairId);
    QCOMPARE(output._speechQueue.size(), 1);
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("故障甲"));
    output._stopRecording();
    output._clipPending = true; output._clipFirmware = true;
    output.clearVehicleAlert(QStringLiteral("Fault A"));
    QVERIFY(output._clipPending);
    output._stopRecording();
}

void AudioOutputTest::_testResolvedVehicleAlertFromOtherThread()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("Fault A"), QStringLiteral("故障甲"));
    output.sayVehicleAlert(QStringLiteral("Fault B"), QStringLiteral("故障乙"));
    bool foreignThread = false;
    std::unique_ptr<QThread> caller(QThread::create([&output, &foreignThread]() {
        foreignThread = QThread::currentThread() != output.thread();
        output.clearVehicleAlert(QStringLiteral("Fault B"));
    }));
    caller->start();
    QVERIFY(caller->wait(2000));
    QVERIFY(foreignThread);
    // No event processing yet: mutation is still queued to AudioOutput's owning thread.
    QCOMPARE(output._speechQueue.size(), 4);
    QTRY_COMPARE_WITH_TIMEOUT(output._speechQueue.size(), 2, 2000);
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("Fault A"));
    QCOMPARE(output._speechQueue.back().text, QStringLiteral("故障甲"));
}

void AudioOutputTest::_testSpecificFaultPrecedesGenericFallback()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayVehicleAlert(QStringLiteral("Uncatalogued EKF reset one"), QString());
    QVERIFY(output._speechQueue.front().genericFallback);
    output.sayVehicleAlert(QStringLiteral("PreArm: RC not found"), QStringLiteral("未检测到遥控器输入。"), true);
    output.sayVehicleAlert(QStringLiteral("PreArm: Battery 1 unhealthy"), QStringLiteral("电池监测器数据异常。"), true);
    output.sayCalibrationInstruction(QStringLiteral("飞控向左。"));
    output.sayFirmwareInstruction();
    QCOMPARE(output._speechQueue.size(), 7);
    QVERIFY(output._speechQueue.at(0).firmware);
    QVERIFY(output._speechQueue.at(1).calibration);
    QCOMPARE(output._speechQueue.at(2).text, QStringLiteral("PreArm: RC not found"));
    QCOMPARE(output._speechQueue.at(3).text, QStringLiteral("未检测到遥控器输入。"));
    QCOMPARE(output._speechQueue.at(4).text, QStringLiteral("PreArm: Battery 1 unhealthy"));
    QVERIFY(output._speechQueue.back().genericFallback);
}

void AudioOutputTest::_testGenericNoticeBurstCoalesces()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayBilingual(QStringLiteral("Uncatalogued EKF reset one"), QString());
    output.sayBilingual(QStringLiteral("Uncatalogued EKF reset two"), QString());
    QCOMPARE(output._speechQueue.size(), 1);
    output._speechQueue.clear();
    output._lastGenericEnglishAt = AudioOutput::_monotonicMilliseconds();
    output.sayBilingual(QStringLiteral("Uncatalogued EKF reset three"), QString());
    QVERIFY(output._speechQueue.isEmpty());
    output._lastGenericEnglishAt -= AudioOutput::kGenericEnglishCooldownMs;
    output.sayBilingual(QStringLiteral("Uncatalogued EKF reset four"), QString());
    QCOMPARE(output._speechQueue.size(), 1);
    output.resetForVehicleChange();
    QCOMPARE(output._lastGenericEnglishAt, qint64(-1));
    output.sayBilingual(QStringLiteral("Uncatalogued new vehicle notice"), QString());
    QCOMPARE(output._speechQueue.size(), 1);
}

void AudioOutputTest::_testGenericCooldownRetainsFaultTranslations()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output._lastGenericEnglishAt = AudioOutput::_monotonicMilliseconds();
    output.sayVehicleAlert(QStringLiteral("Uncatalogued concrete fault one"), QStringLiteral("故障甲"), true);
    output.sayVehicleAlert(QStringLiteral("Uncatalogued concrete fault two"), QStringLiteral("故障乙"), true);
    QCOMPARE(output._speechQueue.size(), 4);
    QCOMPARE(output._speechQueue.at(1).text, QStringLiteral("故障甲"));
    QCOMPARE(output._speechQueue.at(3).text, QStringLiteral("故障乙"));
    QCOMPARE(output._speechQueue.at(0).pairId, output._speechQueue.at(1).pairId);
    QVERIFY(output._speechQueue.at(0).pairId != output._speechQueue.at(2).pairId);
    QVERIFY(!output._speechQueue.at(0).genericFallback);
    // Exercise fallback suppression without an audio device; translations remain queued separately above.
    output._speechQueue.clear();
    output.sayVehicleAlert(QStringLiteral("Uncatalogued generic fault one"), QString());
    output.sayVehicleAlert(QStringLiteral("Uncatalogued generic fault two"), QString());
    QCOMPARE(output._speechQueue.size(), 2);
    output._speechStarting = false;
    output._startNextSpeech();
    QVERIFY(output._speechQueue.isEmpty());
    QVERIFY(!output._clipPending);
    QVERIFY(!output._speechPending);
}

void AudioOutputTest::_testPrearmAlertLifetimeMatchesCheckCycle()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    const qint64 now = AudioOutput::_monotonicMilliseconds();
    output.sayVehicleAlert(QStringLiteral("PreArm: RC not found"), QStringLiteral("遥控器异常"), true);
    output.sayVehicleAlert(QStringLiteral("PreArm: Battery 1 unhealthy"), QStringLiteral("电池异常"), true);
    output.sayVehicleAlert(QStringLiteral("PreArm: Hardware safety switch"), QStringLiteral("安全开关未解除"), true);
    output.sayVehicleAlert(QStringLiteral("Transient fault"), QStringLiteral("即时异常"));
    QCOMPARE(output._speechQueue.size(), 8);
    output._pruneExpiredVehicleAlerts(now + 16000);
    QCOMPARE(output._speechQueue.size(), 6);
    for (const auto& item : output._speechQueue) QVERIFY(item.alertPrearm);
    output._pruneExpiredVehicleAlerts(now + 44000);
    QCOMPARE(output._speechQueue.size(), 6);
    output._pruneExpiredVehicleAlerts(now + 46000);
    QVERIFY(output._speechQueue.isEmpty());
}

void AudioOutputTest::_testOrdinaryPairSurvivesPriorityChanges()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayBilingual(QStringLiteral("Compass inconsistent"), QStringLiteral("罗盘不一致"));
    output._activeSpeechPairId = output._speechQueue.dequeue().pairId;
    QVERIFY(output._activeSpeechPairId != 0);
    output._speechQueue.front().expiresAt = 1;
    output.sayVehicleAlert(QStringLiteral("PreArm: RC not found"), QStringLiteral("遥控器异常"), true);
    output.sayCalibrationInstruction(QStringLiteral("飞控向左。"));
    output.sayFirmwareInstruction();
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("罗盘不一致"));
    QVERIFY(output._speechQueue.at(1).firmware);
    QVERIFY(output._speechQueue.at(2).calibration);
    output.clearVehicleAlerts(true);
    output.clearVehicleAlert(QStringLiteral("Unrelated fault"));
    output._pruneExpiredVehicleAlerts(AudioOutput::_monotonicMilliseconds());
    QCOMPARE(output._speechQueue.size(), 3);
    QCOMPARE(output._speechQueue.front().pairId, output._activeSpeechPairId);
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("罗盘不一致"));
}

void AudioOutputTest::_testQueueEvictsFallbackBeforeConcreteFaults()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    for (int i = 0; i < 8; ++i) {
        output.sayVehicleAlert(QStringLiteral("Concrete fault %1").arg(i), QStringLiteral("具体故障%1").arg(i));
    }
    output.sayBilingual(QStringLiteral("Uncatalogued generic notice"), QString());
    output.sayBilingual(QStringLiteral("Compass inconsistent"), QStringLiteral("罗盘不一致"));
    QCOMPARE(output._speechQueue.size(), 19);
    output.sayVehicleAlert(QStringLiteral("Additional concrete fault"), QStringLiteral("新增故障"));
    QCOMPARE(output._speechQueue.size(), 20);
    for (const auto& item : output._speechQueue) QVERIFY(!item.genericFallback);
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("Concrete fault 0"));
    output.sayVehicleAlert(QStringLiteral("Latest concrete fault"), QStringLiteral("最新故障"));
    QCOMPARE(output._speechQueue.size(), 20);
    QHash<quint64, int> counts;
    for (const auto& item : output._speechQueue) {
        QVERIFY(!item.alertKey.isEmpty());
        ++counts[item.pairId];
        QVERIFY(item.text != QStringLiteral("罗盘不一致"));
    }
    for (int count : counts) QCOMPARE(count, 2);
    QCOMPARE(output._speechQueue.front().text, QStringLiteral("Concrete fault 0"));
}

void AudioOutputTest::_testOrdinaryNoticeExpires()
{
    AudioOutput output;
    Fact volume, muted;
    volume.setRawValue(100); muted.setRawValue(false);
    output._volumeFact = &volume; output._mutedFact = &muted;
    output._initialized = true; output._speechStarting = true;
    output.sayCalibrationInstruction(QStringLiteral("飞控向左。"));
    output.sayBilingual(QStringLiteral("Compass inconsistent"), QStringLiteral("罗盘不一致"));
    output._pruneExpiredVehicleAlerts(AudioOutput::_monotonicMilliseconds() + 16000);
    QCOMPARE(output._speechQueue.size(), 1);
    QVERIFY(output._speechQueue.front().calibration);
}

void AudioOutputTest::_testSpokenReplacements()
{
    QString result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("-10.5m, -10.5m. -10.5 m"));
    QCOMPARE(result,
             QStringLiteral("negative 10 point 5 meters, negative 10 point 5 meters. negative 10 point 5  meters"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("-10m -10 m"));
    QCOMPARE(result, QStringLiteral("negative 10 meters negative 10  meters"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("foo -10m -10 m bar"));
    QCOMPARE(result, QStringLiteral("foo negative 10 meters negative 10  meters bar"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("-foom"));
    QCOMPARE(result, QStringLiteral("-foom"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("10 moo"));
    QCOMPARE(result, QStringLiteral("10 moo"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("10moo"));
    QCOMPARE(result, QStringLiteral("10moo"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("10ms"));
    QCOMPARE(result, QStringLiteral("10ms"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("1000ms"));
    QCOMPARE(result, QStringLiteral("1 second"));
    result = AudioOutput::_fixTextMessageForAudio(QStringLiteral("1001ms"));
    QCOMPARE(result, QStringLiteral("1 second and 1 millisecond"));
}

#include "UnitTest.h"

UT_REGISTER_TEST(AudioOutputTest, TestLabel::Unit, TestLabel::Utilities)
