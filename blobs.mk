LOCAL_PATH := device/sony/pdx256

# 암호화 blob 은 이제 recovery/root/system/{bin,lib64} 에 있습니다.
# TWRP 의 램디스크 조립 단계가 device tree 의 recovery/root 를 통째로 복사하므로
# (cp -rf device/sony/pdx256/recovery/root <out>/recovery/) 별도 규칙이 필요 없습니다.
# vendor/etc/vintf 의 매니페스트도 같은 경로로 함께 들어갑니다.
