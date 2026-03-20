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
2) Which defconfig for u-boot ? Is evb-rk3568_defconfig ok ?
3) Which device tree for u-boot ? is the mainline evb-rk3568 ok ?
4) which atf file ? mainline or from rkbin ?
5) which op-tee file ? rk3568_tee_v2.10.bin is not in rkbin

### Questions on kernel:

6) Which version of kernel ?
7) Can we have an up-to-date device tree .dts for the board ? The one we have is de-compiled
8) which .its ? is the one in ok ?
9) Which version of mkimage ? We had some working results with the one from the SDK than the one online ?

### Questions on IO:
10) Is it possible for InHand to inverse the logic (not enabled, 1, by default). Since a new hardware version is already planned to replace the DE-9 ports this might be a good opportunity to also add this change.
Our use case is to control industrial relay (Normally open). The current hardware default state enable (close) the relay when the device is powered. This is a big issue for us since it will force us to inverse the logic in our electrical cabinet (and hope all our client will use Normally Closed realy...).

## Answers 

### Answers within the meeeting:
1, 2, 3, 4, 5, 6, 8, 9) No Mainline support. Only use SDK.
7) No .dts provided, because of IP.

### Information waiting for the next meeting:

a) Information of *what exact* versions (commit) of u-boot and kernel are the starting point for the ones that are in the SDK
b) Answers to the question 10) regarding digical IOs
 

