# EC900 Yocto Secure Boot (FIT Signature Verification)

This document describes the FIT signature chains for the current tree layout (`meta-inhand`, `u-boot-ec900.bb`, `linux-ec900`, Rockchip `fit-core.sh` / `fit.sh`), which files to change to enable secure boot, and what to update when rotating keys.

---

## 1. FIT signature chains (two independent paths)

| Image | Verified by | Chain meaning |
|-------|-------------|---------------|
| **`uboot.itb` / `uboot.img`** | **SPL** using the public key in **`spl/u-boot-spl.dtb`** | **SPL → U-Boot**, not “U-Boot → kernel” |
| **`boot.itb` / `boot.img`** | **U-Boot** using the public key in **`u-boot.dtb`** | **U-Boot → kernel (FIT)** |

Both may share the same RSA material under `keys/`, but they are **two FIT images**, **two DTBs where the public key is embedded**, and **two stages (SPL vs U-Boot)**.

Script references: `u-boot/scripts/fit-core.sh` (`fit_gen_uboot_itb` / `fit_gen_boot_itb`), `u-boot/scripts/fit.sh`.

---

## 2. Current project state (summary)

| Area | Notes |
|------|--------|
| **`u-boot/configs/rk3568_defconfig`** | Includes `CONFIG_FIT`, `CONFIG_SPL_FIT_HW_CRYPTO`, AVB/OPTEE, etc.; **`CONFIG_FIT_SIGNATURE` / `CONFIG_SPL_FIT_SIGNATURE` are not present by default** unless added manually. |
| **`kernel/boot.its`** | Under `configurations/conf` there is already a **`signature`** block (`sha256,rsa2048`, `key-name-hint = "dev"`). |
| **`do_fitimage` in `meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb`** | Uses `mkimage -f ... -E -p 0x800` **without** `-k` / `-K`, so **`boot.img` is not signed with the private key**. |
| **`u-boot/keys/`** | Usually **missing** in the repo; Rockchip scripts default to **`u-boot/keys/dev.key`, `dev.pubkey`, `dev.crt`**. |

Changing only `boot.its` without U-Boot config and packaging commands is generally **not** enough for a full verified-boot chain.

---

## 3. Enabling FIT-style secure boot: files to change or touch

### 3.1 U-Boot configuration (verification support)

| File | Role |
|------|------|
| **`u-boot/configs/rk3568_defconfig`** | Or a **fragment `.cfg` merged by the recipe**: at minimum **`CONFIG_FIT_SIGNATURE=y`** and **`CONFIG_SPL_FIT_SIGNATURE=y`** (`fit-core.sh` requires SPL when signing `uboot.itb`). Optionally: **`CONFIG_FIT_ENABLE_RSA4096_SUPPORT`** (must match `rsa4096` in the ITS), rollback options, etc. |

### 3.2 U-Boot packaging (`uboot.itb` / `uboot.img` / loader)

| File | Role |
|------|------|
| **`meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb`** | `do_compile:append` currently runs **`./make.sh rk3568 --spl-new`**. For full FIT signing you usually need to invoke **`./scripts/fit.sh`** from the build directory with **`--spl-new`, `--ini-loader`, `--ini-trust`** (aligned with SoC and ini files). `fit.sh` chains `uboot` / `boot` / loader steps. |
| **`u-boot/make.sh`** | Usually unchanged; must remain compatible with the upstream `fit.sh` flow. |
| **`u-boot/rkbin/RKTRUST/RK3568TRUST.ini`** | Points to BL31/BL32, etc.; **not** FIT RSA key files, but tied to loader packaging—do not confuse with the FIT signing flow. |

### 3.3 Kernel `boot.img` (U-Boot verifies kernel FIT)

| File | Role |
|------|------|
| **`kernel/boot.its`** | Keep key name and algorithm (RSA2048/4096) consistent; `key-name-hint` must match the signature node policy in the device trees. |
| **`meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb` → `do_fitimage()`** | Change `mkimage` to pass **`-k ${KEY_DIR}`** and **`-K <built u-boot.dtb>`** so the public key is written into **`u-boot.dtb`** (same idea as `fit_gen_boot_itb`). |

### 3.4 Images and tools (as needed)

| File | Role |
|------|------|
| **`meta-inhand/recipes-core/images/ec900-image.bb`** | Produces `update.img`; if partition/vbmeta policy changes, sync **`${TOPDIR}/../tools/package-file`** and **`parameter.txt`**. |
| **`meta-inhand/conf/machine/ec900.conf` or `local.conf`** | Variables can gate signing, key paths, prebuilt U-Boot, etc. |

---

## 4. Rotating keys: what to update

### 4.1 Key material (core)

Default paths in Rockchip `fit-core.sh`:

- **`u-boot/keys/dev.key`** (private key)
- **`u-boot/keys/dev.pubkey`**
- **`u-boot/keys/dev.crt`**

Example DT node: `SIGNATURE_KEY_NODE="/signature/key-dev"`, matching **`key-name-hint = "dev"`** in **`kernel/boot.its`**.

**Key rotation:** replace these three files (or keep filenames and replace contents). If you rename the key (not `dev`), also update:

- **`key-name-hint`** in **`kernel/boot.its`**
- **`SIGNATURE_KEY_NODE`** in **`u-boot/scripts/fit-core.sh`** (or a patch that keeps naming consistent)

### 4.2 Build artifacts (must rebuild after key change)

- **`spl/u-boot-spl.dtb`**, **`u-boot.dtb`**: public keys are injected via **`mkimage -K`**. You **cannot** only replace `boot.img` without rebuilding U-Boot.

### 4.3 Manufacturing / hardware (if enabled)

If you use **`CONFIG_SPL_FIT_HW_CRYPTO`**, **`--burn-key-hash`**, etc., the **key hash** may need to be programmed in eFuse on the line—that is process/tooling, not a single source file.

---

## 5. Android AVB (alongside FIT)

| Notes |
|-------|
| **`CONFIG_ANDROID_AVB`** and related options use the **AVB / vbmeta** stack; keys and tools are usually **different** from `u-boot/keys/dev.*`. |
| Requires **`avbtool`**-signed **vbmeta**, partition layout, and packaging scripts; **meta-inhand may not ship a full AVB recipe**—plan separately. |

---

## 6. Quick checklist

**Enable FIT secure boot (SPL → U-Boot → kernel):**

1. Enable **`CONFIG_FIT_SIGNATURE`**, **`CONFIG_SPL_FIT_SIGNATURE`**, etc. in **`rk3568_defconfig`** or a **fragment**.
2. Update **`u-boot-ec900.bb`**: wire **`fit.sh`** or an equivalent signing path in `do_compile`; use **`mkimage` with `-k`/`-K`** in **`do_fitimage`**.
3. Supply **`u-boot/keys/dev.{key,pubkey,crt}`** (prefer **bbappend + SRC_URI** or a secrets directory; **do not commit private keys** to public repos).
4. Align **`kernel/boot.its`** with algorithm and key name.
5. As needed, align **`RK3568TRUST.ini`**, **`ec900-image.bb`**, and **`tools/`** with partition policy.

**Rotate keys:**

- Update the **three files under `u-boot/keys/`** and, if renamed, **`boot.its` / `fit-core.sh`** key naming.
- **Rebuild** the full U-Boot chain (SPL DTB, U-Boot DTB) and **re-sign `boot.img`**.

---

## 7. Reference paths (in-tree)

| Path |
|------|
| `u-boot/scripts/fit-core.sh` |
| `u-boot/scripts/fit.sh` |
| `u-boot/configs/rk3568_defconfig` |
| `kernel/boot.its` |
| `meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb` |
| `u-boot/rkbin/RKTRUST/RK3568TRUST.ini` |

---
