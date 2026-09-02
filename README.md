# device/sony/pdx256 — OrangeFox / TWRP device tree

Sony **pdx256** · Qualcomm **SM8750 ("sun")** · Android 15 · 1080x2340

부팅하고, 메뉴가 뜨고, **`/data` 복호화 패턴 입력까지 도달하는** 상태입니다.

빌드 베이스는 **OrangeFox 14.1** (`twrp-14`, android-14). 12.1은 매니페스트가
스스로 모순이라(라이브러리는 지우고 소비자 코드는 남김) 포기했습니다.

---

## 빌드

```bash
repo init -u https://github.com/nebrassy/platform_manifest_twrp_aosp.git -b twrp-14 \
          --depth=1 --repo-rev=v2.54 --no-repo-verify
cd ~/orangefox/sync && ./orangefox_sync.sh --branch 14.1 --path ~/OrangeFox_14.1
git clone <this repo> ~/OrangeFox_14.1/device/sony/pdx256
cd ~/OrangeFox_14.1
source build/envsetup.sh
lunch twrp_pdx256-ap2a-eng
mka adbd recoveryimage
```

* `--repo-rev=v2.54` 없으면 `repo init` 이 실패합니다. `twrp-14` 매니페스트는
  `name=` 없이 `path=` 만 쓰는 `<remove-project>` 를 686개 갖고 있는데, 구형
  repo(v1.13.11)는 그 문법을 모릅니다.
* lunch 는 android-14 형식 `<product>-<release>-<variant>` 입니다. release 는 `ap2a`.
* `lunch` 에 파이프를 걸지 마세요. 서브셸에서 돌아 `TARGET_RELEASE` 가 안 남습니다.
* WSL 이면 소스를 ext4 홈에 두세요. `/mnt/...` 는 대소문자 구분이 안 돼 빌드가 깨집니다.

---

## 기기 사실 (전부 순정 이미지에서 추출한 값)

| | |
|---|---|
| recovery.img | boot header **v4**, `kernel_size=0` — **램디스크 전용** |
| 커널 | `6.6.92-android15-8` GKI, boot.img 에서 옴 |
| super | 19327352832 (18 GiB), 그룹 이름 **`somc_dynamic_partitions`** |
| 화면 | 1080x2340 |
| 암호화 | metadata(`wrappedkey_v0`) + FBE, 2층 구조 |

`recovery` 파티션에는 램디스크만 들어갑니다. `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE`
가 그래서 필수입니다.

리커버리 부팅 시 `boot.img` 커널 + `vendor_boot` 램디스크 + 이 램디스크가 합쳐지고,
**커널 모듈 306개가 vendor_boot 의 `modules.load.recovery` 로 자동 로드**됩니다
(디스플레이 `msm_drm`, 터치 `lxs_touchscreen` 포함). 모듈 이식이 필요 없습니다.

---

## `/data` 복호화

TWRP 의 QCOM 복호화 인프라를 씁니다. OrangeFox 14.1 트리에는 이 파일들이 없어서
동작하는 TWRP 이미지에서 이식했습니다.

```
init.recovery.qcom.rc  →  import /init.recovery.qcom_decrypt.rc
      prepdecrypt.sh  →  crypto.ready=1
      →  qseecomd  →  vendor.sys.listeners.registered=true
      →  keymint + gatekeeper  →  keystore2  →  패턴 입력
```

vendor blob 46개는 **pdx256 자체 vendor 파티션**에서 뽑았고 `/vendor/bin(/hw)`,
`/vendor/lib64` 에 둡니다. `/system` 이 아닌 이유: 이 세트에는 vendor 버전
`libc++`(`__libcpp_verbose_abort` 보유), `libbase`, `libcrypto` 가 포함되는데
`/system/lib64` 에 두면 Android 14 로 빌드된 TWRP 바이너리를 깨뜨립니다.
rc 의 `LD_LIBRARY_PATH` 가 `/vendor/lib64` 를 먼저 보므로 vendor 프로세스에만 적용됩니다.

### 실제로 막았던 두 가지 — 둘 다 디바이스 노드 권한

**`/dev/smcinvoke`** (`0660 system drmrpc`)
qseecomd 는 자기 확인용으로 root 로 한 번 열고, fork 한 자식이 권한을 낮춘 뒤
`libminkdescriptor` 로 다시 엽니다. 노드가 커널 기본값 `root:root 0600` 이면 거기서 EACCES:

```
QSEECOMD: SUCCESS: While opening the device /dev/smcinvoke   <- 첫 open (root)
SmcInvoke_MinkDescriptor: Failed to open invoke driver, errno = 13
ListenerMngr: Error -1 getting clientEnv
```

**`/dev/0:0:0:49476`** (`0600 system system`) — UFS RPMB LUN

```
rpmb_ufs: Unable to open /dev/0:0:0:49476 (error no: 13)
KeyMasterHalDevice: upgrade_key / ret: -8
keystore2: Upgrade failed. / Error::Km(INCOMPATIBLE_BLOCK_MODE)
I:Unable to decrypt metadata encryption
```

RPMB 는 keymaster 의 롤백 방지 카운터 저장소입니다. 여기 접근이 막히면
`KEY_REQUIRES_UPGRADE(-62)` 를 영원히 해소할 수 없습니다.
**오류 이름에 속아 패치 레벨을 두 번 헛짚었습니다. 원인은 두 줄 위에 있었습니다.**

노드를 하나씩 쫓는 대신 **순정 `vendor/etc/ueventd.rc` 전문(441줄)** 을 넣었습니다.

### 그 외 필요했던 것

* `vendor.gatekeeper.is_security_level_spu=0` — 순정은 `init.qti.keymaster.sh` 가
  soc_id(618)를 보고 세웁니다. 없으면 keymint 가 초기화 후 등록하지 않고 멈춥니다.
* `fix_patchlevel.sh` — `16.1.0` / `2099-12-31`. keymaster 는 현재 값이 키보다
  앞서면 업그레이드를 허용하고 뒤처지면 롤백으로 거부합니다.
  `PLATFORM_SECURITY_PATCH` 는 android-14 의 `version_util.mk` 가 `ifdef` 로 막으므로
  `resetprop` 을 씁니다.
* `libqtigatekeeper.so` 를 `/vendor/lib64` 에도 둡니다 — `DT_NEEDED` 라 링커가
  `hw/` 를 보지 않습니다.
* `task_profiles.json` — 없으면 `logd` 가 `DropPrivs()` 에서 abort 합니다.
  logd 없이는 keystore2 의 panic 메시지를 볼 수 없습니다.

---

## UI 주변 기능

### 배터리 잔량 — ADSP 를 띄워야 합니다

SM8750 은 연료게이지와 충전기가 **ADSP 의 충전 펌웨어 뒤에** 있습니다.
`qti_battery_charger` 모듈이 로드되어 있어도 `pmic_glink` 로 ADSP 에 붙은
뒤에야 `/sys/class/power_supply/battery` 를 등록합니다. 리커버리는 ADSP 를
띄우지 않으므로 `power_supply` 클래스가 통째로 비고, 잔량이 `-1%` 로 나옵니다.
**sysfs 경로를 아무리 지정해도 해결되지 않습니다** — 데이터 소스 자체가 없습니다.

ADSP 기동을 막는 것은 SELinux 입니다:

```
avc: denied { open } path="/firmware_mnt/image/adsp.mdt"
     scontext=u:r:kernel:s0 tcontext=u:object_r:vfat:s0 permissive=0
```

커널 펌웨어 로더는 `u:r:kernel:s0` 자격으로 파일을 엽니다. 순정처럼
`context=u:object_r:firmware_file:s0` 으로 마운트하려 해도 **그 타입이 리커버리
정책에 없어서** `mount` 가 `EINVAL` 로 실패합니다. 실측한 정책 보유 타입:

| 타입 | 리커버리 정책 |
|---|---|
| `vfat`, `tmpfs` | 있음 (그러나 kernel 이 읽지 못함) |
| `firmware_file`, `system_file` | **없음** |
| `rootfs` | 있고 **kernel 이 읽을 수 있음** |

그래서 `adsp_boot.sh` 가 modem 파티션에서 펌웨어를 읽어 `/lib/firmware`(rootfs)
로 복사한 뒤 거기서 로드합니다. 약 21MB, Enforcing 상태 그대로 동작합니다.
같은 기법이 다른 remoteproc 펌웨어에도 그대로 적용됩니다.

`TW_USE_LEGACY_BATTERY_SERVICES := true` 도 필요합니다. `twrp.cpp:565` 는 이
플래그가 있을 때만 sysfs 를 직접 읽고, 없으면 health HAL 로 가는데 이 기기는
리커버리에서 health@2.0 이 제대로 올라오지 않습니다.

### 시계

`Android.mk:430-438` 의 화이트리스트가 `msm8226`~`msm8998` 까지라
`TARGET_BOARD_PLATFORM := sun` 은 `QCOM_RTC_FIX` 가 정의되지 않습니다.
그러면 `Fixup_Time_On_Boot()` 본체가 통째로 컴파일에서 빠져(두 변형 모두
`#ifdef QCOM_RTC_FIX` 로 감싸여 있습니다) 리커버리가 시각을 아예 세팅하지
않습니다. `TARGET_RECOVERY_QCOM_RTC_FIX := true` 로 켭니다.

타임존은 별개입니다. `orangefox.mk:571` 의 `OF_DEFAULT_TIMEZONE` 기본값이
`CET-1;CEST,...`(중앙유럽) 이라 `OF_DEFAULT_TIMEZONE := KST-9` 로 바꿉니다.
**타임존만으로는 못 고칩니다** — 오프셋은 시 단위라 분까지 어긋나는 증상은
기준 시각이 없다는 뜻입니다.

### About 의 메인테이너 카드

테마에 이미 있습니다. `pages/settings.xml` 의 About 페이지가 `of_maintainer`
가 1/2/3(OrangeFox 개발자 본인) 이 **아닐 때만** "Unofficial maintainer" 카드를
그립니다. `OF_MAINTAINER := DIGIWB` 만 넣으면 카드가 뜹니다.

아바타는 그 카드의 `maintainer_img`, 즉 램디스크의
`twres/images/Default/About/maintainer.png` 입니다. 테마 원본은
`bootable/recovery` 안이라 `repo sync` 때 날아가므로 **같은 경로를
`recovery/root/` 아래에 둡니다.** `build/make/core/Makefile` 의 리커버리 이미지
레시피가

```
2773  rsync (베이스 램디스크)
2780  OrangeFox_A14.sh (테마/램디스크 가공)
2815  cp -rf $(recovery_root_private) $(TARGET_RECOVERY_OUT)/
```

순서로 돌기 때문에 `recovery/root/` 가 **항상 마지막에 이깁니다.** 환경변수도
필요 없습니다. (`FOX_LOCAL_CALLBACK_SCRIPT` 훅도 있지만 그건 make 변수가 아니라
셸 환경에서 읽히므로, `vendorsetup.sh` 가 생기기 전에 `envsetup.sh` 를 source 한
셸에서 빌드하면 조용히 건너뜁니다.)

**PNG 규격 주의.** `minuitwrp/resources.cpp` 는 `png_get_IHDR` 에서
`interlace_type` 을 `NULL` 로 버리고 `png_set_interlace_handling()` 도 부르지
않은 채 `png_read_row()` 로 순차 읽기만 합니다. **Adam7 인터레이스 PNG 는 화면에
아무것도 안 뜹니다.** 순정 테마 이미지와 동일하게 192x192, 8bit RGBA,
비인터레이스여야 합니다.

### 백업 목록 — `twrp.flags` 가 필요합니다

`recovery.fstab`(v2) 의 인라인 `;flags=...;backup=1` 만으로는 백업 화면에
Data 와 Super 만 떴습니다. TWRP 는 `/etc/twrp.flags`(v1 포맷) 를 따로 읽어
목록을 채웁니다(`partitionmanager.cpp:360`). EFS/TA 계열은 이쪽에 넣습니다.

이 기기의 EFS 상당물은 **Sony TrimArea(`TA`)** 입니다 — IMEI, DRM 키, 캘리브레이션,
부트로더 언락 상태. 순정 `init.rc` 의 `tad` 서비스가 여는 파티션입니다.
`modemst1` / `modemst2` / `fsg` / `fsc` / `LTALabel` 도 실재를 확인했습니다.

`TA` 에는 `flashimg` 를 주지 않았습니다. 임의 이미지를 굽는 건 벽돌 직행입니다.

### 진동 — 없습니다

이 기기의 진동자는 PMIC 햅틱이 아니라 **Cirrus Logic CS40L25A**(I2C `6-0040`)
입니다. 순정 dtbo 조차 `qcom,hv-haptics` 를 `status="disable"` 로 둡니다.

커널 계층은 이식에 성공했습니다 — `cirrus_wm_adsp.ko` + `cirrus_cs40l2x.ko`
(vendor_dlkm) 와 DSP 펌웨어(vendor:`/firmware/cs40l25a_*`) 를 올리면
`/sys/class/leds/cs40l25:vibrator` 가 생깁니다. 막힌 곳은 벤더 HAL 입니다:

```
E Vibrator: miscta_get_unit_size: id=4730 error 1
init: Service 'vendor.vibrator.cs40l25' received signal 11
```

HAL 이 진동 캘리브레이션을 Sony TA 에서 읽는데 리커버리에는 그걸 중개하는
`tad` 데몬도 `/dev/socket/tad` 도 없습니다. **남은 작업은 `tad` 이식입니다.**

**HAL 이 없을 때의 비용을 반드시 알아두십시오.** `events.cpp:162` 는 터치마다
`AServiceManager_getService(kVibratorInstance)` 를 호출하고, 서비스가 없으면
최대 5초를 블로킹합니다. 즉 "진동이 안 되는" 정도가 아니라 **UI 전체가 멎습니다.**
그래서 `TW_NO_HAPTICS := true` 로 호출 경로 자체를 없앴습니다.
(sysfs 백엔드는 `/sys/class/leds/vibrator/activate` 로 경로가 하드코딩돼 있어
`cs40l25:vibrator` 와 매치되지 않고, sysfs 에는 심볼릭 링크를 만들 수 없습니다.)

전체 이식 시도와 blob 은 `git log --all --grep=CS40L25A` 로 찾을 수 있습니다.

---

## 알아둘 함정

**`:= false` 가 켜는 플래그가 있습니다.** `ifdef` 로 검사하는 것들입니다.

| 플래그 | 검사 | 결론 |
|---|---|---|
| `BOARD_INCLUDE_DTB_IN_BOOTIMG` | `ifdef` ×7 | **정의하지 말 것** |
| `BOARD_INCLUDE_RECOVERY_DTBO` | `ifdef` ×4 | **정의하지 말 것** |
| `TW_INCLUDE_CRYPTO` | `ifeq` + `ifneq(,)` | 끄려면 정의 자체를 지울 것 |
| `TARGET_SUPPORTS_32_BIT_APPS` 등 | `ifeq` | `false` 안전 |

**`TW_INCLUDE_FBE_METADATA_DECRYPT := false` 는 효과가 없습니다.**
`Android.mk:348` 이 `TW_INCLUDE_CRYPTO` 가 켜져 있으면 `-DTW_INCLUDE_FBE_METADATA_DECRYPT`
를 무조건 붙입니다.

**android-14 가 막는 변수들** — `PLATFORM_SECURITY_PATCH`, `PLATFORM_SDK_VERSION`,
`TARGET_PLATFORM_VERSION` 은 `ifdef` 하드 에러입니다. 구형 디바이스 트리에서
복사해 오면 빌드가 즉시 죽습니다.

**`PRODUCT_USE_DYNAMIC_PARTITIONS`** 는 제품 변수라 BoardConfig 에 쓰면 readonly 에러입니다.

**`$(LOCAL_PATH)`** 는 제품 makefile 에서 자동 정의되지 않습니다. 직접 지정해야 합니다.

---

## 도구

`tools/` 는 전부 파이썬 표준 라이브러리만 씁니다. Windows 에 `lz4` 도 `7z` 도 없어서
만들었고, 펌웨어가 갱신돼도 같은 방식으로 재현됩니다.

| | |
|---|---|
| `lz4_legacy_unpack.py` | LZ4 legacy 해제 (램디스크, super sparse) |
| `unpack_super.py` | `super_*.sin` → 논리 파티션. **`.sin` 은 tar 컨테이너**이고 청크에 표준에 없는 `0xCAC5`(LZ4 압축 RAW)가 섞여 있어 `simg2img` 로는 안 풀립니다 |
| `ext4_reader.py` | ext4 이미지에서 파일 목록/추출 |
| `elf_deps.py` | `DT_NEEDED` 재귀 추적 |

`DT_NEEDED` 만으로는 부족합니다. `qseecomd` 는 TZ 리스너 10개를 **`dlopen`** 으로
로드하므로 ELF 의존성 테이블에 안 나옵니다. 바이너리 문자열에서 뽑아야 합니다.

---

## 스크린샷

TWRP 내장 기능이 있습니다 — `gui/gui.cpp:293` 이 볼륨다운+전원을 **200ms 이상 함께**
누른 것을 감지해 `GUIAction::screenshotImpl()` 을 부릅니다. 저장 위치는
`Fox_Home/screenshots/`, 즉 이 기기에서는 `/sdcard/Fox/screenshots/` 입니다
(디렉터리를 못 만들면 `/tmp/` 로 폴백).

**손으로 누르면 잘 안 잡힙니다.** 전원 키가 먼저 들어가면 화면 토글로 소비되기
때문입니다. 볼륨다운을 먼저 누르고, 누른 채로 전원을 추가한 뒤 1초쯤 유지하십시오.

확실한 방법은 `sendevent` 로 그 순서대로 주입하는 것입니다:

```bash
powershell -ExecutionPolicy Bypass -File .\tools\screenshot.ps1
```

키 배치는 `/proc/bus/input/devices` 의 `B: KEY=` 비트맵에서 확인했습니다.
비트맵은 64비트 워드를 **상위부터** 나열하므로, 마지막 워드가 키코드 0-63 입니다.

| 장치 | 이벤트 | 비트맵 | 키코드 |
|---|---|---|---|
| `gpio-keys` | `event1` | `4000000000000` (2^50, 워드1) | 64+50 = 114 `KEY_VOLUMEDOWN` |
| `pmic_resin` | `event2` | `8000000000000` (2^51, 워드1) | 64+51 = 115 `KEY_VOLUMEUP` |
| `pmic_pwrkey` | `event3` | `10000000000000` (2^52, 워드1) | 64+52 = 116 `KEY_POWER` |

이 기기에는 `/dev/graphics/fb0` 이 없습니다. DRM(`/dev/dri/card0`) 을 쓰므로
프레임버퍼를 밖에서 직접 덤프하는 방법은 쓸 수 없습니다. 리커버리가 DRM 마스터를
쥐고 있는 동안에는 TWRP 자신에게 찍게 하는 것이 유일한 방법입니다.

## 로그 뽑기

`logcat` 은 `task_profiles.json` 덕에 동작합니다. 문제 생기면 세 개 다 필요합니다 —
keystore2 의 panic 은 logcat 에, init/logd 의 FATAL 은 **dmesg** 에 남습니다.

```bash
adb shell "dmesg > /external_sd/dmesg.log; logcat -d > /external_sd/logcat.log; cp /tmp/recovery.log /external_sd/"
```

## blob 다시 뽑기

```bash
powershell -ExecutionPolicy Bypass -File .\extract-blobs.ps1   # 루팅된 기기에서
```

`adb exec-out` 을 씁니다. `adb shell` 로 받으면 개행 변환으로 `.so` 가 깨집니다.
기기가 리커버리에 있으면 `/vendor` 는 램디스크뿐이므로, `tools/unpack_super.py` 로
`super_*.sin` 에서 뽑는 편이 확실합니다 (바이트 동일함을 sha256 으로 확인했습니다).

## 플래시

```bash
fastboot flash recovery recovery.img
```

* 언락 시 **Sony DRM 키가 영구 소거**됩니다.
* 수정된 이미지를 부팅하려면 `vbmeta` 를
  `--disable-verity --disable-verification` 으로 함께 플래시해야 합니다.
* Virtual A/B 이므로 슬롯(`fastboot getvar current-slot`)을 확인하세요.
* 순정 `recovery.img` 는 복구용으로 보관하세요.
