# recovery/root/vendor 아래에 있는 모든 파일을 TWRP 램디스크로 복사.
# extract-blobs.sh 를 돌리기 전에는 아무것도 복사되지 않으므로 빌드는 그대로 성공합니다.
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/recovery/root/vendor,$(TARGET_COPY_OUT_RECOVERY)/root/vendor)

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/etc/init/init.recovery.crypto.rc:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/init/init.recovery.crypto.rc
