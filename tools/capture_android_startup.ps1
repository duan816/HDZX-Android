param(
    [string]$Adb = 'adb',
    [string]$Serial = '',
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (!$OutputDirectory) {
    $OutputDirectory = Join-Path $projectRoot ('artifacts/startup-crash-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$deviceLines = & $Adb devices
if (!$Serial) {
    $online = @($deviceLines | Where-Object { $_ -match '^\S+\s+device$' })
    if ($online.Count -ne 1) { throw 'Connect exactly one authorized Android device, or specify -Serial.' }
    $Serial = ($online[0] -split '\s+')[0]
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$package = 'org.hquavcenter.hdzx.opensource'
& $Adb -s $Serial shell dumpsys package $package > (Join-Path $OutputDirectory 'package.txt')
& $Adb -s $Serial logcat -b crash -d -v threadtime > (Join-Path $OutputDirectory 'previous-crash.txt')
& $Adb -s $Serial shell am start -W -n ($package + '/org.mavlink.qgroundcontrol.QGCActivity') > (Join-Path $OutputDirectory 'launch.txt')
for ($attempt = 0; $attempt -lt 15; ++$attempt) {
    Start-Sleep -Seconds 2
    $appPid = & $Adb -s $Serial shell pidof $package
    if (!$appPid) { break }
}
& $Adb -s $Serial logcat -d -v threadtime -t 6000 > (Join-Path $OutputDirectory 'startup-logcat.txt')
& $Adb -s $Serial logcat -b crash -d -v threadtime > (Join-Path $OutputDirectory 'crash.txt')
& $Adb -s $Serial shell dumpsys activity exit-info $package > (Join-Path $OutputDirectory 'exit-info.txt')
Write-Output $OutputDirectory
