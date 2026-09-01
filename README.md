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

TWRP 내장 기능입니다. **전원 + 볼륨 다운** → 현재 저장소의 `screenshots/` 에 저장.
`/data` 가 안 풀린 상태면 외장 SD 로 갑니다.

```bash
adb pull /external_sd/screenshots/
```

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
