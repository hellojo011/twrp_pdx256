#
# BoardConfig.mk - Sony pdx256 (SM8750 / "sun")
#
# 이 파일의 값은 전부 순정 이미지에서 직접 읽어낸 것입니다.
# 출처가 불확실하거나 기기에서 확인이 필요한 항목은 TODO 로 표시했습니다.
#

DEVICE_PATH := device/sony/pdx256

# --- Platform ------------------------------------------------------------
# ro.product.board=sun, ro.board.platform=sun, ro.soc.manufacturer=QTI
TARGET_BOARD_PLATFORM := sun
TARGET_BOARD_SUFFIX := _64
TARGET_USES_UEFI := true

# ro.product.cpu.abi=arm64-v8a, abilist32 이 비어 있음 -> 순수 64비트 기기
TARGET_ARCH := arm64
# SM8750 은 실제로 armv9.2 이지만, OrangeFox/TWRP 12.1 (Android 12.1 기반) 빌드
# 시스템은 armv9-a 를 모릅니다. 리커버리 성능과는 무관하므로 armv8-a 로 둡니다.
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a76
TARGET_SUPPORTS_32_BIT_APPS := false
TARGET_SUPPORTS_64_BIT_APPS := true
TARGET_USES_64_BIT_BINDER := true

# --- Kernel --------------------------------------------------------------
# boot.img: header v4, kernel_size=36596224, ramdisk_size=0  (GKI, 커널 전용)
# Linux version 6.6.92-android15-8-g6715ebef9908-ab14756967-4k
# -> 4K 페이지 GKI 커널. 소스 빌드 없이 prebuilt 그대로 사용.
BOARD_KERNEL_IMAGE_NAME := Image
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/Image
TARGET_KERNEL_SOURCE :=
BOARD_KERNEL_PAGESIZE := 4096
BOARD_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)

# 순정 recovery.img 의 cmdline 은 비어 있습니다.
# (부팅 인자는 vendor_boot 의 cmdline + bootconfig 가 담당)
BOARD_KERNEL_CMDLINE :=

# vendor_boot 헤더에서 읽은 로드 주소 (참고용, header v4 에서는 mkbootimg 가 무시)
#   kernel_addr=0x00008000  ramdisk_addr=0x01000000
#   tags_addr=0x00000100    dtb_addr=0x01f00000

# DTB 는 boot.img 가 아니라 vendor_boot 안에 있습니다 (13개 SoC DTB, 6062476 bytes)
BOARD_INCLUDE_DTB_IN_BOOTIMG := false
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt

# dtbo.img: 71개 오버레이. Sony 전용 fragment 가 들어있는 것은 index 43/44/45
# ("Sun QRD SKU1 / SKU1 V8 / SKU2 V8") 와 56 ("SunP QRD HDK").
# TWRP 는 dtbo 를 교체하지 않으므로 순정 dtbo 를 그대로 씁니다.
BOARD_INCLUDE_RECOVERY_DTBO := false
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img

# --- Recovery ------------------------------------------------------------
# 순정 recovery.img: header v4, kernel_size=0, ramdisk 만 19775596 bytes (LZ4 legacy)
# 즉 recovery 파티션에는 램디스크만 들어갑니다. 커널은 boot.img 에서 옵니다.
# 이 플래그가 없으면 빌드가 커널을 recovery.img 안에 넣어버려 부팅하지 않습니다.
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_USES_RECOVERY_AS_BOOT := false
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := false
BOARD_RAMDISK_USE_LZ4 := true

# 파티션 크기 = 덤프 파일 크기 (100 MiB). 실제 이미지 본체는 0x12DE000 까지이고
# 그 뒤는 0 패딩 + AVB footer 입니다.
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600

TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab

# --- A/B & Dynamic partitions -------------------------------------------
# ro.build.ab_update=true, ro.boot.dynamic_partitions=true
# ro.virtual_ab.enabled=true, ro.virtual_ab.compression.enabled=true
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += boot dtbo init_boot odm recovery system_dlkm vbmeta vendor vendor_boot vendor_dlkm
BOARD_USES_METADATA_PARTITION := true
# PRODUCT_USE_DYNAMIC_PARTITIONS 는 제품 변수라 BoardConfig 에서 못 씁니다.
# (board_config.mk 는 제품 설정 이후에 실행돼 그 시점엔 readonly)
# -> twrp_pdx256.mk 로 옮겼습니다.
# super.sin 의 LP 메타데이터(v10.2)에서 직접 읽은 실제 그룹 이름입니다.
# ("qti_dynamic_partitions" 가 아님에 주의)
BOARD_SUPER_PARTITION_GROUPS := somc_dynamic_partitions
BOARD_SOMC_DYNAMIC_PARTITIONS_PARTITION_LIST :=     system system_ext product vendor odm vendor_dlkm system_dlkm
# 기기 확인값: blockdev --getsize64 /dev/block/by-name/super = 19327352832 (18 GiB)
BOARD_SUPER_PARTITION_SIZE := 19327352832
# Virtual A/B (retrofit 아님) 이므로 그룹 크기는 super 에서 메타데이터 여유분을 뺀 값.
BOARD_SOMC_DYNAMIC_PARTITIONS_SIZE := 19323158528

# --- Filesystem ----------------------------------------------------------
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_HAS_LARGE_FILESYSTEM := true

# --- AVB -----------------------------------------------------------------
# recovery 파티션 끝에 AVB footer 존재 (원본 이미지 0x12DE000, vbmeta 0x8C0).
# fstab 상 recovery 는 avb=vbmeta 로 검증됩니다.
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
# 수정한 recovery 를 부팅하려면 언락 후 vbmeta 를
#   fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
# 로 함께 플래시해야 합니다.

# --- Crypto --------------------------------------------------------------
# vendor_boot fstab.qcom 기준:
#   fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0
#   metadata_encryption=aes-256-xts:wrappedkey_v0
#   keydirectory=/metadata/vold/metadata_encryption
# 하드웨어 래핑 키(HW-wrapped FBE) + ICE 입니다.
BOARD_USES_QCOM_HARDWARE := true
# keymint blob 은 빌드 모듈이 아니라 prebuilt 파일이므로 blobs.mk 의
# PRODUCT_COPY_FILES 로 넣습니다. TARGET_RECOVERY_DEVICE_MODULES 에 적으면
# "module not found" 로 빌드가 실패합니다.
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
PLATFORM_SECURITY_PATCH := 2026-06-01
VENDOR_SECURITY_PATCH := 2026-06-01
PLATFORM_VERSION := 15

# --- TWRP ----------------------------------------------------------------
# 기기 확인값: wm size = 1080x2340
TW_THEME := portrait_hdpi
TARGET_SCREEN_WIDTH := 1080
TARGET_SCREEN_HEIGHT := 2340
TW_SCREEN_BLANK_ON_BOOT := true
TW_EXTRA_LANGUAGES := true
TW_DEFAULT_LANGUAGE := en
TW_INPUT_BLACKLIST := "hbtp_vm"
TW_USE_TOOLBOX := true
TW_EXCLUDE_APEX := true
TW_NO_SCREEN_BLANK := false

# 백라이트 노드는 순정 init.recovery.qcom.rc 에서 확인됨
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 200

# SD 카드 슬롯 있음 (fstab.qcom: /devices/platform/soc/8804000.sdhci/mmc_host*)
TW_INTERNAL_STORAGE_PATH := "/data/media/0"
TW_INTERNAL_STORAGE_MOUNT_POINT := "data"
TW_EXTERNAL_STORAGE_PATH := "/external_sd"
TW_EXTERNAL_STORAGE_MOUNT_POINT := "external_sd"

TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_HAS_MTP := true
TW_MTP_DEVICE := /dev/mtp_usb

# ro.recovery.usb.* 에서 확인
TW_DEVICE_VERSION := pdx256-SHIMANTO-1.1.0
