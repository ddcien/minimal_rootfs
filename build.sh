#!/usr/bin/bash


# prepare minsys 
export MINSYS_HOME=/tmp/minsys
export MINSYS_SYSROOT=$MINSYS_HOME/sysroot
export MINSYS_ROOTFS=$MINSYS_HOME/rootfs

rm -rf $MINSYS_HOME
mkdir -p $MINSYS_HOME $MINSYS_SYSROOT $MINSYS_ROOTFS
tar xvf rootfs.tar.gz -C $MINSYS_ROOTFS

# # install linux headers
pushd /work/byhx/eops_neo/kernel_build_6.6
make ARCH=arm LLVM=1 INSTALL_HDR_PATH=$MINSYS_SYSROOT headers_install
popd

# build and install musl to $MINSYS_SYSROOT
tar -xvf src/musl-1.2.5.tar.gz
pushd musl-1.2.5
./configure --target=arm-linux-gnueabihf --prefix=$MINSYS_SYSROOT
make -j$(nproc --all) install
popd

# build and install busybox to $MINSYS_ROOTFS
tar -xvf src/busybox-1.36.1.tar.bz2
pushd busybox-1.36.1
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
    CONFIG_STATIC=y \
    CONFIG_EXTRA_CFLAGS="-specs=$MINSYS_SYSROOT/lib/musl-gcc.specs" \
    CONFIG_PREFIX=$MINSYS_ROOTFS \
    -j$(nproc --all) install
popd

pushd $MINSYS_ROOTFS
mv linuxrc init
popd

## build initramfs
pushd $MINSYS_ROOTFS
find . | cpio -o -H newc | gzip > ${MINSYS_HOME}/initramfs.cpio.gz
popd
pushd $MINSYS_HOME
mkimage -A arm -O linux -T ramdisk -C gzip -d initramfs.cpio.gz /srv/tftp/initramfs.uimg
popd

## build initrd
pushd ${MINSYS_HOME}
truncate --size=16M initrd.ext4
mkfs.ext4 -d ${MINSYS_ROOTFS} initrd.ext4
gzip initrd.ext4
mkimage -A arm -O linux -T ramdisk -C gzip -d initrd.ext4.gz /srv/tftp/initrd.uimg
popd
