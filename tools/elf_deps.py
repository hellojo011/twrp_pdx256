import struct
from ext4 import Ext4

def needed(data):
    if data[:4]!=b'\x7fELF': return []
    is64=data[4]==2
    e_phoff=struct.unpack('<Q',data[32:40])[0]
    e_phentsize,e_phnum=struct.unpack('<HH',data[54:58])
    dyn=None
    for i in range(e_phnum):
        p=data[e_phoff+i*e_phentsize:e_phoff+(i+1)*e_phentsize]
        p_type=struct.unpack('<I',p[0:4])[0]
        if p_type==2:  # PT_DYNAMIC
            p_offset=struct.unpack('<Q',p[8:16])[0]
            p_filesz=struct.unpack('<Q',p[32:40])[0]
            dyn=data[p_offset:p_offset+p_filesz]
        if p_type==1 and dyn is None:
            pass
    if dyn is None: return []
    # find DT_STRTAB (5) and DT_NEEDED (1)
    strtab_addr=None; needs=[]
    i=0
    while i+16<=len(dyn):
        tag,val=struct.unpack('<qQ',dyn[i:i+16]); i+=16
        if tag==0: break
        if tag==5: strtab_addr=val
        if tag==1: needs.append(val)
    # map vaddr->offset via PT_LOAD
    def v2o(v):
        for i in range(e_phnum):
            p=data[e_phoff+i*e_phentsize:e_phoff+(i+1)*e_phentsize]
            t=struct.unpack('<I',p[0:4])[0]
            if t!=1: continue
            off,va,_,fsz=struct.unpack('<QQQQ',p[8:40])
            if va<=v<va+fsz: return off+(v-va)
        return None
    so=v2o(strtab_addr)
    out=[]
    for n in needs:
        s=so+n; e=data.index(b'\x00',s); out.append(data[s:e].decode())
    return out

fs=Ext4('vendor_a.img')
index={}
for p,ino,ft in fs.walk():
    if ft!=2: index[p.rsplit('/',1)[-1]]=(p,ino)

roots=['/bin/hw/android.hardware.security.keymint-service-qti','/bin/qseecomd']
seen=set(); order=[]; missing=set()
stack=list(roots)
while stack:
    p=stack.pop()
    if p in seen: continue
    seen.add(p); order.append(p)
    ino=fs.resolve(p)
    if not ino: continue
    for n in needed(fs.read_file(ino)):
        if n in index:
            np=index[n][0]
            if np not in seen: stack.append(np)
        else:
            missing.add(n)
print('=== vendor 안에서 해결되는 의존성 (%d개) ==='%len(order))
for p in sorted(order): print('  /vendor'+p)
print()
print('=== vendor 밖(system/apex)에서 오는 것 (%d개) ==='%len(missing))
for n in sorted(missing): print('  ',n)
