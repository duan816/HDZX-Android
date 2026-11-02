.pragma library
function state(group, name) { return group && group[name] ? Number(group[name].value) : 255 }
function authKnown(group) { const a=state(group,"authenticationState"); return a>=1 && a<=4 }
function threat(group) {
    const j=state(group,"jammingState"),s=state(group,"spoofingState")
    return Math.max(j>=1&&j<=3?j:0,s>=1&&s<=3?s:0)
}
function shouldShow(group) { return authKnown(group) || threat(group)>=2 }
function description(group,name) {
    const value=state(group,name)
    const words=name==="authenticationState"?["未提供认证信息","认证初始化中","认证失败","认证成功（正常）","认证已关闭"]
        : name==="jammingState"?["未提供干扰信息","未发现干扰","检测到干扰，已抑制","检测到干扰"]
        : ["未提供欺骗信息","未发现欺骗","检测到欺骗，已抑制","检测到欺骗（定位仍可能存在）"]
    return value>=0&&value<words.length?words[value]:"数据未上报或已过期"
}
