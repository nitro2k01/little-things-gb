mkdir -p obj
mkdir -p bin
rgbasm -h -oobj/double-halt-cancel.o -Wno-obsolete -p 0xFF -isrc/ -i../common/ src/double-halt-cancel.asm  &&
rgblink -t -w -p0xFF -o bin/double-halt-cancel.gb -m bin/double-halt-cancel.map -n bin/double-halt-cancel.sym obj/double-halt-cancel.o &&
cp bin/double-halt-cancel.gb bin/double-halt-cancel-gbconly.gb &&
rgbfix -v -l 0x0 -n 1 -p0xFF -t "2XHALTCANCEL" bin/double-halt-cancel.gb &&
rgbfix -v -C -l 0x0 -n 1 -p0xFF -t "2XHALTCANCEL" bin/double-halt-cancel-gbconly.gb
