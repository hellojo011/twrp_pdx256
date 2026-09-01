# pdx256 blob 추출 - PowerShell 버전 (Git Bash 없이 Windows 에서 바로 실행)
#   powershell -ExecutionPolicy Bypass -File .\extract-blobs.ps1

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$out  = Join-Path $here 'recovery\root\system'   # /vendor 는 심볼릭 링크라 system\vendor 아래에 둡니다
$list = Join-Path $here 'proprietary-files.txt'

$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) { $adb = 'C:\Android\Sdk\platform-tools\adb.exe' }
if (-not (Test-Path $adb)) { throw "adb 를 찾을 수 없습니다." }

& $adb wait-for-device
$id = & $adb shell "su -c id" 2>$null
if ($id -notmatch 'uid=0') { throw "root 권한을 얻지 못했습니다." }

$ok = 0; $fail = 0
Get-Content $list | ForEach-Object {
    $f = $_.Trim()
    if ($f -eq '' -or $f.StartsWith('#')) { return }

    $dst = Join-Path $out ($f -replace '/', '\')
    $dir = Split-Path -Parent $dst
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }

    # cmd 의 리다이렉션은 바이트 단위로 정확합니다.
    # PowerShell 5.1 의 > 나 Out-File 은 네이티브 exe 출력을 텍스트로 디코딩해 바이너리를 깨뜨립니다.
    & cmd /c "`"$adb`" exec-out `"su -c 'cat /$f'`" > `"$dst`" 2>nul"

    if ((Test-Path $dst) -and ((Get-Item $dst).Length -gt 0)) {
        "  OK   {0,-70} {1} bytes" -f $f, (Get-Item $dst).Length
        $ok++
    } else {
        "  FAIL $f"
        if (Test-Path $dst) { Remove-Item $dst }
        $fail++
    }
}

""
"성공 $ok / 실패 $fail  ->  recovery\root\system\vendor\"
""
"검증: ELF 헤더 확인 (7f 45 4c 46 이면 정상)"
Get-ChildItem -Path (Join-Path $out 'vendor') -Recurse -Filter *.so -ErrorAction SilentlyContinue |
    Select-Object -First 3 | ForEach-Object {
        $b = [IO.File]::ReadAllBytes($_.FullName)[0..3]
        "  {0}  {1}" -f (($b | ForEach-Object { $_.ToString('x2') }) -join ' '), $_.Name
    }
