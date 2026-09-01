#
# twrp_pdx256.mk - Sony pdx256 (SM8750 / "sun")
#

# 64비트 전용 기기 (abilist32 이 비어 있음)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

PRODUCT_DEVICE := pdx256
PRODUCT_NAME := twrp_pdx256
PRODUCT_BRAND := Sony
PRODUCT_MODEL := Pdx256
PRODUCT_MANUFACTURER := Sony
PRODUCT_RELEASE_NAME := pdx256

PRODUCT_SHIPPING_API_LEVEL := 35
PRODUCT_TARGET_VNDK_VERSION := 35

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
