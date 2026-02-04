#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common Omni stuff.
$(call inherit-product, vendor/twrp/config/common.mk)

# Inherit from pdx256 device
$(call inherit-product, device/sony/pdx256/device.mk)

PRODUCT_DEVICE := pdx256
PRODUCT_NAME := twrp_pdx256
PRODUCT_BRAND := Sony
PRODUCT_MODEL := Pdx256
PRODUCT_MANUFACTURER := sony

PRODUCT_GMS_CLIENTID_BASE := android-sony

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="pdx256-user 15 AQ3A.241126.002 SHIMANTO-1.1.0-REL-251117-0935 release-keys"

BUILD_FINGERPRINT := Sony/pdx256/pdx256:15/AQ3A.241126.002/SHIMANTO-1.1.0-REL-251117-0935:user/release-keys
