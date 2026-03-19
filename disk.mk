IMG_FILE="deploy/rk3568-custom-minimal.img"
ROOTFS_FILE="${1}"
PARTITION_SCRIPT="scripts/photonicat-disk-parts-minimal.sfdisk"
BOOTFS_IMG_FILE="bootfs.img"
ROOTFS_IMG_FILE="rootfs.img"

IMG_SIZE="7168"
BOOTFS_SIZE="256"
ROOTFS_SIZE="6144"

${IMG_FILE}":
	echo "Creating disk image..."
	dd if=/dev/zero of="${IMG_FILE}" bs=1M count="${IMG_SIZE}"
	sfdisk -X gpt "${IMG_FILE}" < "${PARTITION_SCRIPT}"

	echo "Setup bootloader..."
	dd if="u-boot/deploy/idbloader.img" of="${IMG_FILE}" seek=64 conv=notrunc
	dd if="u-boot/deploy/u-boot.itb" of="${IMG_FILE}" seek=16384 conv=notrunc


${BOOTFS_IMG_FILE}:
	dd if=/dev/zero of="${BOOTFS_IMG_FILE}" bs=1M count="${BOOTFS_SIZE}"
	mkfs.vfat -F 32 "${BOOTFS_IMG_FILE}"

	TMP_MOUNT_DIR="$(mktemp -d)"
	mkdir -p "${TMP_MOUNT_DIR}/bootfs"
	mount "${BOOTFS_IMG_FILE}" "${TMP_MOUNT_DIR}/bootfs"

	cp -rv "$(BUILD_DIR)/bootfs/*" "${TMP_MOUNT_DIR}/bootfs/"

	umount -f "${TMP_MOUNT_DIR}/bootfs"
	rmdir "${TMP_MOUNT_DIR}/bootfs"
	gzip -f "${BOOTFS_IMG_FILE}"

${ROOTFS_IMG_FILE}:
	echo "Creating rootfs..."
	dd if=/dev/zero of="${ROOTFS_IMG_FILE}" bs=1M count="${ROOTFS_SIZE}"
	mkfs.ext4 -F "${ROOTFS_IMG_FILE}"

	mkdir -p "${TMP_MOUNT_DIR}/rootfs"
	mount "${ROOTFS_IMG_FILE}" "${TMP_MOUNT_DIR}/rootfs"

	tar -xpf "${ROOTFS_FILE}" --xattrs --xattrs-include='*' -C "${TMP_MOUNT_DIR}/rootfs"
	tar -xf "kernel/deploy/kmods.tar.gz" -C "${TMP_MOUNT_DIR}/rootfs/usr"

	umount -f "${TMP_MOUNT_DIR}/rootfs"
	rmdir "${TMP_MOUNT_DIR}/rootfs"
	gzip -f "${ROOTFS_IMG_FILE}"

disk:
	echo "Creating bootfs..."

${IMG_FILE}":
	echo "Creating disk image..."
	dd if=/dev/zero of="${IMG_FILE}" bs=1M count="${IMG_SIZE}"
	sfdisk -X gpt "${IMG_FILE}" < "${PARTITION_SCRIPT}"

	echo "Setup bootloader..."
	dd if="u-boot/deploy/idbloader.img" of="${IMG_FILE}" seek=64 conv=notrunc
	dd if="u-boot/deploy/u-boot.itb" of="${IMG_FILE}" seek=16384 conv=notrunc



	rmdir "${TMP_MOUNT_DIR}"

${BOOTFS_IMG_FILE}:
	echo "Making system image..."
	zcat "${BOOTFS_IMG_FILE}.gz" | dd of="${IMG_FILE}" bs=1M seek=32 conv=notrunc
	zcat "${ROOTFS_IMG_FILE}.gz" | dd of="${IMG_FILE}" bs=1M seek="$(expr 32 + ${BOOTFS_SIZE})" conv=notrunc
	gzip -f "${IMG_FILE}"
	echo "Create system image completed."