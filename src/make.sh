if [ ! -d out ]; then
	mkdir out
fi

../ca65.exe -D memo msbasic.s -o ../out/memo.o &&
../ld65.exe -C memo.cfg ../out/memo.o -o ../out/memo.bin -Ln ../out/memo.lbl

