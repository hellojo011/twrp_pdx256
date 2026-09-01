import struct, sys

def lz4_block_decompress(src, max_out=8*1024*1024):
    out = bytearray()
    i = 0; n = len(src)
    while i < n:
        token = src[i]; i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]; i += 1
                lit += b
                if b != 255: break
        out += src[i:i+lit]; i += lit
        if i >= n: break
        off = src[i] | (src[i+1] << 8); i += 2
        ml = token & 0xF
        if ml == 15:
            while True:
                b = src[i]; i += 1
                ml += b
                if b != 255: break
        ml += 4
        start = len(out) - off
        for k in range(ml):
            out.append(out[start + k])
    return bytes(out)

def legacy_decompress(data):
    assert data[:4] == b'\x02\x21\x4c\x18', data[:4].hex()
    i = 4
    out = bytearray()
    while i + 4 <= len(data):
        bsz = struct.unpack('<I', data[i:i+4])[0]
        if bsz in (0x184C2102, 0x184D2204) or bsz == 0 or bsz > 8*1024*1024:
            break
        i += 4
        out += lz4_block_decompress(data[i:i+bsz])
        i += bsz
    return bytes(out)

if __name__ == '__main__':
    d = open(sys.argv[1], 'rb').read()
    open(sys.argv[2], 'wb').write(legacy_decompress(d))
