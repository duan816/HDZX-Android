.pragma library

function persistent(warnings) {
    return Array.from(warnings || []).filter(row => row.persistent).sort((a, b) => {
        const severity = Number(a.severity) - Number(b.severity)
        if (severity) return severity
        // Keep a missing manual-control link visible beside other equally
        // severe checks, even when a periodic battery message arrives last.
        const radio = /\b(rc|radio|receiver|manual control)\b/i
        return Number(radio.test(b.text)) - Number(radio.test(a.text))
    })
}

function transient(warnings, legacy) {
    const rows = Array.from(warnings || [])
    if (!rows.length || rows[0].persistent === undefined) return legacy && legacy.text ? legacy : null
    return rows.find(row => row.currentTransient) || null
}

function summary(warnings) {
    return warnings.map(bilingual).join("\n\n")
}

function bilingual(warning) {
    if (!warning || !warning.text) return ""
    return warning.text + (warning.translation && warning.translation !== warning.text ? "\n" + warning.translation : "")
}

function speaking(audio, vehicleId, warnings) {
    if (!audio || !audio.text || Number(audio.vehicleId) !== Number(vehicleId)) return null
    const guidance = Array.from(warnings || []).find(row => row.text === audio.text) || {}
    return Object.assign({}, guidance, audio)
}
