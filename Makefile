#
# if you want the ram-disk device, define this to be the
# size in blocks.
#
RAMDISK = #-DRAMDISK=512

AS	=as --32 -g
LD	=ld -m elf_i386
LDFLAGS	=-Ttext 0 -e startup_32
CC	=gcc -m32 $(RAMDISK)
CFLAGS	=-Wall -g -fno-builtin -fno-stack-protector -fstrength-reduce -fomit-frame-pointer
CPP	=cpp -nostdinc -Iinclude

OBJCOPY=objcopy
STRIP=strip
BUILD=tools/build.sh

#
# ROOT_DEV specifies the default root-device when making the image.
# This can be either FLOPPY, /dev/xxxx or empty, in which case the
# default of /dev/hd6 is used by 'build'.
#
ROOT_DEV=FLOPPY

ARCHIVES=kernel/kernel.o mm/mm.o fs/fs.o
DRIVERS =kernel/blk_drv/blk_drv.a kernel/chr_drv/chr_drv.a
MATH	=kernel/math/math.a
LIBS	=lib/lib.a

.c.s:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -S -o $*.s $<
.s.o:
	$(AS) -c -o $*.o $<
.c.o:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -c -o $*.o $<

all:	Image

Image: boot/bootsect boot/setup tools/system
	cp -f tools/system tools/system.tmp
	$(STRIP) tools/system.tmp
	$(OBJCOPY) -O binary -R .note -R .comment tools/system.tmp
	$(BUILD) boot/bootsect boot/setup tools/system.tmp images/Image
	rm tools/system.tmp
	sync

#Image: boot/bootsect boot/setup tools/system tools/build
#	tools/build boot/bootsect boot/setup tools/system $(ROOT_DEV) > Image
#	sync

disk: Image
	dd bs=8192 if=Image of=/dev/PS0

tools/build: tools/build.c
	$(CC) $(CFLAGS) \
	-o tools/build tools/build.c

boot/head.o: boot/head.s

tools/system:	boot/head.o init/main.o \
		$(ARCHIVES) $(DRIVERS) $(MATH) $(LIBS)
	$(LD) $(LDFLAGS) boot/head.o init/main.o \
	$(ARCHIVES) \
	$(DRIVERS) \
	$(MATH) \
	$(LIBS) \
	-o tools/system > System.map

kernel/math/math.a:
	(cd kernel/math; make)

kernel/blk_drv/blk_drv.a:
	(cd kernel/blk_drv; make)

kernel/chr_drv/chr_drv.a:
	(cd kernel/chr_drv; make)

kernel/kernel.o:
	(cd kernel; make)

mm/mm.o:
	(cd mm; make)

fs/fs.o:
	(cd fs; make)

lib/lib.a:
	(cd lib; make)

boot/setup: boot/setup.s
	$(AS) -o boot/setup.o boot/setup.s
	$(LD) -s -Ttext 0 -o boot/setup boot/setup.o
	$(OBJCOPY) -R .comment -R .note -O binary boot/setup

boot/bootsect:	boot/bootsect.s
	$(AS) -o boot/bootsect.o boot/bootsect.s
	$(LD) -s -Ttext 0 -o boot/bootsect boot/bootsect.o
	$(OBJCOPY) -R .comment -R .note -O binary boot/bootsect

tmp.s:	boot/bootsect.s tools/system
	(echo -n "SYSSIZE = (";ls -l tools/system | grep system \
		| cut -c25-31 | tr '\012' ' '; echo "+ 15 ) / 16") > tmp.s
	cat boot/bootsect.s >> tmp.s

clean:
	rm -f Image System.map tmp_make core boot/bootsect boot/setup
	rm -f init/*.o tools/system tools/build boot/*.o
	(cd mm;make clean)
	(cd fs;make clean)
	(cd kernel;make clean)
	(cd lib;make clean)

backup: clean
	(cd .. ; tar cf - linux | compress - > backup.Z)
	sync

dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in init/*.c;do echo -n "init/";$(CPP) -M $$i;done) >> tmp_make
	cp tmp_make Makefile
	(cd fs; make dep)
	(cd kernel; make dep)
	(cd mm; make dep)

### Dependencies:
init/main.o : init/main.c include/unistd.h include/sys/stat.h \
  include/sys/types.h include/sys/times.h include/sys/utsname.h \
  include/utime.h include/time.h include/linux/tty.h include/termios.h \
  include/linux/sched.h include/linux/head.h include/linux/fs.h \
  include/linux/mm.h include/signal.h include/asm/system.h include/asm/io.h \
  include/stddef.h include/stdarg.h include/fcntl.h
