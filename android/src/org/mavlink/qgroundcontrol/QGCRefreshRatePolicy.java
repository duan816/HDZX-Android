package org.mavlink.qgroundcontrol;

final class QGCRefreshRatePolicy {
    private QGCRefreshRatePolicy() { }

    static int selectMode(int width, int height, int[] widths, int[] heights, float[] rates) {
        if (width <= 0 || height <= 0 || widths == null || heights == null || rates == null
                || widths.length != heights.length || widths.length != rates.length) return -1;
        int selected = -1;
        float bestRate = 0;
        for (int i = 0; i < rates.length; ++i) {
            if (widths[i] == width && heights[i] == height && Float.isFinite(rates[i])
                    && rates[i] > bestRate && rates[i] <= 144.5f) {
                selected = i;
                bestRate = rates[i];
            }
        }
        return selected;
    }
}
