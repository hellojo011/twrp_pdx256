#!/bin/bash
#
# build/envsetup.sh 의 source_vendorsetup() 이 device/*/*/vendorsetup.sh 를
# 자동으로 source 합니다. (allowed-vendorsetup_sh-files 가 트리에 없으므로 전부 허용)
#
# OrangeFox_A14.sh 는 FOX_* 변수를 make 변수가 아니라 "셸 환경"에서 읽습니다
# (save_build_vars(): export | grep "FOX_"). 그래서 BoardConfig.mk 가 아니라
# 여기서 export 해야 합니다. 반대로 OF_MAINTAINER 는 orangefox.mk 가
# -DOF_MAINTAINER 로 컴파일에 박아넣는 make 변수라 BoardConfig.mk 에 둡니다.

export FOX_LOCAL_CALLBACK_SCRIPT="$(gettop)/device/sony/pdx256/fox_callback.sh"
