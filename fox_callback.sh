#!/bin/bash
#
# OrangeFox 로컬 콜백 스크립트 (FOX_LOCAL_CALLBACK_SCRIPT)
#
# vendor/recovery/OrangeFox_A14.sh 가 램디스크를 다 채운 뒤에 호출합니다.
#   $1 = --first-call 이면 램디스크 디렉터리 ($FOX_RAMDISK)
#        --last-call  이면 zip 작업 디렉터리
#
# 여기서 하는 일: About 화면의 메인테이너 아바타를 우리 것으로 교체.
# 테마 원본은 bootable/recovery/gui/theme/... 아래에 있어서 직접 고치면
# repo sync 때 날아갑니다. 그래서 디바이스 트리에 두고 여기서 덮어씁니다.

RAMDISK="$1"
CALL="$2"

[ "$CALL" = "--first-call" ] || exit 0
[ -d "$RAMDISK" ] || exit 0

DEVICE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DEVICE_PATH/theme/images/Default/About/maintainer.png"
DST_DIR="$RAMDISK/twres/images/Default/About"

if [ -f "$SRC" ] && [ -d "$DST_DIR" ]; then
    cp -f "$SRC" "$DST_DIR/maintainer.png"
    echo "  -- pdx256: maintainer avatar replaced"
else
    echo "  -- pdx256: WARNING - maintainer avatar not installed"
    echo "     SRC=$SRC (exists: $([ -f "$SRC" ] && echo yes || echo no))"
    echo "     DST=$DST_DIR (exists: $([ -d "$DST_DIR" ] && echo yes || echo no))"
fi

exit 0
