LOCAL_PATH := device/sony/pdx256

# blob 은 root/vendor 가 아니라 root/system/vendor 로 들어갑니다.
# 리커버리 루트의 /vendor 는 /system/vendor 를 가리키는 심볼릭 링크이고,
# 거기에 실제 디렉터리를 만들면 램디스크 조립에서 rsync 가 죽습니다:
#   cannot delete non-empty directory: root/vendor
#   could not make way for new symlink: root/vendor
# system/vendor 에 두면 런타임에 /vendor/bin/... 으로 정상 해석됩니다.
# recovery/root/system/vendor 아래에 있는 모든 파일을 TWRP 램디스크로 복사.
# extract-blobs.sh 를 돌리기 전에는 아무것도 복사되지 않으므로 빌드는 그대로 성공합니다.
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/recovery/root/system/vendor,$(TARGET_COPY_OUT_RECOVERY)/root/system/vendor)

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/etc/init/init.recovery.crypto.rc:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/init/init.recovery.crypto.rc
