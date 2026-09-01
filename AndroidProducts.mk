PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/twrp_pdx256.mk

# android-14 부터 lunch 형식이 <product>-<release>-<variant> 입니다.
# 이 트리의 release 는 ap2a (BUILD_ID=AP2A.240905.003).
COMMON_LUNCH_CHOICES := \
    twrp_pdx256-ap2a-eng \
    twrp_pdx256-ap2a-userdebug
