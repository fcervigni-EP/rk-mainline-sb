# rk-mainline-sb

- [Build/clean](#buildclean)

###### Build/clean

```shell
# copy here the SDK .tar.gz
cp <your_location>/EC900-yocto-sdk-v1.0.1.tar.gz .

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

# Secure Boot blockage of 07.04.2026

We have received file `secureboot.md` on 04/07/2026.

We have applied all suggestions, and the current state of this project represents the suggested modifications.

The [recipe folder here](https://github.com/fcervigni-EP/rk-mainline-sb/tree/main/recipes-bsp) is used instead of the original one. (via symlink)

Here is a summary of the suggestions and how they were applied.

| File | Change | Where done                                                                                     |
|------|--------|------------------------------------------------------------------------------------------------|
| `yocto/u-boot/configs/rk3568_defconfig` | Added `CONFIG_FIT_SIGNATURE=y` | [in patch uboot_secure_boot.patch](https://github.com/fcervigni-EP/rk-mainline-sb/blob/main/recipes-bsp/u-boot/files/patches/uboot_its_required.patch)   |
| `yocto/u-boot/configs/rk3568_defconfig` | Added `CONFIG_SPL_FIT_SIGNATURE=y` | [in patch uboot_secure_boot.patch](https://github.com/fcervigni-EP/rk-mainline-sb/blob/main/recipes-bsp/u-boot/files/patches/uboot_its_required.patch)   |
| `yocto/u-boot/boot.its` | Added `required = "conf";` | [in patch uboot_its_required.patch](https://github.com/fcervigni-EP/rk-mainline-sb/blob/main/recipes-bsp/u-boot/files/patches/uboot_secure_boot.patch) |
| `yocto/meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb` | Added `openssl-native` to `DEPENDS` | [the whole file u-boot-ec900.bb from `secureboot.md` is used](https://github.com/fcervigni-EP/rk-mainline-sb/blob/main/recipes-bsp/u-boot/u-boot-ec900.bb)                               |
| `yocto/meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb` | Added RSA key generation in `do_compile:append` | [the whole file u-boot-ec900.bb from `secureboot.md` is used](https://github.com/fcervigni-EP/rk-mainline-sb/blob/main/recipes-bsp/u-boot/u-boot-ec900.bb)                                            |
| `yocto/meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb` | Changed `do_fitimage` to use `tools/mkimage` | [the whole file u-boot-ec900.bb from `secureboot.md` is used](https://github.com/fcervigni-EP/rk-mainline-sb/blob/main/recipes-bsp/u-boot/u-boot-ec900.bb)                                            |

In [this file validation_2026_04_07.txt](https://github.com/fcervigni-EP/rk-mainline-sb/blob/main/validation_2026_04_07.txt) are:
- the validation that the patches are correctly applied
- the validation checks from the `secureboot.md` that we have received. NOTE signatures are missing as of [here](https://github.com/fcervigni-EP/rk-mainline-sb/blob/main/validation_2026_04_07.txt#L118) 

The current issues is:
```
Log data follows
| DEBUG: Executing shell function do_fitimage
| NOTE: u-boot-ec900: signing boot.img with tools/mkimage (inline FIT, RSA-2048)...
| tools/mkimage Can't add hashes to FIT blob: -5
| Failed to add verification data for 'signature' signature node in 'conf' image node
| WARNING: /home/fra/work/rk-mainline-sb/EC900-yocto-sdk-v1.0.1/yocto/build/tmp/work/ec942-poky-linux/u-boot-ec900/1_2017.09-r0/temp/run.do_fitimage.13592:192 exit 255 from 'tools/mkimage -f "$TMP_ITS" -k keys/ -K u-boot.dtb -r "$TARGET_IMG"'
| WARNING: Backtrace (BB generated script):
|       #1: do_fitimage, /home/fra/work/rk-mainline-sb/EC900-yocto-sdk-v1.0.1/yocto/build/tmp/work/ec942-poky-linux/u-boot-ec900/1_2017.09-r0/temp/run.do_fitimage.13592, line 192
|       #2: main, /home/fra/work/rk-mainline-sb/EC900-yocto-sdk-v1.0.1/yocto/build/tmp/work/ec942-poky-linux/u-boot-ec900/1_2017.09-r0/temp/run.do_fitimage.13592, line 216
ERROR: Task (/home/fra/work/rk-mainline-sb/EC900-yocto-sdk-v1.0.1/yocto/build/../meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb:do_fitimage) failed with exit code '1'
```

To reproduce: instructions are in the section [the build section here](https://github.com/fcervigni-EP/rk-mainline-sb/tree/main?tab=readme-ov-file#buildclean)

NOTE: the issue above has been reproduced on a *clean* build, no previous sstate and no previous cache. 