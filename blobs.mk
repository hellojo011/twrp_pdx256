LOCAL_PATH := device/sony/pdx256

# blob 은 root/vendor 로 들어갑니다. BoardConfig 의 TARGET_COPY_OUT_VENDOR :=
# vendor 덕분에 root/vendor 가 실제 디렉터리라, twrp_ramdisk 가 만드는
# vendor/etc/selinux 와 자연스럽게 병합됩니다.
# recovery/root/vendor 아래에 있는 모든 파일을 TWRP 램디스크로 복사.
# extract-blobs.sh 를 돌리기 전에는 아무것도 복사되지 않으므로 빌드는 그대로 성공합니다.
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/recovery/root/vendor,$(TARGET_COPY_OUT_RECOVERY)/root/vendor)

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/etc/init/init.recovery.crypto.rc:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/init/init.recovery.crypto.rc
