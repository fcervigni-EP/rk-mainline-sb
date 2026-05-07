SUMMARY = "EC900 image"
LICENSE = "MIT"

IMAGE_FEATURES += "splash ssh-server-openssh debug-tweaks"

inherit core-image
DEPENDS += " u-boot-ec900"

do_updateimg() {
    TOOLS_DIR=$(realpath -q "${TOPDIR}/../tools")

    ln -sf "${PN}-${MACHINE}.ext4" "rootfs.img"

	cp ${TOOLS_DIR}/package-file ./
	cp ${TOOLS_DIR}/parameter.txt ./

	TAG=RK$(hexdump -s 21 -n 4 -e '4 "%c"' loader.bin | rev)
	"${TOOLS_DIR}/afptool" -pack ./ update.raw.img
	"${TOOLS_DIR}/rkImageMaker" -$TAG loader.bin update.raw.img update.img -os_type:androidos
}

do_updateimg[dirs] = "${DEPLOY_DIR_IMAGE}"
do_updateimg[nostamp] = "1"
do_updateimg[depends] += "u-boot-ec900:do_deploy"

addtask do_updateimg after do_image_complete

ROOTFS_POSTPROCESS_COMMAND:append = " install_lib_modules;"
install_lib_modules() {
    tar -xf ${DEPLOY_DIR_IMAGE}/modules-${MACHINE}.tgz -C ${IMAGE_ROOTFS}/
}

ROOTFS_POSTPROCESS_COMMAND:append = " install_inhand_overlay;"
install_inhand_overlay() {
    cp -rf ${TOPDIR}/../overlay/* ${IMAGE_ROOTFS}/
}
