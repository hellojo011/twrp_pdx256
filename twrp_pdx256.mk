#
# twrp_pdx256.mk - Sony pdx256 (SM8750 / "sun")
#

# 제품 makefile 에서는 LOCAL_PATH 가 자동으로 정의되지 않습니다. 반드시 직접 지정.
LOCAL_PATH := device/sony/pdx256

# 64비트 전용 기기 (abilist32 이 비어 있음)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
# embedded.mk 는 Android 12.1 에서 삭제되었습니다. 이 트리에는 base.mk 만 존재합니다.
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

# 동적 파티션 (BoardConfig 가 아니라 여기에 있어야 합니다)
PRODUCT_USE_DYNAMIC_PARTITIONS := true

PRODUCT_DEVICE := pdx256
PRODUCT_NAME := twrp_pdx256
PRODUCT_BRAND := Sony
PRODUCT_MODEL := Pdx256
PRODUCT_MANUFACTURER := Sony
PRODUCT_RELEASE_NAME := pdx256

# 기기는 SDK 35 지만 OrangeFox/TWRP 12.1 트리(Android 12.1 기반)에는
# VNDK 35 스냅샷이 없습니다. 여기에 35 를 넣으면 sync 직후 빌드가 깨집니다.
# 리커버리는 VTS 대상이 아니므로 지정하지 않는 편이 안전합니다.
# PRODUCT_SHIPPING_API_LEVEL := 32
# PRODUCT_TARGET_VNDK_VERSION := 32

# 순정 지문 (스푸핑용, ro.product.build.fingerprint 그대로)
PRODUCT_BUILD_PROP_OVERRIDES += \
    TARGET_DEVICE=pdx256 \
    PRODUCT_NAME=pdx256 \
    PRIVATE_BUILD_DESC="pdx256-user 15 AQ3A.241126.002 SHIMANTO-1.1.0-REL-260522-1203 release-keys"

BUILD_FINGERPRINT := Sony/pdx256/pdx256:15/AQ3A.241126.002/SHIMANTO-1.1.0-REL-260522-1203:user/release-keys

# 순정 recovery 의 init.recovery.qcom.rc 를 그대로 사용
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.qcom.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.qcom.rc

# vendor blob (복호화용) - proprietary-files.txt / extract-blobs.sh 참고
include $(LOCAL_PATH)/blobs.mk
