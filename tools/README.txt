Windows에서 외부 도구 없이(파이썬만으로) 순정 이미지를 뜯기 위한 스크립트들입니다.

lz4_legacy_unpack.py  LZ4 legacy 프레임 해제 (램디스크, super sparse 청크)
unpack_super.py       super_*.sin 파싱 + 논리 파티션 추출
ext4_reader.py        ext4 이미지에서 파일 목록/추출
elf_deps.py           ELF DT_NEEDED 재귀 추적 (blob 목록 만들 때 사용)

super_*.sin 구조 (분석 결과):
  tar 컨테이너
   └ super.cms          PKCS#7 서명
   └ super.000..073     Android sparse 이미지 조각
        청크 타입 0xCAC1 RAW / 0xCAC2 FILL / 0xCAC3 DONT_CARE
                  0xCAC5 = LZ4 블록 압축 RAW  <- Sony 확장, simg2img 로는 안 풀림
  전체 4718592 블록 x 4096 = 19327352832 bytes

예) vendor 뽑기
  python unpack_super.py                 # 파티션 목록
  python -c "import unpack_super as s; sp=s.Super(); md=s.metadata(sp); s.extract(sp,md,'vendor_a','vendor.img')"
  python ext4_reader.py                  # vendor.img 파일 목록
