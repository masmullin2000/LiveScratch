#!/bin/bash

rm -f distro/lfs.sqsh lfs.iso distro/isolinux/init.gz
mksquashfs lfs distro/lfs.sqsh
#cd ramfs/ && find . | cpio -H newc -o > ../init.cpio && cd ../ && cat init.cpio | gzip -9 > distro/isolinux/init.gz
cd ramfs && find . | cpio -H newc -o | gzip -9 > ../distro/isolinux/init.gz && cd ..
mkisofs -V LFSISO -o lfs.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -iso-level 3 -f -R distro
isohybrid lfs.iso

