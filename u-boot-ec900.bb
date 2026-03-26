inherit python3-dir

require recipes-bsp/u-boot/u-boot.inc
require recipes-bsp/u-boot/u-boot-common.inc

PROVIDES = "virtual/bootloader"
DEPENDS += " linux-ec900 bc-native dtc-native"

PV = "2017.09"

LIC_FILES_CHKSUM = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"
SRC_URI = "git://${TOPDIR}/../u-boot;protocol=file;branch=master; \
           file://patches/uboot_secure_boot.patch \
           file://patches/uboot_rkbin_activate_sign_flag.patch \
           "
SRCREV = "${AUTOREV}"

# Generate Rockchip style loader binaries
RK_LOADER_BIN = "loader.bin"
UBOOT_BINARY = "uboot.img"
KERNEL_BINARY = "boot.img"

DEPENDS:append = " ${PYTHON_PN}-native"

# Needed for packing BSP u-boot
DEPENDS:append = " coreutils-native ${PYTHON_PN}-pyelftools-native util-linux-native"

do_configure:prepend() {
	# Make sure we use /usr/bin/env ${PYTHON_PN} for scripts
	for s in `grep -rIl python ${S}`; do
		sed -i -e '1s|^#!.*python[23]*|#!/usr/bin/env ${PYTHON_PN}|' $s
	done

	# Support python3
	sed -i -e 's/\(open([^,]*\))/\1, "rb")/' \
		-e 's/print >> \([^,]*\), *\(.*\),*$/print(\2, file=\1)/' \
		-e 's/print \(.*\)$/print(\1)/' \
		${S}/arch/arm/mach-rockchip/make_fit_atf.py

	# Remove unneeded stages from make.sh
	sed -i -e '/^select_tool/d' -e '/^clean/d' -e '/^\t*make/d' -e '/which python2/{n;n;s/exit 1/true/}' ${S}/make.sh

	if [ "x${RK_ALLOW_PREBUILT_UBOOT}" = "x1" ]; then
		# Copy prebuilt images
		if [ -e "${S}/${UBOOT_BINARY}" ]; then
			bbnote "${PN}: Found prebuilt images."
			mkdir -p ${B}/prebuilt/
			mv ${S}/*.bin ${S}/*.img ${B}/prebuilt/
		fi
	fi

	[ ! -e "${S}/.config" ] || make -C ${S} mrproper

	sed -i 's/ found;/ found = NULL;/' ${S}/lib/avb/libavb/avb_slot_verify.c

    # signing
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Before configure, defconfig"
    tail "${S}/configs/rk3568_defconfig"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Before configure, setting.ini"
    tail "${S}/rkbin/tools/setting.ini"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> OK"
}


do_compile:append() {
	cd ${B}

	if [ -e "${B}/prebuilt/${UBOOT_BINARY}" ]; then
		bbnote "${PN}: Using prebuilt images."
		ln -sf ${B}/prebuilt/*.bin ${B}/prebuilt/*.img ${B}/
	else
		# Prepare needed files
		for d in make.sh scripts configs arch/arm/mach-rockchip rkbin; do
            bbnote "cp -rT ${S}/${d} ${d}"
			cp -rT ${S}/${d} ${d}
		done

		# Pack rockchip loader images
		./make.sh rk3568 --spl-new  --boot_img boot.img
	fi

	ln -sf *_loader*.bin "${RK_LOADER_BIN}"
}

do_deploy:append() {
	cd ${B}

	for binary in "${RK_LOADER_BIN}" "${KERNEL_BINARY}";do
		[ -f "${binary}" ] || continue
		install "${binary}" "${DEPLOYDIR}/${binary}-${PV}"
		ln -sf "${binary}-${PV}" "${DEPLOYDIR}/${binary}"
	done
}

do_fitimage() {
	cd ${B}

	TARGET_IMG="${DEPLOY_DIR_IMAGE}/${KERNEL_BINARY}"
	ITS="${S}/boot.its"
	KERNEL_IMG="${DEPLOY_DIR_IMAGE}/Image-${MACHINE}.bin"
	RAMDISK_IMG=""
	KERNEL_DTB="${DEPLOY_DIR_IMAGE}/rk3568-${MACHINE}.dtb"
	RESOURCE_IMG=${DEPLOY_DIR_IMAGE}/resource.img

	if [ ! -f "$ITS" ]; then
		echo "$ITS not exists!"
		exit 1
	fi

	TMP_ITS=$(mktemp)
	cp "$ITS" "$TMP_ITS"

	sed -i -e "s~@KERNEL_DTB@~$(realpath -q "$KERNEL_DTB")~" \
		-e "s~@KERNEL_IMG@~$(realpath -q "$KERNEL_IMG")~" \
		-e "s~@RAMDISK_IMG@~$(realpath -q "$RAMDISK_IMG")~" \
		-e "s~@RESOURCE_IMG@~$(realpath -q "$RESOURCE_IMG")~" "$TMP_ITS"

	rkbin/tools/mkimage -f "$TMP_ITS"  -E -p 0x800 "$TARGET_IMG"

	# signing
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Signing"
	#./rk_sign_tool sf ......
	
	rm -f "$TMP_ITS"
}
do_fitimage[nostamp] = "1"
do_fitimage[depends] += "linux-ec900:do_deploy"

addtask do_fitimage after do_compile before do_install