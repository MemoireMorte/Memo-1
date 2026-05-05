if [ ! -d out ]; then
	mkdir out
fi

../ca65.exe -D memo msbasic.s -o ../out/memo.o &&
../ld65.exe -C memo.cfg ../out/memo.o -o ../out/memo.bin -Ln ../out/memo.lbl

# Debug build: keeps KCS_DEBUG instrumentation (bit log, raw X dump)
../ca65.exe -D memo -D KCS_DEBUG msbasic.s -o ../out/memo_debug.o &&
../ld65.exe -C memo.cfg ../out/memo_debug.o -o ../out/memo_debug.bin -Ln ../out/memo_debug.lbl

