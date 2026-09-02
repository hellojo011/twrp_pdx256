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
# SM8750 은 armv9.2. android-14 Soong 의 archVariants 에 armv9-a 가 있는 것을
# 확인했습니다 (armv9-2a 는 없음).
TARGET_ARCH_VARIANT := armv9-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a76
TARGET_SUPPORTS_32_BIT_APPS := false
TARGET_SUPPORTS_64_BIT_APPS := true
# TARGET_USES_64_BIT_BINDER 는 android-14 에서 deprecated (모든 기기가 기본 64비트)

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

# DTB 는 boot.img 가 아니라 vendor_boot 안에 있습니다 (13개 SoC DTB, 6062476 bytes).
# 우리는 recovery(램디스크 전용)만 빌드하므로 DTB 를 패키징할 일이 없습니다.
# BOARD_PREBUILT_DTBIMAGE_DIR 은 BOARD_INCLUDE_DTB_IN_BOOTIMG := true 일 때만
# 허용되므로(board_config.mk:816) 아예 지정하지 않습니다.
# prebuilt/dtb.img 는 참고용으로 트리에 남아 있습니다.
#
# 주의: BOARD_INCLUDE_DTB_IN_BOOTIMG 을 "false" 로 두면 안 됩니다.
# core/Makefile 이 ifdef 로 검사해서(1058, 1327, 1629, 1789, 1815, 2746, 2880)
# false 여도 "정의됨"=참으로 동작합니다. 그러면 INSTALLED_DTBIMAGE_TARGET 이
# 잡히고 recovery.img 가 dtb.img 를 요구하는데, 만들 규칙이 없어 빌드가 죽습니다.
# 끄려면 아예 정의하지 않아야 합니다.

# dtbo.img: 71개 오버레이. Sony 전용 fragment 가 들어있는 것은 index 43/44/45
# ("Sun QRD SKU1 / SKU1 V8 / SKU2 V8") 와 56 ("SunP QRD HDK").
# TWRP 는 dtbo 를 교체하지 않으므로 순정 dtbo 를 그대로 씁니다.
# BOARD_INCLUDE_RECOVERY_DTBO 도 같은 이유로 정의하지 않습니다
# (core/Makefile 2736, 2870, 5969, 6573 에서 ifdef 검사).
# 순정 dtbo 를 그대로 쓰므로 빌드에서 dtbo.img 를 만들 필요가 없습니다.
# prebuilt/dtbo.img 는 참고 및 재플래시용으로만 보관합니다.
# BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img

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

# 이 기기는 super 안에 실제 vendor 파티션이 있습니다. 이걸 선언하지 않으면
# TARGET_COPY_OUT_VENDOR 가 비-Treble 기본값 "system/vendor" 로 남고,
# system/core/rootdir/Android.mk:117 이 /vendor 를 /system/vendor 로 가는
# 심볼릭 링크로 만듭니다. 그런데 bootable/recovery/prebuilt/Android.mk 의
# twrp_ramdisk 는 recovery/root/vendor 를 실제 디렉터리로 만들기 때문에,
# 램디스크 조립의 rsync 가 "could not make way for new symlink" 로 죽습니다.
# "vendor" 로 두면 board_config.mk:679 가 BOARD_USES_VENDORIMAGE 를 켜서
# root/vendor 가 실제 디렉터리가 되고 두 쪽이 병합됩니다.
# BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE 은 일부러 두지 않습니다 -- 그걸 넣으면
# BUILDING_VENDOR_IMAGE 가 켜져서 필요도 없는 vendor.img 를 빌드합니다.
TARGET_COPY_OUT_VENDOR := vendor
# PRODUCT_USE_DYNAMIC_PARTITIONS 는 제품 변수라 BoardConfig 에서 못 씁니다.
# (board_config.mk 는 제품 설정 이후에 실행돼 그 시점엔 readonly)
# -> twrp_pdx256.mk 로 옮겼습니다.
# super.sin 의 LP 메타데이터(v10.2)에서 직접 읽은 실제 그룹 이름입니다.
# ("qti_dynamic_partitions" 가 아님에 주의)
BOARD_SUPER_PARTITION_GROUPS := somc_dynamic_partitions
# system_dlkm 은 Android 13 부터 유효한 이름입니다. 실제 super 에도 존재합니다
# (12.5MB). 12.1 에서는 거부돼서 뺐던 것을 복원.
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

# blobs.mk 는 vendor blob 32개를 PRODUCT_COPY_FILES 로 넣는데, android-14 는
# ELF 파일을 그렇게 복사하는 것을 기본적으로 막습니다:
#   "found ELF prebuilt in PRODUCT_COPY_FILES,
#    use cc_prebuilt_binary / cc_prebuilt_library_shared instead."
# 정석은 Android.bp 에 cc_prebuilt_* 모듈 29개를 선언하는 것이지만,
# build/make 가 공식 탈출구를 제공합니다 (Changes.md:323).
# 주의: 이름 그대로 "broken" 취급이라 향후 버전에서 사라질 수 있습니다.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# TW_INCLUDE_FBE_METADATA_DECRYPT 를 켜면 bootable/recovery/Android.mk:369 가
# recovery 바이너리에 libsysutils 를 링크합니다. 그런데 libsysutils.so 를
# 램디스크에 "설치" 하는 쪽(prebuilt/Android.mk:362)은 아래 두 플래그가 모두
# 켜져 있을 때만 동작합니다. 안 켜면 부팅은 되지만 리커버리가 즉시 죽고
# SONY 로고에서 멈춥니다:
#   CANNOT LINK EXECUTABLE "/system/bin/recovery":
#   library "libsysutils.so" not found: needed by main executable
# 덤으로 리커버리 안에서 logcat 을 쓸 수 있게 됩니다 -- 복호화 디버깅에 필수.
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
# keymint blob 은 빌드 모듈이 아니라 prebuilt 파일이므로 blobs.mk 의
# PRODUCT_COPY_FILES 로 넣습니다. TARGET_RECOVERY_DEVICE_MODULES 에 적으면
# "module not found" 로 빌드가 실패합니다.
# 암호화 지원 -- 다시 켰습니다. 아래는 껐던 이유와 다시 켠 근거입니다.
#
# bootable/recovery/Android.mk:348 이
#   ifeq ($(TW_INCLUDE_CRYPTO), true)
#       ...
#       LOCAL_CFLAGS += -DTW_INCLUDE_FBE_METADATA_DECRYPT   <- 조건 없이 무조건
# 이라서 TW_INCLUDE_FBE_METADATA_DECRYPT 를 false 로 둬도 무한 대기하는
# fscrypt_mount_metadata_encrypted() 경로가 빌드에 그대로 들어갑니다.
# (false 로 빌드한 뒤 recovery 바이너리 문자열로 실제 확인했습니다)
#
# 그 호출은 keystore2 -> keymint 를 binder 로 부르는데 keystore2 가 리커버리에서
# 죽어 있어 응답이 없고, TWRP 가 splash 에서 멈춰 메뉴가 아예 뜨지 않습니다.
#
# "false" 가 아니라 정의 자체를 하지 않는 이유: Android.mk:581 이
#   ifneq ($(TW_INCLUDE_CRYPTO),)
# 로도 검사해서 false 조차 참으로 동작합니다 (DTB 플래그와 같은 함정).
#
# 껐던 이유는 keystore2 가 죽어서였는데, 그 사인이 VINTF 충돌로 밝혀졌습니다:
#   servicemanager: NULL VINTF MANIFEST!: device / framework
# base manifest 를 비우고 fragment 만 남기도록 고쳤으므로 다시 켭니다.
# 그래도 splash 에서 멈추면 crypto 를 끈 이미지로 되돌리면 됩니다
# (out/recovery-crypto-off.img).
# 암호화 -- 동작이 확인된 pineapple TWRP 의 방식으로 다시 켭니다.
#
# 여기까지 확인된 사슬:
#   qseecomd 가 리스너 10개를 모두 로드하는 데까지는 성공하지만,
#   TZ 핸드셰이크에서 멈춥니다:
#     SmcInvoke_MinkDescriptor: Failed to open invoke driver, errno = 13
#     SmcInvoke_TZCom: TZCom_getRootEnvObject ret=1
#     ListenerMngr: Error -1 getting clientEnv
#   -> keymint 가 servicemanager 에 등록되지 못하고
#   -> keystore2 는 keymint 를 무한 대기하며
#   -> TWRP 는 fscrypt_mount_metadata_encrypted() 에서 영원히 멈춥니다.
#
# errno 13 은 파일 권한이나 SELinux 문제가 아닙니다. 확인한 것:
#   - 셸에서 /dev/smcinvoke 는 O_RDONLY/O_WRONLY/O_RDWR 모두 정상 오픈
#   - setenforce 0 (전역 permissive) 로도 동일하게 실패
#   - 해당 노드를 점유 중인 다른 프로세스 없음
#   - 커널은 부팅 시 QTEE 와 정상 통신 (root object invocation returned 0)
#
# 참고: Sony 순정 recovery.img 에는 qseecomd / keymint / keystore2 / vold 가
# 아예 없습니다. 순정 리커버리도 /data 를 복호화하지 않고 wipe 만 합니다.
# 즉 이 TZ 클라이언트 스택은 이 기기의 리커버리 환경에서 동작한 전례가 없습니다.
#
# 되살리려면 아래 세 줄의 주석을 풀면 됩니다. blob 과 VINTF, 리스너 라이브러리는
# 모두 그대로 남겨두었으므로 TZ 문제만 풀리면 바로 이어서 시도할 수 있습니다.
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_USE_FSCRYPT_POLICY := 2
# 이 플래그를 켜면 partitionmanager.cpp:688 의
#   android::vold::fscrypt_mount_metadata_encrypted(...)
# 가 실행되는데, 이 호출은 keystore2 -> keymint 를 binder 로 부르고
# 응답이 없으면 영원히 대기합니다. keystore2 가 리커버리에서 죽는 상태라
# TWRP 가 splash 에서 멈추고 메뉴가 아예 뜨지 않습니다.
#
# 끄면 #else 분기가 로그 한 줄만 남기고 진행하므로 메뉴가 정상적으로 뜹니다.
#   LOGERR("Metadata FBE decrypt support not present in this build")
#
# /data 는 여전히 못 읽지만, 그것 말고 리커버리가 할 수 있는 일
# (플래싱, boot/vendor/vbmeta 백업, fastbootd, adb sideload) 은 전부 됩니다.
# 복호화를 다시 시도하려면 이 줄을 true 로 되돌리면 됩니다. 다만 그 전에
# keystore2 가 리커버리에서 살아있게 만드는 것이 선행되어야 합니다.
# TW_INCLUDE_FBE_METADATA_DECRYPT := true   (TW_INCLUDE_CRYPTO 와 함께 되살릴 것)
# android-14 부터 PLATFORM_SECURITY_PATCH 를 직접 지정하면 빌드가 에러로 막습니다:
#   "Do not set PLATFORM_SECURITY_PATCH directly. Use RELEASE_PLATFORM_SECURITY_PATCH."
# PLATFORM_VERSION 도 RELEASE_PLATFORM_VERSION 에서 유도되므로 건드리지 않습니다.
# (12.1 에서는 BoardConfig 에 두는 게 관례였지만 14 에서는 반대입니다)
VENDOR_SECURITY_PATCH := 2026-06-01

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
# --- OrangeFox ------------------------------------------------------------
# orangefox.mk:206 이 이 값을 -DOF_MAINTAINER 로 박아넣고, data.cpp:735 가
# GUI 변수 %of_maintainer% 로 노출합니다.
# 테마(pages/settings.xml)의 About 페이지는 of_maintainer 가 1/2/3(= OrangeFox
# 개발자 본인) 이 "아닐" 때만 별도의 "Unofficial maintainer" 카드를 그립니다.
# 즉 이름만 넣으면 카드가 자동으로 뜹니다. 비워두면 "Testing build (unofficial)".
OF_MAINTAINER := DIGIWB

# 그 카드의 아바타는 maintainer_img 리소스, 즉 램디스크의
#   twres/images/Default/About/maintainer.png 입니다.
# 테마 원본은 bootable/recovery 안이라 repo sync 때 날아가므로, 같은 경로를
# recovery/root/ 아래에 두어 덮어씁니다. build/make/core/Makefile 의
# 리커버리 이미지 레시피가
#   2773  rsync  (베이스 램디스크)
#   2780  OrangeFox_A14.sh  (테마/램디스크 가공)
#   2815  cp -rf $(recovery_root_private) $(TARGET_RECOVERY_OUT)/
# 순서로 돌기 때문에 recovery/root/ 가 항상 마지막에 이깁니다.
#
# 주의: PNG 는 8bit + 비인터레이스여야 합니다. minuitwrp/resources.cpp 는
# png_get_IHDR 에서 interlace_type 을 NULL 로 버리고 png_set_interlace_handling()
# 도 호출하지 않은 채 png_read_row() 로 순차 읽기만 하므로, Adam7 인터레이스
# PNG 는 화면에 아무것도 안 뜹니다. (순정 테마 이미지는 전부 8bit RGBA, 비인터레이스)
# 시계: orangefox.mk:571 의 OF_DEFAULT_TIMEZONE 기본값이
#   CET-1;CEST,M3.5.0,M10.5.0  (중앙유럽시간)
# 이라서 한국에서는 8시간 어긋납니다. data.cpp:1260 이 이 값을
# TW_TIME_ZONE_VAR 초기값으로 씁니다. POSIX TZ 는 부호가 반대라
# UTC+9 를 "KST-9" 로 씁니다. 한국은 서머타임이 없어 DST 규칙 불필요.
OF_DEFAULT_TIMEZONE := KST-9
# 시각 기준: Android.mk:430-438 의 화이트리스트가 msm8226~msm8998 까지라
# TARGET_BOARD_PLATFORM := sun 은 QCOM_RTC_FIX 가 정의되지 않습니다.
# 그러면 twrp-functions.cpp 의 Fixup_Time_On_Boot() 본체가 통째로
# 컴파일에서 빠져서, 리커버리가 시스템 시각을 아예 세팅하지 않습니다.
# (init 이 남긴 값이 그대로 보임 -> 실제와 몇 시간씩 어긋남)
#
# 켜면 /sys/class/rtc/rtc0/since_epoch 를 읽어 settimeofday() 하고,
# 그래도 2018년 이전이면 ats_* 파일(퀄컴 시간 오프셋)로 재보정합니다.
# 타임존(OF_DEFAULT_TIMEZONE)만으로는 못 고칩니다 - 타임존은 시 단위라
# 분이 안 맞는 어긋남(15:17 -> 01:30)을 설명할 수 없습니다.
TARGET_RECOVERY_QCOM_RTC_FIX := true
# 배터리: twrp.cpp:565 는 이 플래그가 있을 때만 sysfs 를 직접 읽고,
# 없으면 GetBatteryInfo() -> health HAL 로 갑니다. 이 기기는 리커버리에서
# health@2.0 HAL 이 제대로 안 올라와서 잔량이 안 잡힙니다.
# 이 플래그를 켜면 /sys/class/power_supply/battery/{capacity,status} 를
# 직접 읽으므로 HAL 을 우회합니다.
# 노드 이름이 battery 가 아닌 것으로 확인되면 대신
#   TW_CUSTOM_BATTERY_PATH := "/sys/class/power_supply/<이름>"
# 를 쓰면 됩니다 (Android.mk:419 가 legacy 를 자동으로 켜줍니다).
TW_USE_LEGACY_BATTERY_SERVICES := true
