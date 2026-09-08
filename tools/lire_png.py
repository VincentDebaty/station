# Lire un PNG sans dépendance : c'est la seule chose que `sips` ne sache pas
# faire, et le projet n'installe rien.
def lire(p):
    import zlib, struct
    d = open(p, 'rb').read(); i = 8; idat = b''; w = hh = bd = ct = 0
    while i < len(d):
        ln = struct.unpack('>I', d[i:i+4])[0]; t = d[i+4:i+8]
        dat = d[i+8:i+8+ln]; i += 12 + ln
        if t == b'IHDR': w, hh, bd, ct = struct.unpack('>IIBB', dat[:10])
        elif t == b'IDAT': idat += dat
        elif t == b'IEND': break
    raw = zlib.decompress(idat); nc = {0:1, 2:3, 3:1, 4:2, 6:4}[ct]
    bpp = nc * bd // 8; st = w * bpp
    out = bytearray(); prev = bytearray(st); p2 = 0
    for y in range(hh):
        f = raw[p2]; p2 += 1; l = bytearray(raw[p2:p2+st]); p2 += st
        for x in range(st):
            a = l[x-bpp] if x >= bpp else 0; b = prev[x]
            c = prev[x-bpp] if x >= bpp else 0
            if f == 1: l[x] = (l[x] + a) & 255
            elif f == 2: l[x] = (l[x] + b) & 255
            elif f == 3: l[x] = (l[x] + (a + b) // 2) & 255
            elif f == 4:
                pa = abs(b-c); pb = abs(a-c); pc = abs(a+b-2*c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                l[x] = (l[x] + pr) & 255
        out += l; prev = l
    return w, hh, bpp, bytes(out)
