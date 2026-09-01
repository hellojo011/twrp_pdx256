import struct, os

class Ext4:
    def __init__(self, path):
        self.f = open(path, 'rb')
        self.f.seek(0x400); sb = self.f.read(1024)
        self.bs = 1024 << struct.unpack('<I', sb[24:28])[0]
        self.inode_size = struct.unpack('<H', sb[88:90])[0]
        self.ipg = struct.unpack('<I', sb[40:44])[0]
        self.bpg = struct.unpack('<I', sb[32:36])[0]
        self.desc_size = struct.unpack('<H', sb[254:256])[0] or 32
        self.blocks = struct.unpack('<I', sb[4:8])[0]
        self.first_data_block = struct.unpack('<I', sb[20:24])[0]
    def blk(self, n, cnt=1):
        self.f.seek(n * self.bs); return self.f.read(self.bs * cnt)
    def gd(self, g):
        gdt_blk = self.first_data_block + 1
        off = gdt_blk * self.bs + g * self.desc_size
        self.f.seek(off); d = self.f.read(self.desc_size)
        return struct.unpack('<I', d[8:12])[0]   # bg_inode_table_lo
    def inode(self, ino):
        g, idx = divmod(ino - 1, self.ipg)
        off = self.gd(g) * self.bs + idx * self.inode_size
        self.f.seek(off); return self.f.read(self.inode_size)
    def extents(self, ind):
        blocks = ind[40:100]
        out = []
        def walk(node):
            magic, entries, mx, depth, gen = struct.unpack('<HHHHI', node[:12])
            if magic != 0xF30A: return
            for i in range(entries):
                e = node[12 + i*12: 24 + i*12]
                if depth == 0:
                    blk, ln, hi, lo = struct.unpack('<IHHI', e)
                    out.append((blk, ln & 0x7fff, lo | (hi << 32)))
                else:
                    blk, lo, hi, _ = struct.unpack('<IIHH', e)
                    walk(self.blk(lo | (hi << 32)))
        walk(blocks)
        return out
    def read_file(self, ino):
        ind = self.inode(ino)
        mode, = struct.unpack('<H', ind[:2])
        sz = struct.unpack('<I', ind[4:8])[0] | (struct.unpack('<I', ind[108:112])[0] << 32)
        flags, = struct.unpack('<I', ind[32:36])
        if (mode & 0xF000) == 0xA000 and sz < 60:      # fast symlink
            return ind[40:40+sz]
        data = bytearray(sz)
        for lblk, ln, pblk in self.extents(ind):
            chunk = self.blk(pblk, ln)
            o = lblk * self.bs
            data[o:o+len(chunk)] = chunk[:max(0, sz - o)]
        return bytes(data[:sz])
    def listdir(self, ino):
        raw = self.read_file(ino)
        out = []; i = 0
        while i < len(raw) - 8:
            child, rec, nlen, ftype = struct.unpack('<IHBB', raw[i:i+8])
            if rec < 8: break
            if child: out.append((raw[i+8:i+8+nlen].decode('utf-8', 'replace'), child, ftype))
            i += rec
        return out
    def walk(self, ino=2, prefix=''):
        for name, child, ft in self.listdir(ino):
            if name in ('.', '..'): continue
            p = prefix + '/' + name
            yield p, child, ft
            if ft == 2:
                yield from self.walk(child, p)
    def resolve(self, path):
        ino = 2
        for part in path.strip('/').split('/'):
            if not part: continue
            for name, child, ft in self.listdir(ino):
                if name == part: ino = child; break
            else: return None
        return ino

if __name__ == '__main__':
    import sys
    fs = Ext4('vendor_a.img')
    n = 0
    for p, ino, ft in fs.walk():
        n += 1
    print('total entries:', n)
