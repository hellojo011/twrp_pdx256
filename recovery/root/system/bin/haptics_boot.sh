#!/system/bin/sh
#
# CS40L25A 햅틱(진동) 부트스트랩.
#
# 이 기기의 진동자는 PMIC 햅틱이 아니라 Cirrus Logic CS40L25A (I2C 6-0040) 다.
# 순정 dtbo 조차 qcom,hv-haptics 노드를 status="disable" 로 둔다.
#
# 리커버리에 없어서 안 되던 것:
#   1) 드라이버 모듈  cirrus_wm_adsp.ko, cirrus_cs40l2x.ko  (vendor_dlkm 소속)
#   2) DSP 펌웨어     cs40l25a_a2h.wmfw 등  (vendor 파티션 소속)
#
# 펌웨어를 /lib/firmware 로 복사하는 이유는 adsp_boot.sh 와 같다:
# 커널 펌웨어 로더는 u:r:kernel:s0 로 파일을 여는데 리커버리 정책상
# vfat/tmpfs 라벨은 못 읽고 rootfs 라벨은 읽을 수 있다.
# 램디스크에 미리 넣어두면 라벨이 보장되지 않으므로, 런타임에 mkdir 한
# /lib/firmware(rootfs) 로 복사해서 라벨을 확실히 만든다.
#
# 성공하면 /sys/class/leds/cs40l25:vibrator 가 생기고,
# vendor.vibrator.cs40l25 (AIDL IVibrator/default) 가 이걸 구동한다.
# TWRP 는 TW_SUPPORT_INPUT_AIDL_HAPTICS 로 그 HAL 을 호출한다.

LOG=/tmp/haptics_boot.log
exec >>"$LOG" 2>&1
echo "===== haptics_boot 시작 ====="

FW=/lib/firmware
SRC=/vendor/etc/cirrus-fw
MOD=/vendor/lib/modules
NODE=/sys/class/leds/cs40l25:vibrator

if [ -d "$NODE" ]; then
    echo "이미 노드 존재. 할 일 없음."
    setprop vendor.haptics.ready 1
    exit 0
fi

mkdir -p "$FW"
cp "$SRC"/* "$FW"/ 2>/dev/null
echo "펌웨어 복사: $(ls "$SRC" | wc -l) 개 -> $FW"
echo "$FW" > /sys/module/firmware_class/parameters/path

# 의존 순서: wm_adsp -> cs40l2x
for m in cirrus_wm_adsp cirrus_cs40l2x; do
    if lsmod | grep -q "^$m "; then
        echo "$m 이미 로드됨"
    else
        insmod "$MOD/$m.ko" && echo "$m 로드 OK" || echo "$m 로드 실패"
    fi
done

i=0
while [ $i -lt 15 ]; do
    [ -d "$NODE" ] && break
    sleep 1
    i=$((i + 1))
done

if [ -d "$NODE" ]; then
    echo "노드 생성됨: $NODE"
    setprop vendor.haptics.ready 1
else
    echo "노드 생성 실패 - HAL 을 시작하지 않는다"
fi
echo "===== haptics_boot 종료 ====="
