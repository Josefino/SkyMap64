#!/bin/sh
# Builds the Czech (skymap64.*) and English (skymap64en.*) versions.
set -e
cd "$(dirname "$0")"
python3 make_en_bas.py
build() {   # $1 = cs|en, $2 = output name, $3 = BASIC source, $4 = LANG number, $5 = disk name
    SKYLANG=$1 python3 gen_data.py
    acme -DLANG=$4 -r planet_$1.lst planet.asm
    petcat -w2 -o planet_basic.prg -- $3
    python3 - "$2" <<'PY'
import sys
b=open('planet_basic.prg','rb').read(); ml=open('planet_ml.bin','rb').read()
assert b[:2]==b'\x01\x08'; end=0x0801+len(b)-2
assert end<0x2000, 'BASIC too long: $%04x' % end
img=bytearray(b[2:])+bytearray(0x2000-end)+ml
open(sys.argv[1]+'.prg','wb').write(b'\x01\x08'+img)
print('%s: basic end $%04x, prg end $%04x'%(sys.argv[1],end,0x0801+len(img)))
PY
    rm -f $2.d64
    c1541 -format "$5,64" d64 $2.d64 -write $2.prg $2 >/dev/null
}
build cs skymap64 planet.bas 0 "skymap64 v1.1"
build en skymap64en planet_en.bas 1 "skymap64en v1.1"
SKYLANG=cs python3 gen_data.py >/dev/null 2>&1   # leave Czech data.asm in place
