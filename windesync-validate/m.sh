mkdir -p obj
mkdir -p bin
rgbasm -oobj/windesync-validate.o -Wno-obsolete -p 0xFF -isrc/ -i../common/ src/windesync-validate.asm  &&
rgblink -t -w -p0xFF -o bin/windesync-validate.gb -m bin/windesync-validate.map -n bin/windesync-validate.sym obj/windesync-validate.o &&
rgbfix -v -l 0x0 -n 1 -p0xFF -t "WINDESYNC_V" bin/windesync-validate.gb
