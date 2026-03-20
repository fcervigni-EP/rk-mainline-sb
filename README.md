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

## Questions on u-boot (variables on top of u-boot.mk and files in /resources):
1) Which version of mainline u-boot ?
2) Which defconfig for u-boot ? Is evb-rk3568_defconfig ok ?
2) Which device tree for u-boot ? is the mainline evb-rk3568 ok ?
3) which atf file ? mainline or from rkbin ?
4) which op-tee file ? rk3568_tee_v2.10.bin is not in rkbin

## Questions on kernel (variables on top of kernel and files in /resources):

4) Which version of kernel ?
4) Can we have an up-to-date device tree .dts for the board ? The one we have is de-compiled
5) which .its ? is the one in ok ?
6) Which version of mkimage ? We had some working results with the one from the SDK than the one online ?


