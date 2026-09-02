# 리커버리 화면 캡쳐 (물리 키 없이)
#
# OrangeFox/TWRP 는 볼륨다운+전원을 200ms 이상 함께 누르면 스크린샷을 찍는다
# (gui/gui.cpp:293 -> GUIAction::screenshotImpl). 손으로 누르면 잘 안 잡히는데,
# 전원 키가 먼저 들어가면 화면 토글로 소비되기 때문이다. 순서가 중요하다:
# 볼륨다운을 먼저 누르고, 누른 채로 전원을 추가한 뒤 1초 유지한다.
#
# 이 스크립트는 sendevent 로 그 순서대로 키 이벤트를 주입한다.
#
# 이 기기의 키 배치 (/proc/bus/input/devices 의 KEY 비트맵에서 확인):
#   event1  gpio-keys    KEY_VOLUMEDOWN(114)
#   event2  pmic_resin   KEY_VOLUMEUP(115)
#   event3  pmic_pwrkey  KEY_POWER(116)
#
# 사용법:
#   powershell -ExecutionPolicy Bypass -File .\tools\screenshot.ps1
#   powershell -ExecutionPolicy Bypass -File .\tools\screenshot.ps1 -OutDir D:\shots

param(
    [string]$OutDir = ".",
    [string]$Adb    = "C:\platform-tools\adb.exe"
)

if (-not (Test-Path $Adb)) { Write-Error "adb 를 찾을 수 없습니다: $Adb"; exit 1 }

# 주의: "no devices/emulators found" 에도 device 가 들어있어 부분일치는 위험하다
$state = ((& $Adb get-state 2>&1) -join "").Trim()
if ($state -notmatch '^(recovery|device|sideload)$') {
    Write-Error "기기가 연결되지 않았습니다 (state=$state)"
    exit 1
}

$cmd = 'VD=/dev/input/event1; PW=/dev/input/event3; ' +
       'sendevent $VD 1 114 1; sendevent $VD 0 0 0; ' +
       'sendevent $PW 1 116 1; sendevent $PW 0 0 0; ' +
       'sleep 1; ' +
       'sendevent $PW 1 116 0; sendevent $PW 0 0 0; ' +
       'sendevent $VD 1 114 0; sendevent $VD 0 0 0; ' +
       'sleep 2; ls -t /sdcard/Fox/screenshots/*.png 2>/dev/null | head -1'

$out = & $Adb shell $cmd 2>&1
$latest = ($out | Where-Object { "$_" -match '\.png\s*$' } | Select-Object -First 1)
if ($latest) { $latest = "$latest".Trim() }

if (-not $latest) {
    Write-Error "스크린샷이 생기지 않았습니다. adb shell tail /tmp/recovery.log 를 확인하세요."
    Write-Host  ("adb 출력: " + ($out -join " | "))
    exit 1
}

$dest = Join-Path $OutDir (Split-Path $latest -Leaf)
& $Adb pull $latest $dest 2>&1 | Out-Null

if (Test-Path $dest) {
    Write-Host ("저장: {0}  ({1:N0} bytes)" -f $dest, (Get-Item $dest).Length)
} else {
    Write-Error "pull 실패: $latest"
    exit 1
}
