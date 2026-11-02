.pragma library

var speedUnits = ["m/s", "km/h", "mph", "kn", "ft/s"]
var speedFactors = [1, 3.6, 2.2369362920544, 1.9438444924406, 3.2808398950131]

function speed(value, unitIndex) {
    return isFinite(value) && unitIndex >= 0 && unitIndex < speedFactors.length
            ? value * speedFactors[unitIndex] : NaN
}
function speedMaximum(key, unitIndex) {
    return (key === "airSpeed" ? [40, 160, 90, 80, 140] : [30, 120, 70, 60, 100])[unitIndex]
}
function speedIntervals(key, unitIndex) {
    return (key === "airSpeed" ? [8, 8, 9, 8, 7] : [6, 6, 7, 6, 5])[unitIndex]
}
function obstaclePoints(distances, increment, offset, frame, heading, minCm, maxCm) {
    if (!distances || !isFinite(increment) || increment === 0 || !isFinite(offset)
            || !(maxCm > minCm) || (frame !== 0 && frame !== 12)
            || (frame === 0 && !isFinite(heading))) return []
    const result = []
    for (let i = 0; i < Math.min(distances.length, 72); i++) {
        const cm = Number(distances[i])
        // UINT16_MAX is unknown; max+1 means no detected obstacle, not a target.
        // A true zero remains valid even below the nominal sensor minimum.
        if (!isFinite(cm) || cm < 0 || cm === 65535 || cm > maxCm || (cm !== 0 && cm < minCm)) continue
        result.push({bearing: offset + increment * i - (frame === 0 ? heading : 0), distance: cm / 100})
    }
    return result
}
