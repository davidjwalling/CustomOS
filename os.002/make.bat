del /Q os.dat
nasm os.asm -f bin -o os.dat -l os.dat.lst -DBUILDBOOT
del /Q os.dsk
nasm os.asm -f bin -o os.dsk -l os.dsk.lst -DBUILDDISK
del /Q os.com
nasm os.asm -f bin -o os.com -l os.com.lst -DBUILDCOM