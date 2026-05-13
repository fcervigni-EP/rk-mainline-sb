inherit python3-dir

require recipes-bsp/u-boot/u-boot.inc
require recipes-bsp/u-boot/u-boot-common.inc

PROVIDES = "virtual/bootloader"
DEPENDS += " linux-ec900 bc-native dtc-native"

PV = "2017.09"

LIC_FILES_CHKSUM = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"
SRC_URI = "git://${TOPDIR}/../u-boot;protocol=file;branch=master; \
    file://patches/uboot_secure_boot.patch \
    file://patches/uboot-no-disabling-cli.patch \
    file://patches/uboot-boot-delay.patch \
    file://patches/uboot-mender-boot.patch \
    file://patches/uboot_its_addresses.patch \
    file://patches/uboot_its_required.patch"
SRCREV = "${AUTOREV}"

# Generate Rockchip style loader binaries
RK_LOADER_BIN = "loader.bin"
UBOOT_BINARY = "uboot.img"
KERNEL_BINARY = "boot.img"

DEPENDS:append = " ${PYTHON_PN}-native"

# Needed for packing BSP u-boot
DEPENDS:append = " coreutils-native ${PYTHON_PN}-pyelftools-native util-linux-native openssl-native"

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

        mkdir -p keys
        if [ -n "${EPOS_SIGNING_KEY_B64}" ] && [ -n "${EPOS_SIGNING_CERT_B64}" ]; then
            bbnote "${PN}: Using injected signing keys from EPOS_SIGNING_KEY_B64 / EPOS_SIGNING_CERT_B64"
            printf '%s' "${EPOS_SIGNING_KEY_B64}"  | base64 -d > keys/dev.key
            printf '%s' "${EPOS_SIGNING_CERT_B64}" | base64 -d > keys/dev.crt
            chmod 600 keys/dev.key
        else
            bbfatal "${PN}: EPOS_SIGNING_KEY_B64 and EPOS_SIGNING_CERT_B64 must be set"
        fi

        openssl rsa -in keys/dev.key -pubout -out keys/dev.pubkey


        # Pack rockchip loader images (with FIT_SIGNATURE enabled,
        # make.sh automatically signs uboot.img and embeds the public key
        # into u-boot.dtb for subsequent boot.img verification)
        ./make.sh rk3568 --spl-new
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

    fdtput -r u-boot.dtb /signature/key-dev/hash@c 2>/dev/null || true
    fdtput -r u-boot.dtb /signature/key-dev/hash@np 2>/dev/null || true
    # do not re-sign the image, as the public key is already embedded in u-boot.dtb and the private key is used by make.sh to sign uboot.img
    tools/mkimage -f "$TMP_ITS" -k keys/ -E -p 0x800 "$TARGET_IMG"

    rm -f "$TMP_ITS"


    # Build and sign script
	ITS="${S}/boot-scr.its"
	BOOTSCR_TXT="${S}/boot-scr.txt"
	TARGET="${DEPLOY_DIR_IMAGE}/boot.scr"

	TMP_ITS=$(mktemp)
	cp "$ITS" "$TMP_ITS"
	sed -i -e "s~@BOOTSCR_TXT@~$(realpath -q "$BOOTSCR_TXT")~" "$TMP_ITS"

	# Use the freshly compiled mkimage so PSS/RSA support matches u-boot's
	# own verifier.  -k keys/ picks up dev.key generated in do_compile.
	# No -K (do not modify u-boot.dtb here, same reason as do_fitimage).
	tools/mkimage -f "$TMP_ITS" -k keys/ -E -p 0x800 "$TARGET"

	rm -f "$TMP_ITS"

	# Versioned copy + symlink, mirroring loader.bin / boot.img layout.
	install "$TARGET" "${DEPLOY_DIR_IMAGE}/boot.scr-${PV}"
	ln -sf "boot.scr-${PV}" "${DEPLOY_DIR_IMAGE}/boot.scr"
}
do_fitimage[nostamp] = "1"
do_fitimage[depends] += "linux-ec900:do_deploy"

addtask do_fitimage after do_compile before do_install