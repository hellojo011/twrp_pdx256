#!/system/bin/sh
#
# keymaster 키는 os_version / os_patchlevel / vendor_patchlevel 에 바인딩됩니다.
# 리커버리의 값이 키에 박힌 값과 어긋나면 TA 가 KEY_REQUIRES_UPGRADE(-62) 를
# 돌려주고, 이어지는 업그레이드가 -8 로 실패해 복호화가 무너집니다:
#   KeymasterUtils: IKMHal_sendCmd failed with rsp_header->status: -62
#   KeymasterUtils: IKMHal_sendCmd failed with rsp_header->status: -8
#   keystore2: Upgrade failed. / Error::Km(INCOMPATIBLE_BLOCK_MODE)
#   recovery: decryptWithKeystoreKey failed / read_key failed in mountFstab
#
# 실제 기기 값(2026-06-01 / 15)으로 "정확히 맞추는" 방식은 실패했습니다.
# 이 기기에서 실제로 복호화에 성공하는 TWRP 이미지를 뜯어보니 반대 방식이었습니다:
#   ro.build.version.release        = 16.1.0
#   ro.build.version.security_patch = 2099-12-31
#   ro.vendor.build.security_patch  = 2099-12-31
# (그 이미지의 prepdecrypt.sh 기본값도 osver_twrp=99.87.36 / 2099-12-31)
#
# keymaster 는 현재 값이 키에 박힌 값보다 "높으면" 업그레이드를 허용하고
# 낮으면 롤백으로 거부합니다. 미래 날짜로 밀어올리면 항상 전자가 됩니다.
#
# BoardConfig 에서 PLATFORM_SECURITY_PATCH 로 설정할 수 없습니다 -- android-14 의
# core/version_util.mk 가 ifdef 로 막고 하드 에러를 냅니다. ro. 속성은 한 번
# 설정되면 setprop 으로 못 바꾸므로 resetprop 을 씁니다.

for kv in \
    "ro.build.version.release 16.1.0" \
    "ro.build.version.security_patch 2099-12-31" \
    "ro.vendor.build.security_patch 2099-12-31" \
    "ro.boot.build.security_patch 2099-12-31"
do
    set -- $kv
    /system/bin/resetprop "$1" "$2"
done

exit 0
