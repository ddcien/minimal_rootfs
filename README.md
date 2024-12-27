# A

## 准备工作

### 获取相关源代码

1. [musl-1.2.5.tar.gz](https://musl.libc.org/releases/musl-1.2.5.tar.gz)
2. [busybox-1.36.1.tar.bz2](https://busybox.net/downloads/busybox-1.36.1.tar.bz2)
3. [linux kernel](https://www.kernel.org/)


### 创建工作目录

```sh
export MINSYS_HOME=/tmp/minsys
export MINSYS_SYSROOT=$MINSYS_HOME/sysroot
export MINSYS_ROOTFS=$MINSYS_HOME/rootfs
mkdir -p $MINSYS_HOME $MINSYS_SYSROOT $MINSYS_ROOTFS

pushd $MINSYS_ROOTFS
mkdir -p lib dev etc proc sys 
popd
```

### 构建

#### 安装内核头文件

`busybox`的编译构建过程是需要`linux`内核同文件的，
因此需要提前将内核头文件安装到`$MINSYS_SYSROOT`目录。

注意：在执行下面的操作前，需要先配置和编译内核。

```sh
pushd linux_build
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
    INSTALL_HDR_PATH=$MINSYS_SYSROOT \
    headers_install
popd
```
#### 编译构建并安装`musl`

```sh
tar -xvf musl-1.2.5.tar.gz
pushd musl-1.2.5
./configure --target=arm-linux-gnueabihf --prefix=$MINSYS_SYSROOT
make install
popd
```

#### 编译构建并安装`busybox`

```sh
tar -xvf busybox-1.36.1.tar.bz2
pushd busybox-1.36.1
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
    CONFIG_STATIC=y \
    CONFIG_EXTRA_CFLAGS="-specs=$MINSYS_SYSROOT/lib/musl-gcc.specs" \
    CONFIG_PREFIX=$MINSYS_ROOTFS \
    install
popd
```

上面的构建`busybox`采用了静态链接，因此busybox的可执行文件是不依赖任何动态库的。
此配置构建出来的`busybox`可执行文件大小900多KB。

如果在跟文件系统中还需要`busybox`意外的其他程序，可以选择动态链接的方式来构建`busybox`。

```sh

# 安装musl的动态链接库到`$MINSYS_ROOTFS/lib`

mkdir -p $MINSYS_ROOTFS/lib
cp $MINSYS_SYSROOT/lib/libc.so $MINSYS_ROOTFS/lib
arm-linux-gnueabihf-strip $MINSYS_ROOTFS/lib/libc.so
ln -s /lib/libc.so $MINSYS_ROOTFS/lib/ld-musl-armhf.so.1

# dynamic linking
# 删除了`CONFIG_STATIC=y` 这一行；
pushd busybox-1.36.1
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
    CONFIG_EXTRA_CFLAGS="-specs=$MINSYS_SYSROOT/lib/musl-gcc.specs" \
    CONFIG_PREFIX=$MINSYS_ROOTFS \
    install
popd
```

这样的配置下，`libc.so`是`musl`的运行时C库，大小为500多KB；
而`busybox`的可执行文件是依赖于`libc.so`的，大小为800多KB，比静态链接时小了100KB左右。
而根文件系统的整体大小来到1.5MB左右，比静态链接时大了400多KB。



#### 将`rootfs`打包成`initramfs`或者`initrd`

关于`ramfs`和`ramdisk`的区别请参考[这里](https://docs.kernel.org/filesystems/ramfs-rootfs-initramfs.html)


##### 打包成`initramfs`

```sh
#!/bin/bash
pushd $MINSYS_ROOTFS
find . | cpio -o -H newc | gzip > ${MINSYS_HOME}/initramfs.cpio.gz
popd

pushd $MINSYS_HOME
mkimage -A arm -O linux -T ramdisk -C gzip -d initramfs.cpio.gz initramfs.uimg
popd
```

##### 打包成`initrd`

```sh
#!/bin/bash
pushd $${MINSYS_HOME}
truncate --size=16M initrd.ext4
mkfs.ext4 -d ${MINSYS_ROOTFS} initrd.ext4
gzip initrd.ext4
mkimage -A arm -O linux -T ramdisk -C gzip -d initrd.ext4.gz  initrd.uimg
```
