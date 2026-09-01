#!/bin/bash
# pdx256 blob 추출 - 루팅된 기기에서 직접 pull
#
# Windows Git Bash / WSL / Linux 어디서든 동작합니다.
# 단, WSL 에서는 기본적으로 USB 가 안 보이므로 Windows 쪽 adb.exe 를 쓰세요:
#   ADB=/mnt/c/Android/Sdk/platform-tools/adb.exe ./extract-blobs.sh
set -u

ADB="${ADB:-adb}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/recovery/root"
LIST="$HERE/proprietary-files.txt"

command -v "$ADB" >/dev/null 2>&1 || { echo "adb 를 찾을 수 없습니다. ADB=<경로> 로 지정하세요."; exit 1; }

"$ADB" wait-for-device
"$ADB" shell 'su -c id' 2>/dev/null | grep -q 'uid=0' || { echo "root 권한을 얻지 못했습니다."; exit 1; }

ok=0; fail=0
while read -r f; do
    case "$f" in ''|\#*) continue ;; esac
    dst="$OUT/$f"
    mkdir -p "$(dirname "$dst")"
    # exec-out: 바이너리 안전. adb shell 로 받으면 .so 가 깨집니다.
    "$ADB" exec-out "su -c 'cat /$f'" > "$dst" 2>/dev/null
    if [ -s "$dst" ]; then
        printf '  OK   %-70s %s bytes\n' "$f" "$(wc -c < "$dst" | tr -d ' ')"
        ok=$((ok+1))
    else
        printf '  FAIL %s\n' "$f"; rm -f "$dst"; fail=$((fail+1))
    fi
done < "$LIST"

echo
echo "성공 $ok / 실패 $fail  ->  recovery/root/vendor/"
echo
echo "검증: ELF 헤더가 살아있는지 확인"
find "$OUT/vendor" -name '*.so' 2>/dev/null | head -3 | while read -r x; do
    head -c 4 "$x" | od -An -tx1 | tr -d ' \n'; echo "  $x"
done
echo "(7f454c46 이면 정상. 다르면 adb 전송이 깨진 것)"
