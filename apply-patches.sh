#!/bin/bash
# device/sony/pdx256 가 필요로 하는 트리 밖 패치를 적용합니다.
# repo sync 를 다시 하면 이 패치들이 사라지므로 그때마다 실행해야 합니다.
#
# 사용법: 소스 트리 루트에서
#   ./device/sony/pdx256/apply-patches.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(pwd)"

apply() {  # $1=대상 repo 경로  $2=패치 파일
    local dir="$ROOT/$1" p="$HERE/patches/$2"
    [ -d "$dir" ] || { echo "  SKIP  $1 (없음)"; return; }
    if git -C "$dir" apply --check "$p" 2>/dev/null; then
        git -C "$dir" apply "$p" && echo "  OK    $1 <- $2"
    elif git -C "$dir" apply --reverse --check "$p" 2>/dev/null; then
        echo "  이미 적용됨  $1 <- $2"
    else
        echo "  FAIL  $1 <- $2  (충돌 - 수동 확인 필요)"
    fi
}

echo "트리 밖 패치 적용:"
# recovery 바이너리와 TWRP libtar.so 가 libsysutils.so 를 링크하는데,
# AOSP 의 libsysutils 에는 recovery_available 이 없어 recovery 변종이
# 빌드되지 않습니다. 그러면 리커버리가 부팅 시 이렇게 죽습니다:
#   CANNOT LINK EXECUTABLE "/system/bin/recovery":
#   library "libsysutils.so" not found
apply system/core 0001-libsysutils-recovery_available.patch
