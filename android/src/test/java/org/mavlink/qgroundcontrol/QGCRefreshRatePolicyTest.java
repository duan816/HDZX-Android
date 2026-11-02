package org.mavlink.qgroundcontrol;

import static org.junit.Assert.assertEquals;
import org.junit.Test;

public class QGCRefreshRatePolicyTest {
    @Test public void picks144HzWithoutChangingResolution() {
        assertEquals(3, QGCRefreshRatePolicy.selectMode(2560, 1600,
            new int[]{2560, 2560, 2560, 2560, 1920}, new int[]{1600, 1600, 1600, 1600, 1080},
            new float[]{60, 90, 120, 144, 144}));
    }
    @Test public void fallsBackToSupportedRate() {
        assertEquals(1, QGCRefreshRatePolicy.selectMode(1920, 1080,
            new int[]{1920, 1920}, new int[]{1080, 1080}, new float[]{60, 120}));
        assertEquals(0, QGCRefreshRatePolicy.selectMode(1920, 1080,
            new int[]{1920}, new int[]{1080}, new float[]{60}));
    }
    @Test public void rejectsInvalidAndMismatchedModes() {
        assertEquals(-1, QGCRefreshRatePolicy.selectMode(1920, 1080,
            new int[]{1280, 1920, 1920}, new int[]{720, 1080, 1080}, new float[]{144, Float.NaN, 0}));
        assertEquals(-1, QGCRefreshRatePolicy.selectMode(1920, 1080,
            new int[]{1920}, new int[]{1080}, new float[]{}));
        assertEquals(-1, QGCRefreshRatePolicy.selectMode(1920, 1080, null, null, null));
    }
}
