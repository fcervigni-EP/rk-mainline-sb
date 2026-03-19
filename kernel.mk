THIS_MAKEFILE_DIR = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

KERNEL_REPO=https://gitlab.com/cip-project/cip-kernel/linux-cip/-/archive/v5.10.246-rt140/linux-cip-v5.10.246-rt140.tar.gz?ref_type=tags
#KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/cip/linux-cip.git/snapshot/linux-cip-
#KERNEL_REPO=https://github.com/torvalds/linux/archive/refs/tags
#KERNEL_VERSION=v5.10
KERNEL_VERSION=v5.10.246
KERNEL_SRC_DIR=${BUILD_DIR}/kernel-src-${KERNEL_VERSION}
KERNEL_BUILD_DIR=${BUILD_DIR}/kernel-build
KERNEL_IMAGE_PATH=${KERNEL_BUILD_DIR}/arch/arm64/boot/Image
KERNEL_VENDOR_FIT_PATH=${KERNEL_BUILD_DIR}/epos_vendor_kernel.fit
KERNEL_ITS_PATH=${THIS_MAKEFILE_DIR}/epos_kernel.its

all: ${KERNEL_IMAGE_PATH}

# download kernel source
${KERNEL_SRC_DIR}/Makefile:
	rm -fr ${KERNEL_SRC_DIR}
	mkdir -p ${KERNEL_SRC_DIR} ${KERNEL_BUILD_DIR}
	wget ${KERNEL_REPO} -O ${BUILD_DIR}/${KERNEL_VERSION}.tar.gz
	tar -xzf ${BUILD_DIR}/${KERNEL_VERSION}.tar.gz -C ${KERNEL_SRC_DIR} --strip-components=1
	# add dts for EC942
	ln -s ${THIS_MAKEFILE_DIR}/resources/rk3568-ec942.dts ${KERNEL_SRC_DIR}/arch/arm64/boot/dts/rockchip/rk3568-ec942.dts
	ln -s ${THIS_MAKEFILE_DIR}/resources/ec942_defconfig ${KERNEL_SRC_DIR}/arch/arm64/configs/ec942_defconfig
	ln -s ${THIS_MAKEFILE_DIR}/resources/vendor.its ${KERNEL_BUILD_DIR}/vendor.its
	# add to the Makefile dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-ec942.dtb
	echo "dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-ec942.dtb" >> ${KERNEL_SRC_DIR}/arch/arm64/Makefile
	rm -fr ${BUILD_DIR}/${KERNEL_VERSION}.tar.gz

${KERNEL_IMAGE_PATH}: ${KERNEL_SRC_DIR}/Makefile
	mkdir -p ${KERNEL_BUILD_DIR}
	make -C ${KERNEL_SRC_DIR} -j12 CROSS_COMPILE=aarch64-unknown-linux-gnu- ARCH=arm64 O=${KERNEL_BUILD_DIR} ec942_defconfig all

${KERNEL_VENDOR_FIT_PATH}: ${KERNEL_IMAGE_PATH}
	cd ${KERNEL_BUILD_DIR} && ${THIS_MAKEFILE_DIR}/resources/mkimage -f vendor.its -E -p 0x800 $@

clean:
	rm -rf ${BUILD_DIR}
