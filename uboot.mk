####### VARIABLES FOR MEETING 20.03.2026
MAINLINE_UBOOT_VERSION=2026.01-rc2
MAINLINE_UBOOT_DEFCONFIG = evb-rk3568_defconfig
TRUSTED_FIRMWARE_A_B31 = ${RKBIN_SRC_DIR}/bin/rk35/rk3568_bl31_v1.45.elf
# OPTEE_BIN = ${RKBIN_SRC_DIR}/bin/rk35/rk3568_tee_v2.10.bin does not exist ?
########################################


MAINLINE_UBOOT_SRC_DIR = ${BUILD_DIR}/mainline-u-boot-src-${MAINLINE_UBOOT_VERSION}
MAINLINE_UBOOT_MAKEFILE_PATH = ${MAINLINE_UBOOT_SRC_DIR}/Makefile
MAINLINE_UBOOT_BUILD_DIR = ${BUILD_DIR}/mainline-u-boot-build-${MAINLINE_UBOOT_VERSION}
MAINLINE_UBOOT_SPL_PATH = ${MAINLINE_UBOOT_BUILD_DIR}/idbloader.img
RKBIN_VERSION = 74213af1e952c4683d2e35952507133b61394862
RKBIN_REPO = https://github.com/rockchip-linux/rkbin
RKBIN_SRC_DIR = ${BUILD_DIR}/rkbin-${RKBIN_VERSION}
RKBIN_DDR_BIN=${RKBIN_SRC_DIR}/bin/rk35/rk3568_ddr_1560MHz_v1.23.bin

all: ${MAINLINE_UBOOT_SPL_PATH}


# download rkbin
${BUILD_DIR}/${RKBIN_VERSION}.tar.gz:
	mkdir -p ${BUILD_DIR}
	wget ${RKBIN_REPO}/archive/${RKBIN_VERSION}.tar.gz -O $@

${RKBIN_DDR_BIN}: ${BUILD_DIR}/${RKBIN_VERSION}.tar.gz
	cd ${BUILD_DIR} && tar -xvmf $<

##### download u-boot sources
${MAINLINE_UBOOT_MAKEFILE_PATH}:
	mkdir -p ${MAINLINE_UBOOT_SRC_DIR}
	wget https://github.com/u-boot/u-boot/archive/refs/tags/v${MAINLINE_UBOOT_VERSION}.tar.gz -O ${MAINLINE_UBOOT_SRC_DIR}.tar.gz
	cd ${MAINLINE_UBOOT_SRC_DIR} && tar --strip-components=1 -xvmf ${MAINLINE_UBOOT_SRC_DIR}.tar.gz
	rm -fr ${MAINLINE_UBOOT_SRC_DIR}.tar.gz
	# add our own configurations
	#cat ${THIS_MAKEFILE_DIR}/configs/evb-rk3568_defconfig.append >> ${MAINLINE_UBOOT_DEFCONFIG_FILE_PATH}

${MAINLINE_UBOOT_SPL_PATH}: ${MAINLINE_UBOOT_MAKEFILE_PATH} ${RKBIN_DDR_BIN}
	mkdir -p ${MAINLINE_UBOOT_BUILD_DIR}
	make -j$(nproc) \
		-C ${MAINLINE_UBOOT_SRC_DIR} \
		O=${MAINLINE_UBOOT_BUILD_DIR} \
		BL31=${TRUSTED_FIRMWARE_A_B31} \
		CROSS_COMPILE=/opt/gcc-13.2.0-nolibc/aarch64-linux/bin/aarch64-linux- \
		ROCKCHIP_TPL=${RKBIN_DDR_BIN} \
		${MAINLINE_UBOOT_DEFCONFIG} \
		all

clean:
	rm -fr {${MAINLINE_UBOOT_SPL_PATH}}