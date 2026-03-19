THIS_MAKEFILE_DIR = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

KERNEL_REPO=https://gitlab.com/cip-project/cip-kernel/linux-cip/-/archive/v5.10.246-rt140/linux-cip-v5.10.246-rt140.tar.gz?ref_type=tags
#KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/cip/linux-cip.git/snapshot/linux-cip-
#KERNEL_REPO=https://github.com/torvalds/linux/archive/refs/tags
#KERNEL_VERSION=v5.10
KERNEL_VERSION=v5.10.246
KERNEL_SRC_DIR=${BUILD_DIR}/kernel-src-${KERNEL_VERSION}
KERNEL_BUILD_DIR=${BUILD_DIR}/kernel-build
KERNEL_IMAGE_PATH=${KERNEL_BUILD_DIR}/arch/arm64/boot/Image
KERNEL_FIT_PATH=${KERNEL_BUILD_DIR}/epos_kernel.fit
KERNEL_VENDOR_FIT_PATH=${KERNEL_BUILD_DIR}/epos_vendor_kernel.fit
KERNEL_ITS_PATH=${THIS_MAKEFILE_DIR}/epos_kernel.its
KERNEL_VENDOR_ITS_PATH=${THIS_MAKEFILE_DIR}/vendor.its
KERNEL_INITRAMFS_PATH=${KERNEL_BUILD_DIR}/initramfs.img

all: ${KERNEL_IMAGE_PATH}

MAINLINE_PARTITIONS_DIR=${BUILD_DIR}/partitions/mainline
MAINLINE_BOOT_IMG_PATH=${MAINLINE_PARTITIONS_DIR}/boot.img
RESOURCE_IMG_PATH=${MAINLINE_PARTITIONS_DIR}/resource.img
ITS_FILE_PATH=${MAINLINE_PARTITIONS_DIR}/boot.its

EPOS_LOGO_FILE_PATH=${THIS_MAKEFILE_DIR}/epos_logo.bmp


# download kernel source
${KERNEL_SRC_DIR}/Makefile:
	rm -fr ${KERNEL_SRC_DIR}
	mkdir -p ${KERNEL_SRC_DIR} ${KERNEL_BUILD_DIR}
	wget ${KERNEL_REPO} -O ${BUILD_DIR}/${KERNEL_VERSION}.tar.gz
	tar -xzf ${BUILD_DIR}/${KERNEL_VERSION}.tar.gz -C ${KERNEL_SRC_DIR} --strip-components=1
	# add dts for EC942
	ln -s ${THIS_MAKEFILE_DIR}/resources/rk3568-ec942.dts ${KERNEL_SRC_DIR}/arch/arm64/boot/dts/rockchip/rk3568-ec942.dts
	ln -s ${THIS_MAKEFILE_DIR}/resources/ec942_defconfig ${KERNEL_BUILD_DIR}/vendor.its
	ln -s
	# add to the Makefile dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-ec942.dtb

${KERNEL_IMAGE_PATH}: ${KERNEL_SRC_DIR}/Makefile
	mkdir -p ${KERNEL_BUILD_DIR}
	make -C ${KERNEL_SRC_DIR} -j12 CROSS_COMPILE=aarch64-unknown-linux-gnu- ARCH=arm64 O=${KERNEL_BUILD_DIR} ec942_defconfig all

${KERNEL_VENDOR_FIT_PATH}: ${KERNEL_ITS_PATH} ${KERNEL_IMAGE_PATH}
	cd ${KERNEL_BUILD_DIR} && ${EPOS_RESOURCES_DIR}/inhand_resources/switch/mkimage -f vendor.its -E -p 0x800 $@

clean:
	rm -rf ${BUILD_DIR}
