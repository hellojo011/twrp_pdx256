#!/system/bin/sh
#
# ADSP 를 띄워서 배터리 잔량/충전 상태를 노출시킨다.
#
# 왜 필요한가:
#   SM8750 은 연료게이지와 충전기가 ADSP 의 충전 펌웨어 뒤에 있다.
#   qti_battery_charger 모듈은 로드되어 있어도, pmic_glink 로 ADSP 에
#   붙은 뒤에야 /sys/class/power_supply/battery 를 등록한다.
#   리커버리는 ADSP 를 띄우지 않으므로 power_supply 클래스가 통째로 비고,
#   그래서 잔량이 -1% 로 나온다. sysfs 경로를 아무리 지정해도 소용없다.
#
# 왜 그냥 modem 파티션에서 로드하지 않는가:
#   커널 펌웨어 로더는 u:r:kernel:s0 자격으로 파일을 여는데, 리커버리
#   정책에서 kernel 은 vfat / tmpfs 라벨 파일을 읽지 못한다:
#     avc: denied { open } path="/firmware_mnt/image/adsp.mdt"
#          scontext=u:r:kernel:s0 tcontext=u:object_r:vfat:s0 permissive=0
#   순정처럼 context=u:object_r:firmware_file:s0 으로 마운트하려 해도
#   firmware_file 타입이 리커버리 정책에 없어서 mount 가 EINVAL 로 실패한다.
#   (vfat / tmpfs 는 있고 firmware_file / system_file 은 없음 - 실측 확인)
#
#   반면 rootfs(u:object_r:rootfs:s0) 라벨은 kernel 이 읽을 수 있다.
#   그래서 펌웨어를 /lib/firmware 로 복사한 뒤 거기서 로드한다.
#   Enforcing 상태 그대로 동작한다. 용량 약 21MB (RAM).

LOG=/tmp/adsp_boot.log
exec >>"$LOG" 2>&1
echo "===== adsp_boot 시작 ====="

FW=/lib/firmware
MNT=/firmware_mnt

if [ -e /sys/class/power_supply/battery/capacity ]; then
    echo "battery 노드가 이미 있음. 할 일 없음."
    exit 0
fi

SFX=$(getprop ro.boot.slot_suffix)
MODEM=
for c in "/dev/block/by-name/modem$SFX" /dev/block/by-name/modem; do
    [ -e "$c" ] && { MODEM=$c; break; }
done
if [ -z "$MODEM" ]; then
    echo "modem 파티션을 찾을 수 없음 (slot_suffix=$SFX)"
    exit 0
fi
echo "modem = $MODEM"

mkdir -p "$MNT" "$FW"
if ! mount -t vfat -o ro "$MODEM" "$MNT"; then
    echo "modem 마운트 실패"
    exit 0
fi

cp "$MNT"/image/adsp* "$FW"/ 2>/dev/null
umount "$MNT"

if [ ! -f "$FW/adsp.mdt" ]; then
    echo "adsp.mdt 복사 실패"
    exit 0
fi
echo "펌웨어 복사 완료: $(ls "$FW" | wc -l) 개"

echo "$FW" > /sys/module/firmware_class/parameters/path

# remoteproc 인덱스는 고정이 아니므로 이름으로 찾는다
RP=
for d in /sys/class/remoteproc/*/; do
    case "$(cat "$d/name" 2>/dev/null)" in
        *remoteproc-adsp) RP=$d; break;;
    esac
done
if [ -z "$RP" ]; then
    echo "adsp remoteproc 노드 없음"
    exit 0
fi
echo "remoteproc = $RP"

if [ "$(cat "$RP/state" 2>/dev/null)" != "running" ]; then
    echo start > "$RP/state"
fi

i=0
while [ $i -lt 15 ]; do
    [ -e /sys/class/power_supply/battery/capacity ] && break
    sleep 1
    i=$((i + 1))
done

echo "state   = $(cat "$RP/state" 2>/dev/null)"
echo "battery = $(cat /sys/class/power_supply/battery/capacity 2>/dev/null)% $(cat /sys/class/power_supply/battery/status 2>/dev/null)"
echo "===== adsp_boot 종료 ====="
