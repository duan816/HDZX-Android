.pragma library

function gpsPresent(gps) {
    // FactGroup objects and count=0 exist before any receiver has reported.
    // MAVLink fix_type=0 means no GPS; 1 means a present receiver without a fix.
    return !!gps && !!gps.telemetryAvailable && !!gps.lock && Number(gps.lock.rawValue) > 0
}

function voltageFraction(voltage, low, full) {
    if (!isFinite(voltage) || !isFinite(low) || !isFinite(full) || voltage <= 0 || low <= 0 || full <= low) return NaN
    return Math.max(0, Math.min(1, (voltage - low) / (full - low)))
}

function percentageFraction(percent) {
    return isFinite(percent) && percent >= 0 && percent <= 100 ? percent / 100 : NaN
}

// Display range, not link quality or packet success rate. The numerical label
// remains in dBm because receivers cannot share a universal quality percentage.
function signalFraction(dbm) {
    return isFinite(dbm) && dbm >= -120 && dbm <= 0 ? Math.max(0, Math.min(1, (dbm + 110) / 60)) : NaN
}
