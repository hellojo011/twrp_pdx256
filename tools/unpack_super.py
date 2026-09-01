import struct, tarfile, sys
from lz4_legacy_unpack import lz4_block_decompress

SIN = 'D:/Xperia/Recovery/super_X-FLASH-ALL-B083.sin'
RAW, FILL, DONT_CARE, CRC32, LZ4 = 0xCAC1, 0xCAC2, 0xCAC3, 0xCAC4, 0xCAC5

def build_map():
    t = tarfile.open(SIN)
    parts = sorted((m.name, m.offset_data) for m in t.getmembers()
                   if m.name.startswith('super.') and not m.name.endswith('.cms'))
    f = open(SIN, 'rb'); segs = []; blk_sz = None; total = None
    for name, off in parts:
        f.seek(off)
        magic, maj, mnr, fhs, chs, bs, tb, tc, _ = struct.unpack('<IHHHHIIII', f.read(28))
        assert magic == 0xed26ff3a
        blk_sz, total = bs, tb
        pos = off + fhs; cur = 0
        for _ in range(tc):
            f.seek(pos)
            ctype, _r, csz, tsz = struct.unpack('<HHII', f.read(12))
            d = pos + chs
            if ctype == RAW:   segs.append((cur, csz, 'raw', d))
            elif ctype == LZ4: segs.append((cur, csz, 'lz4', (d, tsz - chs)))
            elif ctype == FILL:
                f.seek(d); segs.append((cur, csz, 'fill', f.read(4)))
            elif ctype in (DONT_CARE, CRC32): pass
            else: raise SystemExit('unknown chunk %#x in %s' % (ctype, name))
            cur += csz; pos += tsz
    segs.sort()
    return blk_sz, total, segs

class Super:
    def __init__(self):
        self.bs, self.total, self.segs = build_map()
        self.f = open(SIN, 'rb'); self.cache = {}
    def _seg(self, blk):
        lo, hi = 0, len(self.segs)
        while lo < hi:
            mid = (lo + hi) // 2
            if self.segs[mid][0] <= blk: lo = mid + 1
            else: hi = mid
        return self.segs[lo-1] if lo else None
    def read(self, offset, length):
        out = bytearray()
        while length > 0:
            blk, inb = divmod(offset, self.bs)
            s = self._seg(blk)
            if s is None or blk >= s[0] + s[1]:
                take = min(length, self.bs - inb); out += b'\x00' * take
            else:
                start, n, kind, pay = s
                avail = (start + n) * self.bs - (blk * self.bs + inb)
                take = min(length, avail)
                if kind == 'raw':
                    self.f.seek(pay + (blk - start) * self.bs + inb); out += self.f.read(take)
                elif kind == 'fill':
                    out += (pay * (take // 4 + 2))[:take]
                else:
                    d = self.cache.get(start)
                    if d is None:
                        self.f.seek(pay[0]); d = lz4_block_decompress(self.f.read(pay[1]))
                        self.cache = {start: d}
                    o = (blk - start) * self.bs + inb; out += d[o:o+take]
            offset += take; length -= take
        return bytes(out)

def metadata(sp):
    g = sp.read(4096, 4096)
    assert g[:4] == b'\x67\x44\x6c\x61', g[:4]
    _, ssz = struct.unpack('<II', g[:8])
    md_max, slots = struct.unpack('<II', g[40:48])
    lbs, = struct.unpack('<I', g[48:52])
    base = 4096 * 3
    h = sp.read(base, 256)
    assert h[:4] == b'\x30\x50\x4c\x41', h[:4]
    maj, mnr, hsz = struct.unpack('<HHI', h[4:12])
    tsz, = struct.unpack('<I', h[44:48])
    o = 80
    desc = [struct.unpack('<III', h[o+i*12:o+12+i*12]) for i in range(4)]
    tables = sp.read(base + hsz, tsz)
    return dict(md_max=md_max, slots=slots, lbs=lbs, ver=(maj, mnr), desc=desc, tables=tables)

def partitions(md):
    (poff, pn, pe), (eoff, en, ee), (goff, gn, ge), (boff, bn, be) = md['desc']
    T = md['tables']
    ext = []
    for i in range(en):
        b = T[eoff+i*ee: eoff+i*ee+ee]
        ns, tt, td, ts = struct.unpack('<QIQI', b[:24])
        ext.append((ns, tt, td, ts))
    groups = []
    for i in range(gn):
        b = T[goff+i*ge: goff+i*ge+ge]
        groups.append((b[:36].rstrip(b'\x00').decode(), struct.unpack('<Q', b[36:44])[0]))
    devs = []
    for i in range(bn):
        b = T[boff+i*be: boff+i*be+be]
        fls, al, alo, size = struct.unpack('<QIIQ', b[:24])
        devs.append((b[24:60].rstrip(b'\x00').decode(), fls, size))
    out = []
    for i in range(pn):
        b = T[poff+i*pe: poff+i*pe+pe]
        name = b[:36].rstrip(b'\x00').decode()
        attr, fe, ne, gi = struct.unpack('<IIII', b[36:52])
        exts = ext[fe:fe+ne]
        out.append((name, attr, gi, exts))
    return out, groups, devs

if __name__ == '__main__':
    sp = Super()
    print('super: block_size=%d total=%d bytes, %d segments' % (sp.bs, sp.total * sp.bs, len(sp.segs)))
    md = metadata(sp)
    print('LP metadata v%d.%d  max=%d slots=%d logical_block_size=%d' % (md['ver'][0], md['ver'][1], md['md_max'], md['slots'], md['lbs']))
    parts, groups, devs = partitions(md)
    print('groups:', groups)
    print('block_devices:', devs)
    for name, attr, gi, exts in parts:
        tot = sum(e[0] for e in exts) * 512
        print(f'  {name:20s} attr={attr:#x} group={groups[gi][0]:24s} size={tot:12d} extents={len(exts)}')

def extract(sp, md, want, outpath):
    parts, groups, devs = partitions(md)
    for name, attr, gi, exts in parts:
        if name != want: continue
        with open(outpath, 'wb') as o:
            for ns, tt, td, ts in exts:
                if tt != 0:
                    o.write(b'\x00' * (ns * 512)); continue
                off = td * 512; left = ns * 512
                while left:
                    n = min(left, 8 << 20)
                    o.write(sp.read(off, n)); off += n; left -= n
        return True
    return False
