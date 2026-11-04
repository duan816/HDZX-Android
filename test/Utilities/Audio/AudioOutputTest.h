#pragma once

#include "UnitTest.h"

class AudioOutputTest : public UnitTest
{
    Q_OBJECT

private slots:
#ifdef Q_OS_WIN
    void _testPcmWaveAncillaryChunksAndExactPayload();
    void _testPcmWaveRejectsTruncationAndUnsupportedFormat();
    void _testPcmCacheBoundedAndRetainedAcrossVehicleReset();
    void _testPcmQueuedCompletionCannotCompleteNewGeneration();
#endif
    void _testModeAnnouncementWithoutSystemTts();
    void _testNavigationAnnouncementsUseRecordingsAndCoalesce();
    void _testArmingAnnouncementsUseBundledMaleClips();
    void _testSpeakingWarningFollowsPlaybackNotReceipt();
    void _testSpeakingWarningClearsForResetMuteAndNonAlert();
    void _testVehicleChangeClearsStalledClip();
    void _testStalePlaybackCompletionIgnored();
    void _testFirmwarePromptSurvivesDisconnect();
    void _testPlaybackWatchdogReleasesQueue();
    void _testSpokenReplacements();
    void _testBilingualQueue();
    void _testCalibrationQueueReplacement();
    void _testRecordedSpeechWithoutTts();
    void _testEnglishReferenceMapping();
    void _testVehicleAlertQueueDeduplicates();
    void _testVehicleAlertAlreadySpeakingDeduplicates();
    void _testVehicleAlertRetainsLatestWhenFull();
    void _testVehicleAlertPrecedesOrdinaryAnnouncements();
    void _testVehicleAlertExpiresBeforePlayback();
    void _testStartedVehicleAlertRetainsTranslatedHalf();
    void _testClearPrearmPreservesFaultsAndInstructions();
    void _testClearVehicleAlertsStopsMatchingClip();
    void _testVehicleAlertQuietThenNewAlert();
    void _testVehicleAlertReconnectAcceptsSameAlert();
    void _testResolvedVehicleAlertPreservesOtherQueues();
    void _testResolvedVehicleAlertStopsMatchingClip();
    void _testResolvedVehicleAlertPreservesOtherClip();
    void _testResolvedVehicleAlertFromOtherThread();
    void _testSpecificFaultPrecedesGenericFallback();
    void _testGenericNoticeBurstCoalesces();
    void _testGenericCooldownRetainsFaultTranslations();
    void _testPrearmAlertLifetimeMatchesCheckCycle();
    void _testOrdinaryPairSurvivesPriorityChanges();
    void _testQueueEvictsFallbackBeforeConcreteFaults();
    void _testOrdinaryNoticeExpires();
};
