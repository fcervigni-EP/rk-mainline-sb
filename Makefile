SHELL := /bin/bash

THIS_MAKEFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

EC_900_SDK_NAME ?= EC900-yocto-sdk-v1.0.1
EC_900_SDK_ARCHIVE_PATH = $(THIS_MAKEFILE_DIR)/$(EC_900_SDK_NAME).tar.gz
EC_900_SDK_DIR = $(THIS_MAKEFILE_DIR)/$(EC_900_SDK_NAME)
YOCTO_ROOT_DIR = $(EC_900_SDK_DIR)/yocto
U_BOOT_ROOT_DIR = $(YOCTO_ROOT_DIR)/u-boot
U_BOOT_ORIGINAL_DEFCONFIG_FILE_PATH ?= $(YOCTO_ROOT_DIR)/u-boot/configs/original_rk3568_defconfig
U_BOOT_DEFCONFIG_FILE_PATH ?= $(YOCTO_ROOT_DIR)/u-boot/configs/rk3568_defconfig
U_BOOT_DEFCONFIG_APPEND_FILE_PATH ?= $(THIS_MAKEFILE_DIR)/rk3568_defconfig.append
OE_ENV_FILE_PATH ?= $(YOCTO_ROOT_DIR)/oe-init-build-env

.PHONY: all build-image clean

all: build-image




${OE_ENV_FILE_PATH}:
	rm -fr $(EC_900_SDK_DIR)
	mkdir -p $(EC_900_SDK_DIR)
	@echo "Extracting EC900 SDK archive..."
	tar -xzf $(EC_900_SDK_ARCHIVE_PATH) -C $(EC_900_SDK_DIR)
	@echo "Saving original U-Boot defconfig file to $(U_BOOT_ORIGINAL_DEFCONFIG_FILE_PATH)"
	cp -v ${U_BOOT_DEFCONFIG_FILE_PATH} ${U_BOOT_ORIGINAL_DEFCONFIG_FILE_PATH}
	@echo "EC900 SDK extracted to $(EC_900_SDK_DIR)"


${U_BOOT_DEFCONFIG_FILE_PATH}: ${OE_ENV_FILE_PATH}
	@echo "Composing defconfig file as original ${U_BOOT_DEFCONFIG_FILE_PATH} plus append file ..."
	cd $(U_BOOT_ROOT_DIR) && git checkout master
	cat ${U_BOOT_ORIGINAL_DEFCONFIG_FILE_PATH} ${U_BOOT_DEFCONFIG_APPEND_FILE_PATH} > ${U_BOOT_DEFCONFIG_FILE_PATH}
	git commit -am "Updated defconfig"
	@echo "defconfig ends with ..."
	tail -n 10 ${U_BOOT_DEFCONFIG_FILE_PATH}


build-image: ${U_BOOT_DEFCONFIG_FILE_PATH}
	docker run --volume ${EC_900_SDK_DIR}:${EC_900_SDK_DIR} \
			--workdir ${YOCTO_ROOT_DIR} \
			--rm \
			-it crops/poky:latest \
			bash -c "source ${OE_ENV_FILE_PATH} && bitbake u-boot-ec900 -c cleanall && bitbake u-boot-ec900"


clean:
	$(MAKE) -C build_image clean
	rm -rf $(BUILD_DIR)

