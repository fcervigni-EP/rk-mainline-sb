# rk-mainline-sb

###### Build/clean

```shell
# copy here the SDK .tar.gz
cp <your_location>/EC900-yocto-sdk-v1.0.1.tar.gz .
# copy your keys folder into the files/ folder. it is a secret, do not commit it.
cd -r <your_location>/keys/ files/

# build
make

# clean
make clean
```


# Meeting 20.03.2026

## Goal

Boot mainline u-boot and kernel. No secure-boot, it will be done next week.
## Questions 
### Questions on u-boot:
1) Which version of mainline u-boot ?
   It is Rockchip’s U-Boot, and the Makefile in the root directory is version 2017.09.
2) Which defconfig for u-boot ? Is evb-rk3568_defconfig ok ?
   In the u-boot-ec900.bb recipe, ARG_BOARD is set to rk3568, and the defconfig file used is u-boot/configs/rk3568_defconfig.
3) Which device tree for u-boot ? is the mainline evb-rk3568 ok ?
   CONFIG_DEFAULT_DEVICE_TREE="rk3568-evb" corresponds to arch/arm/dts/rk3568-evb.dts.
4) which atf file ? mainline or from rkbin ?
   BL31 comes from the path specified in the INI file within rkbin; RK3568TRUST.ini points to bin/rk35/rk3568_bl31_v1.43.elf.
5) which op-tee file ? rk3568_tee_v2.10.bin is not in rkbin
   In RK3568TRUST.ini, the BL32 (OP-TEE) file is bin/rk35/rk3568_bl32_v2.10.bin.
### Questions on kernel:

6) Which version of kernel ?
   In meta-inhand/recipes-kernel/linux/linux-ec900_5.10.bb, LINUX_VERSION ?= "5.10"
7) Can we have an up-to-date device tree .dts for the board ? The one we have is de-compiled
   Only the DTB file adapted for the EC900 hardware can be used. In the Makefile, it is already defined as dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3568-ec942.dtb.
8) which .its ? is the one in ok ?
   When building the kernel boot.img (FIT), you should use kernel/boot.its from the repository as the template (and ensure that BOOT_ITS points to it during the build; otherwise, mkimage will fall back to the Android boot format via mkbootimg, which is a different path from FIT). In meta-inhand’s linux-ec900_5.10.bb, BOOT_ITS is not set. If you always expect FIT, you should export BOOT_ITS=.../boot.its in the environment or recipe to align with the SDK behavior.
9) Which version of mkimage ? We had some working results with the one from the SDK than the one online ?
   mkimage version 2017.09-gcd388a8602-201015 #ldq, In the Rockchip workflow, mkimage is typically paired with specific versions of U-Boot/rkbin (due to details such as FIT, signing, alignment, etc.). The mkimage tool provided by mainline or distributions may behave slightly differently, which can result in builds succeeding but causing boot or verification issues.
   
### Questions on IO:
10) Is it possible for InHand to inverse the logic (not enabled, 1, by default). Since a new hardware version is already planned to replace the DE-9 ports this might be a good opportunity to also add this change.
Our use case is to control industrial relay (Normally open). The current hardware default state enable (close) the relay when the device is powered. This is a big issue for us since it will force us to inverse the logic in our electrical cabinet (and hope all our client will use Normally Closed realy...).
  DO is an open-drain output. Please refer to section 2.3.5 ‘Switching Output interface (Digital Output)’ in the following link for wiring: https://help.inhand.com/portal/en/kb/articles/ec900#235_Switching_Output_interface_Digital_Output
For the default state of DO, you can modify /usr/local/bin/ec_init.sh under the section # Initialize Digital output [gpio491 ~ gpio494]. After echo 1 > /sys/class/gpio/gpio491/active_low, you can add the default value (for example): echo 0 > /sys/class/gpio/gpio491/value.

## Answers 

### Answers within the meeeting:
- 1, 2, 3, 4, 5, 6, 8, 9 : No Mainline support. Only use SDK.
- 7 : No .dts provided, because of IP.

### Information waiting for the next meeting of 20.03.2026:

a) Information of *what exact* versions (commit) of u-boot and kernel are the starting point for the ones that are in the SDK

b) Answers to the question 10) regarding digical IOs
 
# Meeting 27.03.2026


1. waiting for further response from IO on reboot and eventual hardware revisions.

2. Blocked on building:

Created file u-boot-ec900.bb as a modification of original u-boot-ec900.bb. Blocked on signing uboot.img at this line:

```shell
   #********sign_tool ver 1.39********
   # Image is uboot.img
   # the image did not support to sign
```

Are there any visible issues in our Yocto recipe ?

# Next Meeting
 
#### In response to the suggestions from **secure-boot-yocto-ec900.md** file: 

1. Enable **`CONFIG_FIT_SIGNATURE`**, **`CONFIG_SPL_FIT_SIGNATURE`**, etc. in **`rk3568_defconfig`** or a **fragment**.

A: Done in [this patch](https://github.com/fcervigni-EP/rk-mainline-sb/blob/main/files/patches/uboot_secure_boot.patch) 

2. Update **`u-boot-ec900.bb`**: wire **`fit.sh`** or an equivalent signing path in `do_compile`; use **`mkimage` with `-k`/`-K`** in **`do_fitimage`**.

A: Done in [this line](https://github.com/fcervigni-EP/rk-mainline-sb/blob/cd26a1053e61f6ae0a3616fa9c952f157909e03c/u-boot-ec900.bb#L83), as when CONFIG_FIT_SIGNATURE is y and --burn-key-hash is activated, then in fit_core.sh the **-K** is used

3. Supply **`u-boot/keys/dev.{key,pubkey,crt}`** (prefer **bbappend + SRC_URI** or a secrets directory; **do not commit private keys** to public repos).

Done, there is a **non commited** /keys folder in side the [files folder, which is sym-linked in the recipe](https://github.com/fcervigni-EP/rk-mainline-sb/tree/main/files) which is then included [here](https://github.com/fcervigni-EP/rk-mainline-sb/blob/cd26a1053e61f6ae0a3616fa9c952f157909e03c/u-boot-ec900.bb#L15)

4. Align **`kernel/boot.its`** with algorithm and key name.

As expressed in the notes secure-boot-yocto-ec900.md, it seems as the boot.its is already defining the 'dev' key, isn't it ?

5. As needed, align **`RK3568TRUST.ini`**, **`ec900-image.bb`**, and **`tools/`** with partition policy.

Not very clear for this las tine, could I have sample code ? 


#### _open questions_:

a) The information regarding AVB, it should not regard us, correct ? Thank you in advance

b) How can we improve [our recipe](https://github.com/fcervigni-EP/rk-mainline-sb/blob/main/u-boot-ec900-original.bb) so not to be blocked on this line when signing uboot.img ?

```shell
   #********sign_tool ver 1.39********
   # Image is uboot.img
   # the image did not support to sign
```

# EC900 RK3568 Secure Boot Implementation Guide

## Overview

This document describes the complete implementation of Secure Boot for the EC900 Yocto project
based on the Rockchip RK3568 SoC. It covers background analysis, all file modifications,
build procedure, and verification results.

---

## 1. Background and Boot Chain Analysis

### 1.1 RK3568 Boot Chain

The RK3568 platform uses a multi-stage boot process:

```
BootROM (on-chip, immutable)
  └─→ loader.bin  (DDR init + SPL — from Rockchip rkbin prebuilt binaries)
        └─→ trust.img  (BL31: ARM Trusted Firmware + BL32: OP-TEE)
              └─→ uboot.img  (U-Boot, compiled by this project)
                    └─→ boot.img  (Kernel FIT image: kernel + DTB + resource)
                          └─→ Linux Kernel
```

### 1.2 FIT Image Format

Rockchip uses the U-Boot **Flattened Image Tree (FIT)** format for all firmware images.
A FIT image is a structured binary containing multiple sub-images (kernel, DTB, etc.)
along with metadata, hashes, and — when Secure Boot is enabled — RSA signatures.

### 1.3 Secure Boot Trust Chain

With Secure Boot enabled, each stage cryptographically verifies the next:

| Verifier     | Verified Image | Key Location              |
|--------------|----------------|---------------------------|
| SPL          | `uboot.img`    | Embedded in SPL's DTB     |
| U-Boot       | `boot.img`     | Embedded in U-Boot's DTB  |

> **Note on BootROM verification of SPL:** Full hardware root-of-trust requires burning
> the RSA public key hash into the RK3568 OTP (One-Time Programmable) fuses, which forces
> the BootROM to verify `loader.bin` before execution. This step requires the
> `rk_sign_tool` from Rockchip and is a physical, irreversible manufacturing operation.
> The changes in this document implement the SPL→U-Boot→Kernel software verification chain,
> which can be enabled and tested without burning fuses.

### 1.4 Pre-existing Security Infrastructure

The project already contained significant (but inactive) security infrastructure:

| Component | Status Before | Description |
|-----------|---------------|-------------|
| `CONFIG_RSA=y` | Present | RSA library in U-Boot |
| `CONFIG_SPL_RSA=y` | Present | RSA library in SPL |
| `CONFIG_FIT=y` | Present | FIT image format support |
| `CONFIG_ANDROID_AVB=y` | Present | Android Verified Boot |
| `CONFIG_OPTEE_CLIENT=y` | Present | OP-TEE integration |
| `CONFIG_ROCKCHIP_OTP=y` | Present | OTP memory driver |
| `boot.its` signature node | Present | RSA-2048 PSS signature **template** |
| `CONFIG_FIT_SIGNATURE` | **MISSING** | Actual signature verification |
| `CONFIG_SPL_FIT_SIGNATURE` | **MISSING** | SPL-level verification |
| RSA signing keys | **MISSING** | `keys/dev.key`, `keys/dev.crt` |
| `required = "conf"` | **MISSING** | Enforcement flag in boot.its |

The `rkbin/tools/mkimage` (prebuilt Rockchip binary) was being used to build `boot.img`
but reports `"Signing / verified boot not supported (CONFIG_FIT_SIGNATURE undefined)"`,
meaning signatures were never actually applied despite the template existing in `boot.its`.

---

## 2. Files Modified

Three files were modified to enable Secure Boot:

```
yocto/u-boot/configs/rk3568_defconfig          ← Enable FIT signature verification
yocto/u-boot/boot.its                           ← Enforce signature requirement
yocto/meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb  ← Key generation + signed build
```

---

## 3. Change 1 — `yocto/u-boot/configs/rk3568_defconfig`

### What Changed

Added two configuration options immediately after the existing RSA block (lines 205–209):

```kconfig
# === BEFORE (lines 205–209) ===
CONFIG_RSA=y
CONFIG_SPL_RSA=y
CONFIG_RSA_N_SIZE=0x200
CONFIG_RSA_E_SIZE=0x10
CONFIG_RSA_C_SIZE=0x20

# === AFTER (lines 205–211) ===
CONFIG_RSA=y
CONFIG_SPL_RSA=y
CONFIG_RSA_N_SIZE=0x200
CONFIG_RSA_E_SIZE=0x10
CONFIG_RSA_C_SIZE=0x20
CONFIG_FIT_SIGNATURE=y
CONFIG_SPL_FIT_SIGNATURE=y
```

### Why These Options

**`CONFIG_FIT_SIGNATURE=y`**

Defined in `Kconfig` as:
```kconfig
config FIT_SIGNATURE
    bool "Enable signature verification of FIT uImages"
    depends on DM
    select RSA
    select CONSOLE_DISABLE_CLI
```

This option:
- Compiles RSA verification into U-Boot proper
- Causes `tools/mkimage` to be built **with** signing support
  (`-DCONFIG_FIT_SIGNATURE` is passed to the host compiler via `tools/Makefile`)
- Enables `fit_check_sign` and `fit_info` host tools
- Is automatically detected by `scripts/fit-core.sh`:
  ```bash
  if grep -q '^CONFIG_FIT_SIGNATURE=y' .config ; then
      ARG_SIGN="y"
  fi
  ```
  When `ARG_SIGN=y`, the build script signs `uboot.img` using RSA keys.

**`CONFIG_SPL_FIT_SIGNATURE=y`**

Defined in `Kconfig` as:
```kconfig
config SPL_FIT_SIGNATURE
    bool "Enable signature verification of FIT firmware within SPL"
    depends on SPL_DM
    select SPL_FIT
    select SPL_RSA
```

This option:
- Compiles RSA verification into SPL (Secondary Program Loader)
- Causes `scripts/fit-core.sh` to embed the public key into `spl/u-boot-spl.dtb`
  so SPL can verify `uboot.img` at runtime
- Is checked explicitly by `scripts/fit-core.sh`:
  ```bash
  if ! grep -q '^CONFIG_SPL_FIT_SIGNATURE=y' .config ; then
      echo "ERROR: CONFIG_SPL_FIT_SIGNATURE is disabled"
      exit 1
  fi
  ```

**Implicit enablements via `CONFIG_FIT_SIGNATURE`:**

| Config | Behavior |
|--------|----------|
| `CONFIG_FIT_ENABLE_SHA256_SUPPORT` | Enabled by default when FIT_SIGNATURE is set |
| `CONFIG_FIT_ENABLE_RSASSA_PSS_SUPPORT` | Enabled by default (depends on FIT_SIGNATURE) |
| RSA software/hardware acceleration | Reuses existing `CONFIG_DM_CRYPTO` + `CONFIG_ROCKCHIP_CRYPTO_V2` |

---

## 4. Change 2 — `yocto/u-boot/boot.its`

### What Changed

Added `required = "conf";` to the `signature` node inside the `conf` configuration:

```dts
// === BEFORE ===
            signature {
                algo = "sha256,rsa2048";
                padding = "pss";
                key-name-hint = "dev";
                sign-images = "fdt", "kernel", "multi";
            };

// === AFTER ===
            signature {
                algo = "sha256,rsa2048";
                padding = "pss";
                key-name-hint = "dev";
                required = "conf";
                sign-images = "fdt", "kernel", "multi";
            };
```

### Full File After Modification

```dts
/*
 * Copyright (C) 2020 Rockchip Electronics Co., Ltd
 *
 * SPDX-License-Identifier: GPL-2.0
 */

/dts-v1/;
/ {
    description = "U-Boot FIT source file for arm";

    images {
        fdt {
            data = /incbin/("@KERNEL_DTB@");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            load = <0xffffff00>;

            hash {
                algo = "sha256";
            };
        };

        kernel {
            data = /incbin/("@KERNEL_IMG@");
            type = "kernel";
            arch = "arm64";
            os = "linux";
            compression = "none";
            entry = <0xffffff01>;
            load = <0xffffff01>;

            hash {
                algo = "sha256";
            };
        };

        resource {
            data = /incbin/("@RESOURCE_IMG@");
            type = "multi";
            arch = "arm64";
            compression = "none";

            hash {
                algo = "sha256";
            };
        };
    };

    configurations {
        default = "conf";

        conf {
            rollback-index = <0x00>;
            fdt = "fdt";
            kernel = "kernel";
            multi = "resource";

            signature {
                algo = "sha256,rsa2048";
                padding = "pss";
                key-name-hint = "dev";
                required = "conf";
                sign-images = "fdt", "kernel", "multi";
            };
        };
    };
};
```

### Why `required = "conf"`

The `required` property in a FIT signature node controls enforcement behavior in U-Boot:

| Value | Behavior |
|-------|----------|
| *(absent)* | Signature is present and verified, but boot continues even if it fails |
| `"image"` | Individual images are required to be signed |
| `"conf"` | The **configuration** (and all images it references) must be signed and valid; U-Boot **refuses to boot** if verification fails |

Without `required = "conf"`, enabling `CONFIG_FIT_SIGNATURE` still verifies the
signature but does not enforce it — an attacker could modify the kernel and the device
would still boot. The `required = "conf"` field closes this gap.

### Signing Algorithm

The template already specified:
- `algo = "sha256,rsa2048"` — SHA-256 hash + RSA-2048 asymmetric signature
- `padding = "pss"` — RSASSA-PSS padding scheme (RFC 8017, more secure than PKCS#1 v1.5)
- `key-name-hint = "dev"` — tells mkimage to look for `dev.key` / `dev.crt` in the key directory

---

## 5. Change 3 — `yocto/meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb`

### Full File After All Modifications

```bitbake
inherit python3-dir

require recipes-bsp/u-boot/u-boot.inc
require recipes-bsp/u-boot/u-boot-common.inc

PROVIDES = "virtual/bootloader"
DEPENDS += " linux-ec900 bc-native dtc-native"

PV = "2017.09"

LIC_FILES_CHKSUM = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"
SRC_URI = "git://${TOPDIR}/../u-boot;protocol=file;branch=master;"
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

        # Generate RSA signing keys if not already present
        if [ ! -f keys/dev.key ]; then
            mkdir -p keys
            openssl genrsa -out keys/dev.key 2048
            openssl req -batch -new -x509 -key keys/dev.key -out keys/dev.crt \
                -days 7300 -subj "/CN=dev/"
            openssl rsa -in keys/dev.key -pubout -out keys/dev.pubkey
            bbnote "${PN}: Generated RSA-2048 signing keys in ${B}/keys/"
        fi

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

    # Use U-Boot compiled mkimage (supports FIT signing) to sign boot.img.
    # -k keys/       : directory containing dev.key and dev.crt
    # -K u-boot.dtb  : embed public key into u-boot.dtb for U-Boot runtime verification
    # -r             : mark configuration as required (boot fails if sig invalid)
    tools/mkimage -f "$TMP_ITS" -k keys/ -K u-boot.dtb -E -p 0x800 -r "$TARGET_IMG"

    rm -f "$TMP_ITS"
}
do_fitimage[nostamp] = "1"
do_fitimage[depends] += "linux-ec900:do_deploy"

addtask do_fitimage after do_compile before do_install
```

### Change Details

#### 5.1 Added `openssl-native` to `DEPENDS`

```diff
-DEPENDS:append = " coreutils-native ${PYTHON_PN}-pyelftools-native util-linux-native"
+DEPENDS:append = " coreutils-native ${PYTHON_PN}-pyelftools-native util-linux-native openssl-native"
```

`openssl-native` provides the `openssl` command-line tool in the Yocto build
environment, used to generate the RSA-2048 key pair.

#### 5.2 Added RSA Key Generation in `do_compile:append`

```bash
# Generate RSA signing keys if not already present
if [ ! -f keys/dev.key ]; then
    mkdir -p keys
    openssl genrsa -out keys/dev.key 2048
    openssl req -batch -new -x509 -key keys/dev.key -out keys/dev.crt \
        -days 7300 -subj "/CN=dev/"
    openssl rsa -in keys/dev.key -pubout -out keys/dev.pubkey
    bbnote "${PN}: Generated RSA-2048 signing keys in ${B}/keys/"
fi
```

This runs before `./make.sh rk3568 --spl-new`. The generated files are:

| File | Description |
|------|-------------|
| `${B}/keys/dev.key` | RSA-2048 private key (PEM). Used to sign FIT images. |
| `${B}/keys/dev.crt` | X.509 self-signed certificate (PEM). Contains the public key; `mkimage` extracts the public key from this file. |
| `${B}/keys/dev.pubkey` | RSA public key (PEM). Referenced by Rockchip `fit-core.sh`. |

The key name `dev` must match `key-name-hint = "dev"` in `boot.its`.

**Why keys are generated here (before `make.sh`):**

`scripts/fit-core.sh` detects `CONFIG_FIT_SIGNATURE=y` in `.config` and sets
`ARG_SIGN="y"`, which calls `check_rsa_keys()` to verify key existence **before**
signing. If keys are missing, the build aborts with an error.

#### 5.3 Updated `do_fitimage` to Use `tools/mkimage` with Signing

```diff
-rkbin/tools/mkimage -f "$TMP_ITS"  -E -p 0x800 "$TARGET_IMG"
+tools/mkimage -f "$TMP_ITS" -k keys/ -K u-boot.dtb -E -p 0x800 -r "$TARGET_IMG"
```

| Flag | Value | Description |
|------|-------|-------------|
| `-f` | `$TMP_ITS` | Input: the FIT image source (`.its`) file |
| `-k` | `keys/` | Directory containing `dev.key` and `dev.crt` for signing |
| `-K` | `u-boot.dtb` | Output: embed the RSA public key into this DTB (used by U-Boot at runtime) |
| `-E` | — | Store image data externally (after FIT header), not inline |
| `-p` | `0x800` | External data starts at offset 0x800 bytes |
| `-r` | — | Mark the configuration as `required` in the output FIT |

**Why `rkbin/tools/mkimage` cannot be used for signing:**

The prebuilt `rkbin/tools/mkimage` was compiled without `CONFIG_FIT_SIGNATURE`.
Its `--help` output confirms: `"Signing / verified boot not supported"`.

**Why `tools/mkimage` works:**

When `CONFIG_FIT_SIGNATURE=y` is added to the defconfig, the U-Boot build system
adds `-DCONFIG_FIT_SIGNATURE` to the host compiler flags in `tools/Makefile`:

```makefile
ifdef CONFIG_FIT_SIGNATURE
HOST_EXTRACFLAGS += -DCONFIG_FIT_SIGNATURE
endif
```

This compiles the RSA signing/verification code (from `lib/rsa/rsa-sign.c`,
`common/image-sig.c`) into the host-side `tools/mkimage` binary.

---

## 6. Internal Mechanism: How `make.sh` Signs `uboot.img`

When `CONFIG_FIT_SIGNATURE=y` is in `.config`, the Rockchip `scripts/fit-core.sh`
automatically performs the following signing steps (inside `fit_gen_uboot_itb()`):

```
Step 1: Check if u-boot.dtb already has a /signature node
        → If NOT: run mkimage to sign uboot.itb AND embed public key into u-boot.dtb

Step 2: Final pack — run mkimage to sign uboot.itb AND embed public key into spl/u-boot-spl.dtb
        → At this point, the ITS re-reads u-boot.dtb (which already has the public key from Step 1)
        → The resulting uboot.itb contains u-boot.dtb WITH the embedded public key

Step 3: Repack SPL binary:
        cat spl/u-boot-spl-nodtb.bin + spl/u-boot-spl.dtb → spl/u-boot-spl.bin
        → SPL binary now contains the public key in its appended DTB
```

After this process:
- `uboot.img` (Rockchip FIT for U-Boot) contains `u-boot.dtb` **with the RSA public key**,
  so U-Boot can verify `boot.img` at runtime.
- `loader.bin` (SPL) has the RSA public key in its appended DTB, so SPL can verify
  `uboot.img` at runtime.

---

## 7. Build Procedure

> **Important:** Bitbake must not be run as `root`. Run the build as a non-root user.

### 7.1 Clean Previous U-Boot Build

```bash
cd /home/weiyf/Desktop/git/EC900-yocto/yocto
source poky/oe-init-build-env build
bitbake u-boot-ec900 -c cleansstate
```

### 7.2 Build U-Boot with Secure Boot

```bash
bitbake u-boot-ec900
```

This executes the following task sequence:

| Task | Action |
|------|--------|
| `do_fetch` | Fetch U-Boot source from local git |
| `do_unpack` | Unpack source to `${B}` (build directory) |
| `do_configure` | Run `make rk3568_defconfig` to generate `.config` |
| `do_compile` | Compile U-Boot (creates `tools/mkimage` with signing support) |
| `do_compile:append` | Generate RSA keys → run `make.sh rk3568 --spl-new` (signs `uboot.img`) |
| `do_fitimage` | Sign `boot.img` using `tools/mkimage -k keys/ -K u-boot.dtb -r` |
| `do_install` | Install artifacts |
| `do_deploy` | Deploy `loader.bin`, `uboot.img`, `boot.img` to `${DEPLOY_DIR_IMAGE}` |

### 7.3 Build the Complete Image

```bash
bitbake ec900-image
```

This builds the full system image including rootfs and the signed firmware.

### 7.4 Expected Key Build Log Messages

During `do_compile:append`, you should see output similar to:

```
NOTE: u-boot-ec900: Generated RSA-2048 signing keys in .../build/keys/
...
## Checking RSA keys ...
## Generating U-Boot FIT Image ...
## Signing uboot.img with RSA-2048 key ...
## Adding RSA public key into u-boot.dtb
## pack loader with new: spl/u-boot-spl.bin
```

During `do_fitimage`, you should see:

```
FIT description: U-Boot FIT source file for arm
 Image 0 (fdt)
  Hash algo:    sha256
  Hash value:   ...
 Image 1 (kernel)
  Hash algo:    sha256
  Hash value:   ...
 Image 2 (resource)
  Hash algo:    sha256
  Hash value:   ...
 Configuration 0 (conf)
  Sign algo:    sha256,rsa2048:dev
```

---

## 8. Verification

### 8.1 Verify the Defconfig Was Applied

After `do_configure`, confirm the generated `.config` contains the new options:

```bash
# Path: ${WORKDIR}/build/.config inside the Yocto work directory
# Example path:
grep "FIT_SIGNATURE" \
  yocto/build/tmp/work/ec942-poky-linux/u-boot-ec900/1_2017.09-r0/build/.config
```

Expected output:
```
CONFIG_FIT_SIGNATURE=y
CONFIG_SPL_FIT_SIGNATURE=y
```

### 8.2 Verify `tools/mkimage` Has Signing Support

```bash
BDIR=yocto/build/tmp/work/ec942-poky-linux/u-boot-ec900/1_2017.09-r0/build
${BDIR}/tools/mkimage --help 2>&1 | grep -E "sign|key|Signing"
```

Expected output (confirms signing is compiled in):
```
Signing / verified boot options: [-E] [-k keydir] [-K dtb] [ -c <comment>] [-p addr] [-r] [-N engine]
          -k => set directory containing private keys
          -K => write public keys to this .dtb file
          -r => mark keys used as 'required' in dtb
```

If the output shows `"Signing / verified boot not supported"`, the defconfig was not
applied correctly — check that the clean and rebuild steps were completed.

### 8.3 Verify RSA Keys Were Generated

```bash
BDIR=yocto/build/tmp/work/ec942-poky-linux/u-boot-ec900/1_2017.09-r0/build
ls -la ${BDIR}/keys/
```

Expected output:
```
-rw-------  1 user user 1704 Apr  3 12:54 dev.key
-rw-r--r--  1 user user 1099 Apr  3 12:54 dev.crt
-rw-r--r--  1 user user  451 Apr  3 12:54 dev.pubkey
```

### 8.4 Verify the Public Key Is Embedded in `u-boot.dtb`

The public key must be in `u-boot.dtb` for U-Boot to verify `boot.img` at runtime:

```bash
BDIR=yocto/build/tmp/work/ec942-poky-linux/u-boot-ec900/1_2017.09-r0/build

# Check the /signature node exists
fdtget -l ${BDIR}/u-boot.dtb /signature

# Check the key properties
fdtget -t s ${BDIR}/u-boot.dtb /signature/key-dev algo
fdtget -t s ${BDIR}/u-boot.dtb /signature/key-dev required
fdtget -t u ${BDIR}/u-boot.dtb /signature/key-dev rsa,num-bits
```

Expected output:
```
key-dev
sha256,rsa2048
conf
2048
```

### 8.5 Verify the Signature in `boot.img`

Inspect the FIT image header for the signature node:

```bash
DEPLOY=yocto/build/tmp/deploy/images/ec942
fdtdump ${DEPLOY}/boot.img 2>&1 | grep -A 15 "signature {"
```

Expected output (truncated):
```
signature {
    hashed-strings = <0x00000000 0x000000f5>;
    hashed-nodes = "/", "/configurations", "/configurations/conf", ...;
    timestamp = <0x...>;
    signer-version = "2017.09";
    signer-name = "mkimage";
    value = <0x... (64 words = 256 bytes = RSA-2048 signature) ...>;
    algo = "sha256,rsa2048";
    padding = "pss";
    key-name-hint = "dev";
    sign-images = "fdt", "kernel", "multi";
};
```

### 8.6 End-to-End Signature Verification with `fit_check_sign`

This is the definitive verification step — it runs the same RSA verification
code path that U-Boot uses at runtime:

```bash
BDIR=yocto/build/tmp/work/ec942-poky-linux/u-boot-ec900/1_2017.09-r0/build
DEPLOY=yocto/build/tmp/deploy/images/ec942

${BDIR}/tools/fit_check_sign \
    -f ${DEPLOY}/boot.img \
    -k ${BDIR}/u-boot.dtb
```

**Actual output from verification run:**

```
Signature check OK
Verifying Hash Integrity ... sha256,rsa2048:dev+
## Loading kernel from FIT Image at 75e5fc400000 ...
   Using 'conf' configuration
   Verifying Hash Integrity ...
sha256,rsa2048:dev+
OK

   Trying 'kernel' kernel subimage
     Description:  unavailable
     Created:      Fri Apr  3 12:54:45 2026
     Type:         Kernel Image
     Compression:  uncompressed
     Data Size:    38242816 Bytes = 37346.50 KiB = 36.47 MiB
     Architecture: AArch64
     OS:           Linux
     Load Address: 0xffffff01
     Entry Point:  0xffffff01
     Hash algo:    sha256
     Hash value:   372f622293a95d18ad0d555205d37d9d2eb2254ad7b551fbe59309bb4fe55e95
   Verifying Hash Integrity ...
sha256+
OK

   Loading Kernel Image from 0x75e5fc41c800 to 0x75e5f311d010 ... OK

## Loading fdt from FIT Image at 75e5fc400000 ...
   Using 'conf' configuration
   Trying 'fdt' fdt subimage
     Description:  unavailable
     Created:      Fri Apr  3 12:54:45 2026
     Type:         Flat Device Tree
     Compression:  uncompressed
     Data Size:    114497 Bytes = 111.81 KiB = 0.11 MiB
     Architecture: AArch64
     Load Address: 0xffffff00
     Hash algo:    sha256
     Hash value:   5dc8031816b8402c2e91a68a74087fc5221978a4a32671ddb8be4f72840b6f39
   Verifying Hash Integrity ...
sha256+
OK

   Loading Flat Device Tree from 0x75e5fc400800 to 0x75e5fec90010 ... OK
```

**Exit code: `0` — verification passed.**

The output `sha256,rsa2048:dev+` means:
- Algorithm: SHA-256 hash with RSA-2048 signature
- Key: `dev` (matches `key-name-hint = "dev"` in `boot.its`)
- `+` suffix: verification **passed**

---

## 9. Secure Boot Behavior at Runtime

### 9.1 Normal Boot (Signed Image)

When a correctly signed `boot.img` is present:

```
U-Boot:  Verifying Hash Integrity ... sha256,rsa2048:dev+ OK
U-Boot:  Booting kernel ...
```

### 9.2 Tampered or Unsigned Image

If `boot.img` is replaced with an unsigned or modified image, U-Boot prints:

```
U-Boot:  Verifying Hash Integrity ... sha256,rsa2048:dev- BAD
ERROR: Failed to validate required configuration 'conf'
FAILED: Bad Data Hash
```

U-Boot then halts — the kernel does not boot.

---

## 10. Production Hardening Notes

The changes in this document implement the software verification chain. For production
devices, the following additional steps are required:

### 10.1 Key Management

The current recipe auto-generates keys inside the Yocto build directory (`${B}/keys/`).
This is acceptable for development but **not** for production because:
- Keys are regenerated on a clean build, breaking compatibility with previously flashed devices
- Keys in the build directory may not be backed up securely

**Recommended approach for production:**

```bitbake
# In u-boot-ec900.bb, replace auto-generation with:
SRC_URI += "file://keys/dev.key \
            file://keys/dev.crt \
            file://keys/dev.pubkey"

do_compile:append() {
    mkdir -p ${B}/keys
    cp ${WORKDIR}/keys/dev.key ${B}/keys/
    cp ${WORKDIR}/keys/dev.crt ${B}/keys/
    cp ${WORKDIR}/keys/dev.pubkey ${B}/keys/
    ...
}
```

Store the private key in a Hardware Security Module (HSM) or secure key store.
Never commit the private key to a public repository.

### 10.2 OTP Fuse Programming (Hardware Root of Trust)

To extend the trust chain from BootROM level, burn the SHA-256 hash of the
public key into RK3568 OTP fuses using Rockchip's `rk_sign_tool`:

```bash
# This is a ONE-WAY, IRREVERSIBLE operation
rk_sign_tool kk --pub keys/dev.pubkey   # Program public key hash into OTP
```

After fuse programming, the BootROM will verify `loader.bin` before execution,
completing the full hardware root-of-trust chain:

```
BootROM (verifies via OTP hash)
  └─→ loader.bin / SPL  ← hardware-verified
        └─→ uboot.img   ← SPL-verified (CONFIG_SPL_FIT_SIGNATURE)
              └─→ boot.img  ← U-Boot-verified (CONFIG_FIT_SIGNATURE + required="conf")
                    └─→ Linux Kernel
```

### 10.3 Rollback Protection

The FIT image supports a `rollback-index` field to prevent firmware downgrade attacks.
Enable it in U-Boot defconfig:

```kconfig
CONFIG_FIT_ROLLBACK_PROTECT=y
CONFIG_SPL_FIT_ROLLBACK_PROTECT=y
```

And pass rollback indices during the build:
```bash
./make.sh rk3568 --spl-new \
    --rollback-index-uboot 1 \
    --rollback-index-boot 1
```

Rollback indices are stored in OP-TEE's secure storage (RPMB) and verified against
the `rollback-index` field in the FIT image.

---

## 11. File Change Summary

| File | Change | Purpose |
|------|--------|---------|
| `yocto/u-boot/configs/rk3568_defconfig` | Added `CONFIG_FIT_SIGNATURE=y` | Enable U-Boot FIT signature verification |
| `yocto/u-boot/configs/rk3568_defconfig` | Added `CONFIG_SPL_FIT_SIGNATURE=y` | Enable SPL FIT signature verification |
| `yocto/u-boot/boot.its` | Added `required = "conf";` | Enforce signature; reject unsigned kernels |
| `yocto/meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb` | Added `openssl-native` to `DEPENDS` | Provide `openssl` CLI for key generation |
| `yocto/meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb` | Added RSA key generation in `do_compile:append` | Auto-generate `dev.key`, `dev.crt`, `dev.pubkey` |
| `yocto/meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb` | Changed `do_fitimage` to use `tools/mkimage` | Sign `boot.img` with RSA; embed public key in `u-boot.dtb` |

**Total: 3 files modified, 7 logical changes.**
