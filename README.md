# device/sony/pdx256 — TWRP device tree (초안)

Sony **pdx256** / Qualcomm **SM8750 ("sun")** / Android 15.
순정 `boot` · `vendor_boot` · `dtbo` · `recovery` 이미지에서 **직접 추출한 값**으로 만든 트리입니다.
추측한 값은 전부 `TODO` 로 표시했습니다.

## 이미지 분석 결과

| 이미지 | 형식 | 내용 |
|---|---|---|
| `recovery` | boot hdr **v4**, `kernel_size=0` | 램디스크만 19,775,596 B (LZ4 legacy), 497개 항목 |
| `boot` | boot hdr **v4**, `ramdisk_size=0` | 커널만 36,596,224 B (ARM64 `Image`, 비압축) |
| `vendor_boot` | vendor hdr **v4** | vendor ramdisk 9,024,227 B (fragment 1개, PLATFORM) + DTB 6,062,476 B + bootconfig 238 B |
| `dtbo` | DTBO v0 | 오버레이 71개, 총 20,847,248 B |

- 커널: `Linux version 6.6.92-android15-8-g6715ebef9908-ab14756967-4k` (GKI, 4K 페이지)
- 빌드: `Sony/pdx256/pdx256:15/AQ3A.241126.002/SHIMANTO-1.1.0-REL-260522-1203:user/release-keys`
- 보안 패치: 2026-06-01 / SDK 35 / `ro.product.cpu.abilist32` 비어 있음 (**64비트 전용**)
- Virtual A/B + 압축 스냅샷 + 동적 파티션
- vendor_boot DTB: Kera/KeraP/Sun/SunP/Tuna/TunaP SoC DTB 13종
- dtbo 오버레이 중 Sony 전용 fragment(`somc,*` / `sony,camera_modules`)를 가진 것은
  **index 43, 44, 45** (`Sun QRD SKU1`, `SKU1 V8 Power Grid`, `SKU2 V8 Power Grid`) 와 **56** (`SunP QRD HDK`)
- dtbo 안에 `com.android.build.dtbo.fingerprint = Sony/pdx256/...` 로 기기 확인됨

### 부팅 구조에서 중요한 점

`recovery.img` 에 커널이 없습니다. 리커버리 부팅 시:

```
boot.img 의 커널  +  vendor_boot 의 vendor ramdisk  +  recovery 파티션의 램디스크
```

가 합쳐집니다. 그래서 **커널 모듈 306개(`modules.load.recovery`)를 TWRP가 직접 챙길 필요가 없습니다.**
디스플레이(`msm_drm`, `dispcc-sun`, `panel_event_notifier`), 터치(`lxs_touchscreen`),
UFS(`ufs-qcom`, `ufshcd-crypto-qti`), ICE(`qcom_ice`) 모두 vendor_boot 쪽에서 로드됩니다.
→ TWRP 는 **램디스크만** 만들면 되고, 그래서 `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true` 가 필수입니다.

## 디렉터리

```
BoardConfig.mk                              보드 설정 (전부 추출값 기반)
AndroidProducts.mk / twrp_pdx256.mk         제품 정의
recovery/root/system/etc/recovery.fstab     TWRP fstab (순정 2종을 합침)
recovery/root/init.recovery.qcom.rc         순정 그대로
prebuilt/Image                              GKI 커널 (boot.img 에서 추출)
prebuilt/dtb.img                            vendor_boot 의 DTB
prebuilt/dtbo.img                           순정 dtbo (패딩 제거)
prebuilt/vendor_ramdisk.cpio.lz4            vendor_boot 램디스크 (참고용)
reference/                                  순정 fstab / rc / prop / 모듈 목록 원본
tools/lz4_legacy_unpack.py                  LZ4 legacy 램디스크 해제 (Windows용, 의존성 없음)
```

## 확인 완료된 값

- `super` 크기: **19327352832** (18 GiB) — 기기 `blockdev --getsize64` 확인
- 화면: **1080x2340** — 기기 `wm size` 확인 → `TW_THEME := portrait_hdpi` + `TARGET_SCREEN_*`
- super 그룹 이름: **`somc_dynamic_partitions`** (`qti_` 아님) — `super.sin` 의 LP 메타데이터 v10.2 에서 직접 확인
  - 논리 파티션: `system 999366656` / `system_ext 933154816` / `product 4054171648` /
    `vendor 1650360320` / `odm 2371584` / `vendor_dlkm 93687808` / `system_dlkm 12500992` (모두 `_a` 슬롯만 채워짐)

### super_*.sin 구조

`.sin` 은 **tar 컨테이너**입니다. `super.cms`(PKCS#7 서명) + `super.000`~`super.073`(Android sparse 조각).
주의: 청크 타입에 표준에 없는 **`0xCAC5` = LZ4 블록 압축 RAW** 가 섞여 있어
`simg2img` 로는 풀리지 않습니다. `tools/unpack_super.py` 가 이걸 처리합니다.

## TODO 3 — /data 복호화

`fileencryption=...wrappedkey_v0` + `metadata_encryption=aes-256-xts:wrappedkey_v0`,
즉 **하드웨어 래핑 키**입니다. 키가 TEE 밖으로 나오지 않으므로 TWRP 안에서
**keymint HAL 을 실제로 띄우는 것 말고는 방법이 없습니다.**

`super.sin` 에서 `vendor_a` 를 뽑아 실제로 확인한 사실:

- vintf 에 선언된 기본 HAL 은 `android.hardware.security.keymint` **v3 `IKeyMintDevice/default`**
  → `/vendor/bin/hw/android.hardware.security.keymint-service-qti` (TEE/TZ 경로)
- `keymint-service-spu-qti` 는 vintf 선언이 없는 **StrongBox** 인스턴스 → 불필요
- keymint 는 **`qseecomd` 가 먼저 떠 있어야** 동작 (TA 로드)
- keymaster TA 이미지는 vendor 안이 아니라 **modem 파티션**에 있고 `/vendor/firmware_mnt` 로 마운트됨
  → `recovery.fstab` 의 `firmware_mnt` 항목이 필수 (이미 넣어둠)

필요한 blob 은 keymint HAL 바이너리의 `DT_NEEDED` 를 재귀적으로 따라가 폐포를 구했습니다
(`proprietary-files.txt`, **32개**). `libc/libdl/liblog/libm/libbinder_ndk/libvndksupport` 6개만
vendor 밖이고 TWRP 램디스크에 이미 있습니다.

작업 순서 — 이 환경(Windows)에서 실행하는 방법:

```
# PowerShell (추가 설치 불필요)
powershell -ExecutionPolicy Bypass -File .\extract-blobs.ps1

# 또는 Git Bash
"C:/Program Files/Git/bin/bash.exe" ./extract-blobs.sh
```

**WSL 에서는 실행하지 마세요.** WSL2 는 기본적으로 USB 를 못 보기 때문에 기기가 안 잡힙니다.
꼭 WSL 에서 돌려야 한다면 Windows 쪽 adb 를 넘겨주세요:

```
ADB=/mnt/c/Android/Sdk/platform-tools/adb.exe ./extract-blobs.sh
```

두 스크립트 모두 `adb exec-out` 을 씁니다. `adb shell` 로 받으면 개행 변환 때문에
`.so` 파일이 깨지므로 절대 바꾸지 마세요. 스크립트 끝에서 ELF 헤더(`7f454c46`)를 검사합니다.

`blobs.mk` 가 `recovery/root/vendor/` 를 통째로 램디스크에 복사하고,
`recovery/root/system/etc/init/init.recovery.crypto.rc` 가 `qseecomd` → `keymint` 순서로 띄웁니다.

남은 변수 두 가지:

1. **SELinux** — TWRP 는 자체 정책으로 도는데 `qseecomd`/`vendor_keymint` 도메인이 없으면
   HAL 이 죽습니다. 첫 시도는 permissive 로 확인하고, 붙으면 도메인을 추가하세요.
   (`/sepolicy` 는 순정 recovery 램디스크에서 뽑아둔 것이 1.4MB 있습니다)
2. **`metadata_encryption`** — `/metadata` 를 먼저 마운트해야 `/metadata/vold/metadata_encryption`
   의 키를 읽습니다. fstab 순서상 `/data` 보다 앞에 있어야 하며 이미 그렇게 넣어뒀습니다.

붙었는지 확인은 TWRP 터미널에서:

```
logcat -s vold keystore2 qseecomd
```

## TODO 4 — vendor/twrp

특별한 작업이 없습니다. TWRP 최소 매니페스트를 받으면 `vendor/twrp` 가 같이 딸려옵니다.

```
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags
```

동기화 후 `vendor/twrp/config/common.mk` 가 존재하는지만 확인하면 됩니다.

**빌드는 반드시 WSL(Ubuntu-20.04) 안에서** 하세요. AOSP/TWRP 빌드 시스템은 Windows 에서 돌지 않습니다.
그리고 소스는 **WSL 의 ext4 홈 디렉터리에 두어야** 합니다:

```
~/twrp        O   (ext4, 대소문자 구분)
/mnt/d/...    X   (DrvFs. 대소문자 구분이 안 돼 빌드가 깨지고, 속도도 수 배 느립니다)
```

이 디바이스 트리만 `/mnt/d` 에서 복사해 넣으면 됩니다:

```
cp -r /mnt/d/Xperia/Recovery/device/sony ~/twrp/device/
```
Android 15(SDK 35) 대상이라 `twrp-12.1` 브랜치에서 빌드 오류가 나면
`twrp-14.1` 매니페스트가 있는지 확인하고 그쪽을 쓰세요.

## 빌드

```
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags
# 이 트리를 device/sony/pdx256 에 배치
. build/envsetup.sh && lunch twrp_pdx256-eng && mka recoveryimage
```

## 플래시 (언락 필요, 주의)

```
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
fastboot flash recovery out/target/product/pdx256/recovery.img
```

- Sony 부트로더 언락 시 **DRM 키가 소거**됩니다 (카메라 화질 등 일부 기능 영구 저하).
- Virtual A/B 기기이므로 슬롯(`_a`/`_b`)을 확인하고 플래시하세요.
- vbmeta 를 함께 처리하지 않으면 수정된 recovery 는 AVB 검증에서 막혀 부팅하지 않습니다.
