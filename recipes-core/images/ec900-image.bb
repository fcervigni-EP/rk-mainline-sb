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

	# Generate misc.img with AvbABData at sector offset 4 (= byte 2048).
	# SPL and U-Boot both use this format (libavb AvbABData, big-endian CRC).
	# slot_a: priority=15, tries_remaining=7, successful_boot=1 (active, verified)
	# slot_b: priority=14, tries_remaining=7, successful_boot=0 (standby)
	python3 - << 'PYEOF'
import struct, zlib

MISC_SIZE = 4 * 1024 * 1024
AB_METADATA_OFFSET = 4 * 512  # AB_METADATA_OFFSET = 4 sectors = 2048 bytes

# AvbABData (32 bytes, all integers in network/big-endian byte order)
# struct: magic[4], version_major, version_minor, reserved1[2],
#         slots[2]×{priority,tries_remaining,successful_boot,reserved[1]},
#         last_boot, reserved2[11], crc32(big-endian)
magic         = b'\x00AB0'          # AVB_AB_MAGIC
version_major = 1
version_minor = 0
reserved1     = b'\x00\x00'
# AvbABSlotData: plain bytes, NO bitfields
slot_a = bytes([15, 0, 1, 0])       # priority=15, tries=0, successful=1 (tries must be 0 when successful=1)
slot_b = bytes([14, 7, 0, 0])       # priority=14, tries=7, successful=0, reserved=0
last_boot  = 0
reserved2  = b'\x00' * 11

data28 = (magic +
          bytes([version_major, version_minor]) + reserved1 +
          slot_a + slot_b +
          bytes([last_boot]) + reserved2)  # 28 bytes before CRC

crc_val = zlib.crc32(data28) & 0xFFFFFFFF
crc_be  = struct.pack('>I', crc_val)       # big-endian (network byte order)

avb_ab_data = data28 + crc_be             # 32 bytes total

misc_img = bytearray(MISC_SIZE)
misc_img[AB_METADATA_OFFSET:AB_METADATA_OFFSET + 32] = avb_ab_data
with open('misc.img', 'wb') as f:
    f.write(bytes(misc_img))
print("misc.img (AvbABData): slot_a=pri15/tries0/success1, slot_b=pri14/tries7/success0, crc32=0x{:08x}".format(crc_val))
PYEOF

	# Generate oem.img: 128 MB ext4 filesystem, A/B-shared, that holds
	# the signed boot.scr at its root.  This partition is the *single
	# source of truth* for the boot dispatcher and is intentionally
	# decoupled from rootfs_a/_b so OTA cannot replace it inadvertently.
	# Size matches the 'oem' partition declared in parameter.txt
	# (0x40000 sectors x 512 = 128 MB).
	OEM_STAGE=$(mktemp -d)
	if [ -f boot.scr ]; then
		cp boot.scr "${OEM_STAGE}/boot.scr"
	else
		bbwarn "boot.scr missing in DEPLOY_DIR_IMAGE; oem.img will be empty"
	fi
	rm -f oem.img
	# 128 MB = 131072 KB; dd is more portable than `truncate` which is
	# not available in bitbake's sandboxed task environment.
	dd if=/dev/zero of=oem.img bs=1024 count=131072 status=none
	mke2fs -F -L oem -t ext4 -d "${OEM_STAGE}" oem.img > /dev/null
	rm -rf "${OEM_STAGE}"

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

# boot.scr lives in the (A/B-shared) oem partition, not in rootfs.
# do_updateimg builds oem.img with /boot.scr at the root.  See the
# CONFIG_BOOTCOMMAND comment in evb_rk3568.h for the full rationale.
do_updateimg[depends] += "u-boot-ec900:do_bootscr"
