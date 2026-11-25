#!/usr/bin/env python3
"""Generate data.asm (ACME syntax) for the C64 planetarium.

Star, constellation-line and constellation-name data come from d3-celestial
(BSD-3, github.com/ofrohn/d3-celestial), derived from Hipparcos and Stellarium.
"""
import json, math, unicodedata, sys, os

D = os.path.join(os.path.dirname(__file__), '..', 'data')
MAGLIM = 4.5
LANG = os.environ.get('SKYLANG', 'cs')
EN = LANG == 'en'
SC = 16384  # s1.14 fixed point

def load(n):
    return json.load(open(os.path.join(D, n)))

stars = {f['id']: f for f in load('stars.6.json')['features']}
lines = load('constellations.lines.json')['features']
cons = load('constellations.json')['features']

def vec(ra, dec):
    ra = math.radians(ra % 360.0); dec = math.radians(dec)
    return (math.cos(dec) * math.cos(ra), math.cos(dec) * math.sin(ra), math.sin(dec))

def fx(v):
    return int(round(v * SC)) & 0xFFFF

def ascii_up(s):
    s = s.replace(' ', ' ')
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(ch for ch in s if not unicodedata.combining(ch))
    return s.upper()

# ---- star selection ------------------------------------------------------
sel = {}  # id -> (ra, dec, mag)
for sid, f in stars.items():
    m = f['properties']['mag']
    if m <= MAGLIM:
        ra, dec = f['geometry']['coordinates']
        sel[sid] = (ra, dec, m)

# spatial lookup for line vertices
grid = {}
for sid, f in stars.items():
    ra, dec = f['geometry']['coordinates']
    grid.setdefault((round(ra), round(dec)), []).append(sid)

def find_star(ra, dec):
    best = None; bd = 1e9
    for dr in (-1, 0, 1):
        for dd in (-1, 0, 1):
            for sid in grid.get((round(ra) + dr, round(dec) + dd), []):
                r2, d2 = stars[sid]['geometry']['coordinates']
                dist = abs(r2 - ra) + abs(d2 - dec)
                if dist < bd:
                    bd, best = dist, sid
    return best if bd < 0.05 else None

pseudo = []
seg_keys = []
for f in lines:
    for ls in f['geometry']['coordinates']:
        ids = []
        for ra, dec in ls:
            sid = find_star(ra, dec)
            if sid is None:
                sid = ('p', len(pseudo)); pseudo.append((ra, dec)); stars_coord = (ra, dec, 6.0)
                sel[sid] = stars_coord
            else:
                r2, d2 = stars[sid]['geometry']['coordinates']
                if sid not in sel:
                    sel[sid] = (r2, d2, stars[sid]['properties']['mag'])
            ids.append(sid)
        for a, b in zip(ids, ids[1:]):
            if a != b:
                seg_keys.append((a, b))

# ---- group stars into zones (spherical k-means) for fast culling -------------
import numpy as np
keys = sorted(sel, key=lambda k: sel[k][2])
P = np.array([vec(sel[k][0], sel[k][1]) for k in keys])
NZ = 40
rng = np.random.default_rng(1)
C = P[rng.choice(len(P), NZ, replace=False)]
for it in range(60):
    lab = np.argmax(P @ C.T, axis=1)
    for z in range(NZ):
        m = P[lab == z]
        if len(m): C[z] = m.sum(0) / np.linalg.norm(m.sum(0))
lab = np.argmax(P @ C.T, axis=1)
zones = []
order = []
for z in range(NZ):
    idx = [i for i in range(len(keys)) if lab[i] == z]
    if not idx: continue
    assert len(idx) < 256
    r = max(math.acos(min(1.0, float(P[i] @ C[z]))) for i in idx) + math.radians(0.5)
    zones.append((C[z], r, len(idx)))
    order += [keys[i] for i in idx]
ZONES = zones
index = {k: i for i, k in enumerate(order)}
segs = sorted(set(tuple(sorted((index[a], index[b]))) for a, b in seg_keys))

def magcode(m):
    # (mag + 2) * 10, clamped to 0..80
    return max(0, min(80, int(round((m + 2.0) * 10))))

# ---- named stars (Czech forms) ---------------------------------------------
NAMED = {32349: 'SIRIUS', 30438: 'CANOPUS', 69673: 'ARKTUR', 91262: 'VEGA',
         24608: 'KAPELA', 24436: 'RIGEL', 37279: 'PROKYON', 27989: 'BETELGEUZE',
         97649: 'ALTAIR', 21421: 'ALDEBARAN', 65474: 'SPIKA', 80763: 'ANTARES',
         37826: 'POLLUX', 113368: 'FOMALHAUT', 102098: 'DENEB', 49669: 'REGULUS',
         11767: 'POLÁRKA', 36850: 'KASTOR', 25336: 'BELLATRIX', 677: 'ALFERATZ',
         15863: 'MIRFAK', 54061: 'DUBHE', 67301: 'BENETNAŠ', 9884: 'HAMAL',
         14576: 'ALGOL', 68702: 'HADAR', 71683: 'RIGIL KENT', 60718: 'AKRUX'}
if EN:
    NAMED.update({69673: 'ARCTURUS', 24608: 'CAPELLA', 37279: 'PROCYON', 27989: 'BETELGEUSE',
                  65474: 'SPICA', 11767: 'POLARIS', 36850: 'CASTOR', 677: 'ALPHERATZ',
                  67301: 'ALKAID', 60718: 'ACRUX'})
named = [(index[h], n) for h, n in NAMED.items() if h in index]

# ---- constellation labels ----------------------------------------------------
clab = []
for f in cons:
    ra, dec = f['geometry']['coordinates']
    name = f['properties']['name' if EN else 'cz']
    rank = int(f['properties']['rank'])
    clab.append((vec(ra, dec), name, rank))

# ---- font (own 5x7 design, 8x8 cells), chars 32..95 ---------------------------
F = {
' ': [],
'!': ['..X..','..X..','..X..','..X..','.....','..X..'],
'*': ['.....','X.X.X','.XXX.','XXXXX','.XXX.','X.X.X'],
'+': ['.....','..X..','..X..','XXXXX','..X..','..X..'],
',': ['.....','.....','.....','.....','..X..','..X..','.X...'],
'-': ['.....','.....','.....','XXXXX'],
'.': ['.....','.....','.....','.....','.....','..X..'],
'/': ['....X','...X.','..X..','.X...','X....'],
'0': ['.XXX.','X...X','X..XX','X.X.X','XX..X','X...X','.XXX.'],
'1': ['..X..','.XX..','..X..','..X..','..X..','..X..','.XXX.'],
'2': ['.XXX.','X...X','....X','..XX.','.X...','X....','XXXXX'],
'3': ['XXXXX','...X.','..XX.','....X','....X','X...X','.XXX.'],
'4': ['...X.','..XX.','.X.X.','X..X.','XXXXX','...X.','...X.'],
'5': ['XXXXX','X....','XXXX.','....X','....X','X...X','.XXX.'],
'6': ['..XX.','.X...','X....','XXXX.','X...X','X...X','.XXX.'],
'7': ['XXXXX','....X','...X.','..X..','.X...','.X...','.X...'],
'8': ['.XXX.','X...X','X...X','.XXX.','X...X','X...X','.XXX.'],
'9': ['.XXX.','X...X','X...X','.XXXX','....X','...X.','.XX..'],
':': ['.....','..X..','.....','.....','..X..'],
'=': ['.....','.....','XXXXX','.....','XXXXX'],
'?': ['.XXX.','X...X','...X.','..X..','..X..','.....','..X..'],
'@': ['.XX..','X..X.','X..X.','.XX..'],   # degree sign
'A': ['.XXX.','X...X','X...X','XXXXX','X...X','X...X','X...X'],
'B': ['XXXX.','X...X','X...X','XXXX.','X...X','X...X','XXXX.'],
'C': ['.XXX.','X...X','X....','X....','X....','X...X','.XXX.'],
'D': ['XXXX.','X...X','X...X','X...X','X...X','X...X','XXXX.'],
'E': ['XXXXX','X....','X....','XXXX.','X....','X....','XXXXX'],
'F': ['XXXXX','X....','X....','XXXX.','X....','X....','X....'],
'G': ['.XXX.','X...X','X....','X.XXX','X...X','X...X','.XXXX'],
'H': ['X...X','X...X','X...X','XXXXX','X...X','X...X','X...X'],
'I': ['.XXX.','..X..','..X..','..X..','..X..','..X..','.XXX.'],
'J': ['..XXX','...X.','...X.','...X.','...X.','X..X.','.XX..'],
'K': ['X...X','X..X.','X.X..','XX...','X.X..','X..X.','X...X'],
'L': ['X....','X....','X....','X....','X....','X....','XXXXX'],
'M': ['X...X','XX.XX','X.X.X','X.X.X','X...X','X...X','X...X'],
'N': ['X...X','X...X','XX..X','X.X.X','X..XX','X...X','X...X'],
'O': ['.XXX.','X...X','X...X','X...X','X...X','X...X','.XXX.'],
'P': ['XXXX.','X...X','X...X','XXXX.','X....','X....','X....'],
'Q': ['.XXX.','X...X','X...X','X...X','X.X.X','X..X.','.XX.X'],
'R': ['XXXX.','X...X','X...X','XXXX.','X.X..','X..X.','X...X'],
'S': ['.XXXX','X....','X....','.XXX.','....X','....X','XXXX.'],
'T': ['XXXXX','..X..','..X..','..X..','..X..','..X..','..X..'],
'U': ['X...X','X...X','X...X','X...X','X...X','X...X','.XXX.'],
'V': ['X...X','X...X','X...X','X...X','X...X','.X.X.','..X..'],
'W': ['X...X','X...X','X...X','X.X.X','X.X.X','X.X.X','.X.X.'],
'X': ['X...X','X...X','.X.X.','..X..','.X.X.','X...X','X...X'],
'Y': ['X...X','X...X','.X.X.','..X..','..X..','..X..','..X..'],
'Z': ['XXXXX','....X','...X.','..X..','.X...','X....','XXXXX'],
}
ACCENTED = {   # 8-row glyphs: accent on rows 0-1, letter on rows 2-7
 'Á': ['...X.','..X..','.XXX.','X...X','XXXXX','X...X','X...X','X...X'],
 'Č': ['.X.X.','..X..','.XXX.','X...X','X....','X....','X...X','.XXX.'],
 'Ď': ['.X.X.','..X..','XXXX.','X...X','X...X','X...X','X...X','XXXX.'],
 'É': ['...X.','..X..','XXXXX','X....','XXXX.','X....','X....','XXXXX'],
 'Ě': ['.X.X.','..X..','XXXXX','X....','XXXX.','X....','X....','XXXXX'],
 'Í': ['...X.','..X..','.XXX.','..X..','..X..','..X..','..X..','.XXX.'],
 'Ň': ['.X.X.','..X..','X...X','XX..X','X.X.X','X..XX','X...X','X...X'],
 'Ó': ['...X.','..X..','.XXX.','X...X','X...X','X...X','X...X','.XXX.'],
 'Ř': ['.X.X.','..X..','XXXX.','X...X','XXXX.','X.X..','X..X.','X...X'],
 'Š': ['.X.X.','..X..','.XXXX','X....','.XXX.','....X','....X','XXXX.'],
 'Ť': ['.X.X.','..X..','XXXXX','..X..','..X..','..X..','..X..','..X..'],
 'Ú': ['...X.','..X..','X...X','X...X','X...X','X...X','X...X','.XXX.'],
 'Ů': ['..X..','.X.X.','..X..','X...X','X...X','X...X','X...X','.XXX.'],
 'Ý': ['...X.','..X..','X...X','X...X','.X.X.','..X..','..X..','..X..'],
 'Ž': ['.X.X.','..X..','XXXXX','....X','...X.','..X..','.X...','XXXXX'],
}
ACC = {}
for i, (k, v) in enumerate(ACCENTED.items()):
    ACC[k] = chr(96 + i)
    F[chr(96 + i)] = v
NFONT = 96 + len(ACCENTED)
def c64text(s):
    s = s.upper().replace('\u2005', ' ')
    return ''.join(ACC.get(ch, unicodedata.normalize('NFKD', ch)[0]) for ch in s)
def bstr(label, s):
    t = c64text(s); check_text(t)
    return '%s !byte %s,0' % (label, ','.join(str(ord(c)) for c in t))

font = []
for c in range(32, NFONT):
    rows = F.get(chr(c), ['XXXXX'] * 7 if chr(c) not in F else [])
    if chr(c) not in F:
        rows = ['.....'] * 7
    b = []
    off = 0 if len(rows) == 8 else 1      # glyphs sit on rows 1..7, accents use row 0
    for r in range(8):
        rr = r - off
        row = rows[rr] if 0 <= rr < len(rows) else '.....'
        v = 0
        for i, ch in enumerate(row):
            if ch == 'X':
                v |= 0x40 >> i   # columns 1..5 of the 8-pixel cell
        b.append(v)
    font += b

def check_text(s):
    for ch in s:
        if not (32 <= ord(ch) < NFONT) or (ch not in F and ch != ' '):
            raise SystemExit('missing glyph %r in %r' % (ch, s))

# ---- emit ------------------------------------------------------------------
out = []
def emit_bytes(label, data, per=16):
    out.append(label)
    for i in range(0, len(data), per):
        out.append('  !byte ' + ','.join('$%02x' % (x & 0xFF) for x in data[i:i + per]))

out.append('; generated by gen_data.py - do not edit')
out.append('NSTARS = %d' % len(order))
out.append('NSEGS = %d' % len(segs))
out.append('NCONS = %d' % len(clab))
out.append('NNAMED = %d' % len(named))

data = []
for k in order:
    ra, dec, m = sel[k]
    v = vec(ra, dec)
    for c in v:
        w = fx(c); data += [w & 0xFF, w >> 8]
    data.append(magcode(m))
emit_bytes('stars:', data, 14)

data = []
for c, r, n in ZONES:
    for x in c:
        w = fx(x); data += [w & 0xFF, w >> 8]
    ra = int(r / (2 * math.pi) * 65536) + 1
    ht = (-int(math.sin(r) * 4096 + 260)) & 0xFFFF
    data += [ra & 0xFF, ra >> 8, ht & 0xFF, ht >> 8, n]
out.append('NZONES = %d' % len(ZONES))
emit_bytes('zones:', data, 11)

data = []
for a, b in segs:
    data += [a & 0xFF, a >> 8, b & 0xFF, b >> 8]
emit_bytes('segs:', data, 16)

out.append('conlab:')
for i, (v, name, rank) in enumerate(clab):
    w = [fx(c) for c in v]
    out.append('  !word $%04x,$%04x,$%04x,cn%d' % (w[0], w[1], w[2], i))
for i, (v, name, rank) in enumerate(clab):
    out.append(bstr('cn%d' % i, name))

# ---- Messier objects --------------------------------------------------------
MT = {'s': 0, 'e': 0, 'i': 0, 'oc': 1, 'pos': 1, 'gc': 2}
mess = load('messier.json')['features']
mess.sort(key=lambda f: int(f['id'][1:]))
out.append('NMESS = %d' % len(mess))
out.append('messier:')
for f in mess:
    ra, dec = f['geometry']['coordinates']
    w = [fx(c) for c in vec(ra, dec)]
    t = MT.get(f['properties']['type'], 3)
    out.append('  !word $%04x,$%04x,$%04x' % tuple(w))
    out.append('  !byte %d' % t)
    out.append('  !word mn%s' % f['id'][1:])
for f in mess:
    out.append('mn%s !text "%s",0' % (f['id'][1:], f['id']))

for i, nm in enumerate(['SUN', 'MOON', 'MERCURY', 'VENUS', 'MARS', 'JUPITER', 'SATURN'] if EN else
                        ['SLUNCE', 'MĚSÍC', 'MERKUR', 'VENUŠE', 'MARS', 'JUPITER', 'SATURN']):
    out.append(bstr('pn%d' % i, nm))
out.append('CH_YACUTE = %d' % ord(ACC['Ý']))
out.append('CH_SCARON = %d' % ord(ACC['Š']))
if EN:
    out += ["ALT1 = 'A'", "ALT2 = 'L'", "ALT3 = 'T'", "FOV1 = 'F'", "FOV2 = 'O'"]
else:
    out += ["ALT1 = 'V'", "ALT2 = CH_YACUTE", "ALT3 = CH_SCARON", "FOV1 = 'Z'", "FOV2 = 'P'"]
fold = []
for k in ACCENTED:
    fold.append(ord(unicodedata.normalize('NFKD', k)[0]))
out.append('foldtab: !byte ' + ','.join(map(str, fold)))
out.append('starlab:')
for i, (idx, name) in enumerate(named):
    out.append('  !word %d,sn%d' % (idx, i))
for i, (idx, name) in enumerate(named):
    out.append(bstr('sn%d' % i, name))

emit_bytes('font:', font)

N = 1024
sl = []; sh = []
for i in range(N):
    w = fx(math.sin(2 * math.pi * i / N))
    sl.append(w & 0xFF); sh.append(w >> 8)
out.append('!align 255,0')
emit_bytes('sinlo:', sl)
emit_bytes('sinhi:', sh)
q = [n * n // 4 for n in range(512)]
emit_bytes('sqlo:', [x & 0xFF for x in q])
emit_bytes('sqhi:', [x >> 8 for x in q])

open(os.path.join(os.path.dirname(__file__), 'data.asm'), 'w').write('\n'.join(out) + '\n')
print('zones', len(ZONES), 'max r', round(math.degrees(max(z[1] for z in ZONES)),1), 'stars', len(order), 'pseudo', len(pseudo), 'segs', len(segs), 'cons', len(clab), 'named', len(named),
      file=sys.stderr)

# ---- extra tables: rows, zoom levels, star/planet patterns ------------------
ex = []
def eb(label, data, per=16):
    ex.append(label)
    for i in range(0, len(data), per):
        ex.append('  !byte ' + ','.join('$%02x' % (x & 0xFF) for x in data[i:i + per]))
rows = [0xE000 + (y >> 3) * 320 + (y & 7) for y in range(200)]
eb('ytlo:', [r & 0xFF for r in rows]); eb('ythi:', [r >> 8 for r in rows])
FOVS = [120, 90, 60, 40, 25, 15]
STEP = [20, 15, 10, 6, 4, 2.5]
MAGL = [61, 66, 255, 255, 255, 255]
K = [round(160 / math.tan(math.radians(f / 4))) for f in FOVS]
DMIN = []
for k in K:
    tc = 2 * math.degrees(math.atan(math.hypot(160, 96) / k))
    z = math.cos(math.radians(min(tc + 12, 100)))
    DMIN.append(int(SC + z * SC))
ex.append('NZOOM = %d' % len(FOVS))
QZ = [((d - SC) // 4 - 246) & 0xFFFF for d in DMIN]
ZC = [round(math.acos((d - SC) / SC) / (2 * math.pi) * 65536) for d in DMIN]
UX = [min(65535, round(65536 * math.tan(math.radians(2 * math.degrees(math.atan(160 / k)) + 12) / 2))) for k in K]
UY = [min(65535, round(65536 * math.tan(math.radians(2 * math.degrees(math.atan(96 / k)) + 12) / 2))) for k in K]
for nm, arr in (('zcone', ZC), ('zux', UX), ('zuy', UY), ('zq', QZ), ('zk', K), ('zd', DMIN), ('zstep', [round(s * 65536 / 360) for s in STEP])):
    eb(nm + 'lo:', [a & 0xFF for a in arr]); eb(nm + 'hi:', [a >> 8 for a in arr])
eb('zfov:', FOVS); eb('zmag:', MAGL)
def pat(pts):
    d = [len(pts)]
    for x, y in pts: d += [x & 0xFF, y & 0xFF]
    return d
disc = lambda r: [(x, y) for y in range(-r, r + 1) for x in range(-r, r + 1) if x * x + y * y <= r * r + r * 0.6]
P = {
 'pat0': [(x, y) for y in range(-2, 3) for x in range(-2, 3) if abs(x) + abs(y) < 4],
 'pat1': [(x, y) for y in range(-1, 3) for x in range(-1, 3) if (x, y) not in ((-1, -1), (2, -1), (-1, 2), (2, 2))],
 'pat2': [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)],
 'pat3': [(0, 0), (1, 0), (0, 1), (1, 1)],
 'pat4': [(0, 0)],
 'patsun': [(x, y) for y in range(-5, 6) for x in range(-5, 6) if 3.6 <= math.hypot(x, y) <= 4.6 or x * x + y * y <= 2],
 'patmoon': disc(4),
 'patsel': [(x, y) for y in range(-8, 9) for x in range(-8, 9) if (5.5 <= math.hypot(x, y) <= 6.4 and min(abs(x), abs(y)) > 1) or (x == 0 and 5 <= abs(y) <= 8) or (y == 0 and 5 <= abs(x) <= 8)],
 'patgal': [(-3, -1), (-2, -2), (-1, -2), (0, -2), (1, -2), (2, -2), (3, -1), (-3, 0), (3, 0), (-3, 1), (-2, 2), (-1, 2), (0, 2), (1, 2), (2, 2), (3, 1), (0, 0)],
 'patoc': [(x, y) for y in range(-4, 5) for x in range(-4, 5) if 3.5 <= math.hypot(x, y) <= 4.4 and (x + y) % 2 == 0],
 'patgc': [(x, y) for y in range(-3, 4) for x in range(-3, 4) if 2.5 <= math.hypot(x, y) <= 3.4] + [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)],
 'patneb': [(x, y) for y in range(-3, 4) for x in range(-3, 4) if max(abs(x), abs(y)) == 3],
 'patpl': [(x, y) for y in range(-1, 2) for x in range(-1, 2)] + [(2, 0), (-2, 0), (0, 2), (0, -2)],
}
for k2, v in P.items():
    eb(k2 + ':', pat(v))
ex.append('bitt: !byte $80,$40,$20,$10,$08,$04,$02,$01')

# ---- title screen (from the SkyMap64 mock-up, 340x190 -> 320x200) ----------
import re as _re
svg = open(os.path.join(D, 'title.svg')).read()
def mapxy(x, y):
    return int(round(8 + (x - 10) * 303 / 320)), int(round(8 + (y - 10) * 183 / 170))
ts = []
for cx_, cy_, rr in _re.findall(r'<circle cx="([0-9.]+)" cy="([0-9.]+)" r="([0-9.]+)"', svg):
    x, y = mapxy(float(cx_), float(cy_))
    ts += [x & 0xFF, x >> 8, y, 1 if float(rr) > 1 else 0]
ex.append('NTSTARS = %d' % (len(ts) // 4))
eb('tstars:', ts, 16)
tl = []
for d in _re.findall(r'<path d="([^"]+)"', svg):
    pts = [mapxy(float(a), float(b)) for a, b in _re.findall(r'([0-9.]+) ([0-9.]+)', d)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        tl += [x0 & 0xFF, x0 >> 8, y0, x1 & 0xFF, x1 >> 8, y1]
ex.append('NTLINES = %d' % (len(tl) // 6))
eb('tlines:', tl, 12)
TT = [(4, 'ASTRONOMICKÝ PROGRAM PRO C64', None), (13, 'OSOBNÍ PLANETÁRIUM', None), (17, 'VESMÍR V 64 KB', None),
      (21, 'POKRAČUJ STISKEM RETURN', None), (10, 'V1.1', 33)]
if EN:
    TT = [(4, 'ASTRONOMY PROGRAM FOR C64', None), (13, 'PERSONAL PLANETARIUM', None), (17, 'THE UNIVERSE IN 64 KB', None),
          (21, 'PRESS RETURN TO CONTINUE', None), (10, 'V1.1', 33)]
ex.append('ttexts:')
for row, t, col in TT:
    ex.append('  !byte %d,%d' % ((40 - len(t)) // 2 if col is None else col, row))
    ex.append('  !word tt%d' % row)
ex.append('  !byte $ff')
for row, t, col in TT:
    t2 = c64text(t); check_text(t2)
    ex.append('tt%d !byte %s,0' % (row, ','.join(str(ord(c)) for c in t2)))
LOW = {'k': ['X....','X....','X..X.','X.X..','XX...','X.X..','X..X.'],
       'y': ['.....','.....','X...X','X...X','X...X','.XXXX','....X','.XXX.'],
       'a': ['.....','.....','.XXX.','....X','.XXXX','X...X','.XXXX'],
       'p': ['.....','.....','XXXX.','X...X','X...X','XXXX.','X....','X....']}
big = []
for ch in 'SkyMap64':
    rows = LOW.get(ch) or F[ch]
    for rr in range(8):
        row = rows[rr] if rr < len(rows) else '.....'
        big.append(sum(0x40 >> i for i, c in enumerate(row) if c == 'X'))
eb('bigfont:', big, 8)
open(os.path.join(os.path.dirname(__file__), 'data.asm'), 'a').write('\n'.join(ex) + '\n')
print('K', K, 'DMIN', DMIN, file=sys.stderr)
