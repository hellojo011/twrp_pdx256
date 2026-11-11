#!/usr/bin/env python3
"""순정 진동 HAL 을 리커버리에서 돌도록 2군데 패치한다.

대상: vendor/bin/hw/android.hardware.vibrator-service.cs40l25 (B083 펌웨어, 153784 bytes)

왜 필요한가
-----------
순정에서 벤더 프로세스는 libbinder 를 두 벌 갖는다. 벤더용 사본(/dev/vndbinder)과
libbinder_ndk 가 쓰는 시스템용(/dev/binder)이 서로 다른 링커 네임스페이스에 있다.
이 HAL 의 main 은 그 전제로 짜여 있다:

    ProcessState::initWithDriver("/dev/vndbinder")      # 벤더 사본
    AServiceManager_addService(...)                      # 시스템 쪽 (ndk)
    ProcessState::self()->setThreadPoolMaxThreadCount(n) # 벤더 사본
    ProcessState::self()->startThreadPool()              # 벤더 사본
    ABinderProcess_setThreadPoolMaxThreadCount(0)        # 시스템 쪽 (ndk)
    ABinderProcess_joinThreadPool()

리커버리는 네임스페이스가 하나라 libbinder 인스턴스도 하나다. 그래서

  1) 통계 스레드가 먼저 /dev/binder 로 초기화한 뒤 main 이 /dev/vndbinder 를
     요구해서 죽는다:
       F ProcessState: ProcessState was already initialized with /dev/binder,
                       can't initialize with /dev/vndbinder.
     -> 문자열 "/dev/vndbinder" 를 "/dev/binder" 로 바꾼다. 비교가 드라이버
        이름 문자열로 이뤄지므로 같은 이름이면 통과한다.

  2) 같은 인스턴스에서 startThreadPool() 뒤에 최대 스레드 수를 0 으로 줄이려다
     죽는다:
       F ProcessState: Binder threadpool cannot be shrunk after starting
     -> 0xeec8 의 bl ABinderProcess_setThreadPoolMaxThreadCount 를 NOP 으로 바꾼다.
        반환값은 검사되지 않고 바로 joinThreadPool 로 넘어간다.

두 패치 뒤 HAL 은 IVibrator/default 를 servicemanager 에 등록하고 유지된다
(기기에서 확인).

사용법:  python tools/patch_vibrator_hal.py <stock HAL> <out>
"""
import sys

PATCHES = [
    # (file offset, 기대하는 원본 바이트, 바꿀 바이트, 설명)
    (0x4D98, b"/dev/vndbinder\x00", b"/dev/binder\x00\x00\x00\x00", "driver name string"),
    (0xEEC8, bytes.fromhex("d83e0094"), bytes.fromhex("1f2003d5"),
     "bl ABinderProcess_setThreadPoolMaxThreadCount -> nop"),
]
EXPECTED_SIZE = 153784


def main(src, dst):
    d = bytearray(open(src, "rb").read())
    if len(d) != EXPECTED_SIZE:
        sys.exit(f"크기가 다르다: {len(d)} (기대 {EXPECTED_SIZE}). 다른 펌웨어의 HAL 이면 오프셋을 다시 찾아야 한다.")
    for off, old, new, what in PATCHES:
        cur = bytes(d[off:off + len(old)])
        if cur == new:
            print(f"  이미 적용됨  {off:#06x}  {what}")
            continue
        if cur != old:
            sys.exit(f"{off:#x} 의 바이트가 예상과 다르다: {cur.hex()} (기대 {old.hex()})")
        d[off:off + len(old)] = new
        print(f"  패치        {off:#06x}  {what}")
    with open(dst, "wb") as f:
        f.write(d)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
