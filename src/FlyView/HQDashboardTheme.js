.pragma library

// A visual theme never changes a vehicle mode or its telemetry.
function modeKey(mode) {
    const raw = String(mode || "")
    // Production firmware plugins can return translated bilingual labels.
    // Prefer their English suffix so 特技（Acro）does not become unknown.
    const suffix = raw.match(/[（(]([A-Za-z][A-Za-z _-]*)[）)]/)
    const text = (suffix ? suffix[1] : raw).toLowerCase().replace(/[\s_\-()（）]/g, "")
    if (/^(stabilize|stabilized|自稳|自稳模式)$/.test(text)) return "stabilize"
    if (/^(acro|特技|特技模式)$/.test(text)) return "acro"
    if (/^(althold|altitudehold|altitude|定高|定高模式|高度模式)$/.test(text)) return "altHold"
    if (/^(loiter|hold|positionhold|poshold|position|pos|定点|定点模式|定点悬停|悬停|悬停模式|保持|位置保持|位置模式)$/.test(text)) return "loiter"
    if (/^(rtl|smartrtl|return|returntolaunch|返航|返航模式|智能返航)$/.test(text)) return "rtl"
    if (/^(auto|mission|自动|自动模式|自动任务|任务|任务模式)$/.test(text)) return "auto"
    if (/^(guided|引导)$/.test(text)) return "guided"
    if (/^(offboard|外部控制)$/.test(text)) return "offboard"
    if (/^(land|precisionland|降落|着陆|精准降落)$/.test(text)) return "land"
    if (/^(brake|刹停|刹车|制动)$/.test(text)) return "brake"
    if (/^(circle|orbit|绕圈|环绕|盘旋)$/.test(text)) return "circle"
    if (/^(sport|运动|运动模式)$/.test(text)) return "sport"
    if (/^(manual|手动|手动模式)$/.test(text)) return "manual"
    if (/^(follow|followme|跟随|跟随模式)$/.test(text)) return "follow"
    if (/^(rattitude|半自稳|半自稳模式)$/.test(text)) return "rattitude"
    if (/^(takeoff|vtoltakeoff|起飞|垂直起飞)$/.test(text)) return "takeoff"
    return "neutral"
}

function keys() { return ["stabilize", "altHold", "loiter", "rtl", "auto", "acro", "guided", "land", "brake", "circle", "sport", "manual", "follow", "rattitude", "takeoff", "offboard"] }

function chineseName(key) {
    const names = {stabilize: qsTr("自稳"), altHold: qsTr("定高"), loiter: qsTr("定点 / 位置保持"), rtl: qsTr("返航"), auto: qsTr("自动任务"), acro: qsTr("特技"), guided: qsTr("引导"), land: qsTr("降落"), brake: qsTr("刹停"), circle: qsTr("绕圈"), sport: qsTr("运动"), manual: qsTr("手动"), follow: qsTr("跟随"), rattitude: qsTr("半自稳"), takeoff: qsTr("起飞"), offboard: qsTr("外部控制")}
    return names[key] || "--"
}

function theme(key) {
    const themes = {
        stabilize: {skin: "classic", face: "white", kind: "dial", graph: 0, symbol: "◇", accent: "#8CD6FF", surface: "#111D2A", name: "STABILIZE"},
        altHold: {skin: "precision", face: "white", kind: "dial", graph: 1, symbol: "↕", accent: "#F0C068", surface: "#1B2027", name: "ALT HOLD"},
        loiter: {skin: "navigation", face: "black", kind: "dial", graph: 2, symbol: "⌖", accent: "#7DD8F7", surface: "#080E14", name: "POSITION"},
        rtl: {skin: "return", face: "black", kind: "dial", graph: 3, symbol: "↶ H", accent: "#BCABFF", surface: "#0B0D14", name: "RETURN"},
        auto: {skin: "mission", face: "black", kind: "dial", graph: 4, symbol: "▰ ▰ ▰", accent: "#61C3FF", surface: "#080E14", name: "MISSION"},
        acro: {skin: "performance", face: "red", kind: "dial", graph: 5, symbol: "∞", accent: "#FF5262", surface: "#230F18", name: "ACRO"},
        guided: {skin: "external", face: "black", kind: "dial", graph: 6, symbol: "⇥", accent: "#E8CE83", surface: "#090E14", name: "GUIDED"},
        land: {skin: "landing", face: "white", kind: "digital", graph: 7, symbol: "↓", accent: "#8AD5B5", surface: "#131F26", name: "LAND"},
        brake: {skin: "brake", face: "black", kind: "digital", graph: 8, symbol: "■", accent: "#F5B56C", surface: "#080E14", name: "BRAKE"},
        circle: {skin: "orbit", face: "black", kind: "dial", graph: 9, symbol: "◎", accent: "#68D2FC", surface: "#080E14", name: "ORBIT"},
        sport: {skin: "sport", face: "white", kind: "dial", graph: 10, symbol: "»", accent: "#B7CFF6", surface: "#171E29", name: "SPORT"},
        manual: {skin: "manual", face: "red", kind: "digital", graph: 11, symbol: "X", accent: "#FF6464", surface: "#230D14", name: "MANUAL"},
        follow: {skin: "follow", face: "black", kind: "dial", graph: 12, symbol: "⇢", accent: "#9CDC8E", surface: "#090F13", name: "FOLLOW"},
        rattitude: {skin: "rattitude", face: "red", kind: "digital", graph: 13, symbol: "↗", accent: "#FF8364", surface: "#24131A", name: "RATTITUDE"},
        takeoff: {skin: "launch", face: "white", kind: "digital", graph: 14, symbol: "↑", accent: "#ACBDFE", surface: "#151F2F", name: "TAKEOFF"},
        offboard: {skin: "offboard", face: "green", kind: "dial", graph: 15, symbol: "◎", accent: "#65F3A4", surface: "#071A16", name: "OFFBOARD"}
    }
    return themes[key] || {skin: "neutral", face: "black", kind: "dial", graph: 0, symbol: "—", accent: "#A8BCCB", surface: "#111C27", name: "FLIGHT DECK"}
}
