### Create a Live CD LFS
## INSTRUCTIONS:
##		Use lsblk to find which drive (not partition) your premade LFS is located
##		create the full USB Bootable iso by issuing "make usb DRV=<drive from lsblk>
##
##		Ensure you issue a "make enddev" when you are finished developing
##		This will clean up some temp files make relies on (./bld/.bld.tmp and .mnt.tmp)
##		unmount your LFS drive and clean up all built files
##
## EXAMPLE:
##		make usb DRV=/dev/sdb
##

SHELL := /bin/bash

DIST_DIR := lfs
NAME := lfs
_ISODIR := isodir
ISODIR=$(_ISODIR)/isolinux
RAMDIR := ramfs2
BLDDIR := bld
RESDIR := resources

ROOT_DIR := $(DIST_DIR)/root
BOOT_DIR := $(DIST_DIR)/boot

DIST_ROOT_MNT = $(DRV)2
DIST_BOOT_MNT = $(DRV)1

MNT_TMP_FILE := .mnt.tmp
BLD_TMP_FILE := $(BLDDIR)/.bld.tmp

INIT_FILE := $(BLDDIR)/init.gz
SQSH_FILE := $(BLDDIR)/$(NAME).sqsh
ISO_FILE := $(BLDDIR)/$(NAME).iso

RESOURCES = \
	$(RESDIR)/boot.txt \
	$(RESDIR)/bzImage \
	$(RESDIR)/isolinux.bin \
	$(RESDIR)/isolinux.cfg \
	$(RESDIR)/ldlinux.c32

.PHONY: usb
usb: $(NAME).iso

$(NAME).iso: $(ISO_FILE)
	cp $(ISO_FILE) .
	isohybrid $(NAME).iso

.PHONY: compress
compress: usb
	xz -9e --threads=0 $(NAME).iso

.PHONY: build
build: $(BLDDIR)/.bld.tmp

$(BLDDIR)/.bld.tmp:
	-mkdir $(BLDDIR)
	touch $(BLDDIR)/.bld.tmp

.PHONY: squash
squash: $(SQSH_FILE)

$(SQSH_FILE): $(BLD_TMP_FILE) $(MNT_TMP_FILE)
ifneq ($(strip $(TAR)),)
	$(MAKE) tar
	-sudo mkdir $(ROOT_DIR)/image
	-sudo cp root.tar.xz $(ROOT_DIR)/image/
	-sudo cp boot.tar.xz $(ROOT_DIR)/image/
endif
	sudo mv $(ROOT_DIR)/etc/fstab $(ROOT_DIR)/etc/fstab.bak
	sudo echo "" | sudo tee $(ROOT_DIR)/etc/fstab
	sudo mksquashfs $(ROOT_DIR) $(SQSH_FILE) -wildcards -e sources/* tools/*
	sudo rm $(ROOT_DIR)/etc/fstab
	sudo mv $(ROOT_DIR)/etc/fstab.bak $(ROOT_DIR)/etc/fstab
	-sudo rm -rf $(ROOT_DIR)/image

.PHONY: tar
tar: root.tar.xz boot.tar.xz

root.tar.xz: $(MNT_TMP_FILE)
	cd $(ROOT_DIR) && sudo tar --exclude='./tools' --exclude='./sources' -cf - . | sudo xz -9e -c --threads=0 - > $(CURDIR)/root.tar.xz

boot.tar.xz: $(MNT_TMP_FILE)
	cd $(BOOT_DIR) && sudo tar -cf - . | sudo xz -9e -c --threads=0 - > $(CURDIR)/boot.tar.xz

.PHONY: ramfs
ramfs: $(INIT_FILE)

$(INIT_FILE): $(BLD_TMP_FILE) $(RESDIR)/busybox 
	-rm -rf $(RAMDIR)
	mkdir -p $(RAMDIR)/{bin,sbin,etc,proc,usr,usr/bin,usr/sbin,dev,sys,mnt,mnt/rootfs}
	cp $(RESDIR)/busybox $(RAMDIR)/bin/
	cp $(RESDIR)/init $(RAMDIR)
	cd $(RAMDIR) && find . | cpio -H newc -o | gzip -9 > ../$(INIT_FILE)

.PHONY: iso
iso: $(ISO_FILE)

$(ISO_FILE): $(INIT_FILE) $(SQSH_FILE) $(RESOURCES) 
	-rm -rf $(ISODIR)
	mkdir -p $(ISODIR)/isolinux
	#cp $(RESDIR)/boot.txt $(ISODIR)
	#cp $(RESDIR)/bzImage $(ISODIR)
	#cp $(RESDIR)/isolinux.bin $(ISODIR)
	#cp $(RESDIR)/isolinux.cfg $(ISODIR)
	#cp $(RESDIR)/ldlinux.c32 $(ISODIR)
	cp $(RESOURCES) $(ISODIR)
	cp $(BOOT_DIR)/vmlinuz* $(ISODIR)/vmlinuz
	cp $(SQSH_FILE) $(_ISODIR)
	cp $(INIT_FILE) $(ISODIR)

	mkisofs -V LFSISO -o $(ISO_FILE) -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -iso-level 3 -f -R $(_ISODIR)

.PHONY: clean
clean:
	-rm -rf $(BLDDIR) $(RAMDIR) $(_ISODIR) $(NAME).iso root.tar.xz boot.tar.xz $(NAME).iso.xz

.PHONY: dc
dc: clean
	-rm $(RESDIR)/busybox $(RESDIR)/ldlinux.c32 $(RESDIR)/isolinux.bin

.PHONY: mount
mount: $(MNT_TMP_FILE)

$(MNT_TMP_FILE):
ifeq ($(strip $(DRV)),)
	@echo -e "\n\n---------------------------------------------------------"
	@echo -e "ERROR: mount for $(DIST_DIR) not set\nEnsure you have set DRV variable\neg.\n  make mount DRV=/dev/sdb"
	@echo -e "---------------------------------------------------------\n\n"

	@exit 1
else
	mkdir -p $(DIST_DIR)/{root,boot}
	sudo mount $(DIST_ROOT_MNT) $(ROOT_DIR)
	sudo mount $(DIST_BOOT_MNT) $(BOOT_DIR)
	touch $(MNT_TMP_FILE)
endif

.PHONY: umount
umount:
	sudo umount -R $(ROOT_DIR)
	sudo umount -R $(BOOT_DIR)
	rm $(MNT_TMP_FILE)

.PHONY: enddev
enddev: dc umount

.PHONY: prereq
prereq: getbusy getsys

.PHONY: getbusy
getbusy: $(RESDIR)/busybox

$(RESDIR)/busybox:
	wget https://www.busybox.net/downloads/binaries/1.30.0-i686/busybox && mv busybox $(RESDIR)/
	chmod +x $(RESDIR)/busybox

.PHONY: getsys
getsys: $(RESDIR)/isolinux.bin $(RESDIR)/ldlinux.c32

$(RESDIR)/isolinux.bin:
	wget https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz
	tar xf syslinux-6.03.tar.xz
	cp syslinux-6.03/bios/core/isolinux.bin resources/
	cp syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 resources/
	rm -rf syslinux*
