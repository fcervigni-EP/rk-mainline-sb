# rk-mainline-sb

###### Build/clean

```shell
# to build
make
#to clean
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

1) Created file u-boot-ec900.bb as a modification of original u-boot-ec900.bb. Blocked on signing uboot.img at this line:
#********sign_tool ver 1.39********
# Image is uboot.img
# the image did not support to sign
Are there any visible issues in our Yocto recipe ?

2) waiting for further response from IO on reboot and eventual hardware revisions.

 
