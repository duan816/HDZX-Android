package org.mavlink.qgroundcontrol;

import android.app.Activity;
import android.content.Context;
import android.hardware.display.DisplayManager;
import android.view.Display;
import android.view.WindowManager;

final class QGCDisplayRefreshController implements DisplayManager.DisplayListener {
    private final Activity activity;
    private final DisplayManager manager;
    private boolean registered;
    private float observedRate;

    QGCDisplayRefreshController(Activity activity) {
        this.activity = activity;
        manager = (DisplayManager) activity.getSystemService(Context.DISPLAY_SERVICE);
    }

    void onResume() {
        if (manager != null && !registered) {
            manager.registerDisplayListener(this, null);
            registered = true;
        }
        apply();
    }

    void onPause() {
        if (manager != null && registered) {
            manager.unregisterDisplayListener(this);
            registered = false;
        }
        final WindowManager.LayoutParams attributes = activity.getWindow().getAttributes();
        if (attributes.preferredDisplayModeId != 0 || attributes.preferredRefreshRate != 0) {
            attributes.preferredDisplayModeId = 0;
            attributes.preferredRefreshRate = 0;
            activity.getWindow().setAttributes(attributes);
        }
    }

    void apply() {
        if (!registered) return;
        final Display display = activity.getWindow().getDecorView().getDisplay();
        if (display == null) return;
        final Display.Mode current = display.getMode();
        if (Math.abs(observedRate - current.getRefreshRate()) > 0.1f) {
            observedRate = current.getRefreshRate();
            QGCLogger.i("QGCDisplayRefresh", "Active display mode: " + observedRate + " Hz");
        }
        final Display.Mode[] modes = display.getSupportedModes();
        final int[] widths = new int[modes.length], heights = new int[modes.length];
        final float[] rates = new float[modes.length];
        for (int i = 0; i < modes.length; ++i) {
            widths[i] = modes[i].getPhysicalWidth();
            heights[i] = modes[i].getPhysicalHeight();
            rates[i] = modes[i].getRefreshRate();
        }
        final int selected = QGCRefreshRatePolicy.selectMode(current.getPhysicalWidth(), current.getPhysicalHeight(), widths, heights, rates);
        if (selected < 0) return;
        final WindowManager.LayoutParams attributes = activity.getWindow().getAttributes();
        if (attributes.preferredDisplayModeId == modes[selected].getModeId()
                && Math.abs(attributes.preferredRefreshRate - rates[selected]) < 0.1f) return;
        attributes.preferredDisplayModeId = modes[selected].getModeId();
        attributes.preferredRefreshRate = rates[selected];
        activity.getWindow().setAttributes(attributes);
        QGCLogger.i("QGCDisplayRefresh", "Requested " + rates[selected] + " Hz at " + widths[selected] + "x" + heights[selected]);
    }

    @Override public void onDisplayAdded(int id) { apply(); }
    @Override public void onDisplayChanged(int id) { apply(); }
    @Override public void onDisplayRemoved(int id) { }
}
