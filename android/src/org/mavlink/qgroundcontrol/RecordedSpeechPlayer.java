package org.mavlink.qgroundcontrol;

import android.media.AudioAttributes;
import android.media.MediaPlayer;

/** Called only by the recorded-speech worker; platform callbacks never call Qt. */
public final class RecordedSpeechPlayer {
    private volatile MediaPlayer player;
    private volatile boolean failed;
    private String preparedPath = "";

    public synchronized boolean prepare(String path) {
        if (player != null && !failed && preparedPath.equals(path)) return true;
        release();
        try {
            player = new MediaPlayer();
            player.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build());
            player.setOnErrorListener((source, what, extra) -> {
                if (source == player) failed = true;
                return true;
            });
            player.setDataSource(path);
            player.prepare();
            preparedPath = path;
            return true;
        } catch (Exception error) {
            release();
            return false;
        }
    }

    public synchronized boolean start(String path, float volume) {
        if (!prepare(path)) return false;
        try {
            player.seekTo(0);
            player.setVolume(volume, volume);
            player.start();
            return true;
        } catch (Exception error) {
            failed = true;
            return false;
        }
    }

    /** 1: playing, 0: completed/stopped, -1: backend failure. */
    public synchronized int status() {
        if (player == null || failed) return -1;
        try {
            return player.isPlaying() ? 1 : 0;
        } catch (Exception error) {
            failed = true;
            return -1;
        }
    }

    public synchronized void stop() {
        if (player == null || failed) return;
        try {
            if (player.isPlaying()) player.pause();
            player.seekTo(0);
        } catch (Exception error) {
            failed = true;
        }
    }

    public synchronized void setVolume(float volume) {
        if (player == null || failed) return;
        try {
            player.setVolume(volume, volume);
        } catch (Exception error) {
            failed = true;
        }
    }

    public synchronized void release() {
        MediaPlayer previous = player;
        player = null;
        preparedPath = "";
        failed = false;
        if (previous != null) previous.release();
    }
}
