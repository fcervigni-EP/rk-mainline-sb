SHELL := /bin/bash

THIS_MAKEFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

EC_900_SDK_NAME ?= EC900-yocto-sdk-v1.0.1
EC_900_SDK_ARCHIVE_PATH = $(THIS_MAKEFILE_DIR)/$(EC_900_SDK_NAME).tar.gz
EC_900_SDK_DIR = $(THIS_MAKEFILE_DIR)/$(EC_900_SDK_NAME)
YOCTO_ROOT_DIR = $(EC_900_SDK_DIR)/yocto
OE_ENV_FILE_PATH ?= $(YOCTO_ROOT_DIR)/oe-init-build-env
RKDEVELOPTOOL_PATH ?= ./EC900-yocto-sdk-v1.0.1/yocto/u-boot/rkbin/tools/rkdeveloptool
DEPLOY_DIR_PATH ?= ./EC900-yocto-sdk-v1.0.1/yocto/build/tmp/deploy/images/ec942/
.PHONY: all build-image clean

all: build-image

${OE_ENV_FILE_PATH}:
	rm -fr $(EC_900_SDK_DIR)
	mkdir -p $(EC_900_SDK_DIR)
	@echo "Extracting EC900 SDK archive..."
	tar -xzf $(EC_900_SDK_ARCHIVE_PATH) -C $(EC_900_SDK_DIR)
	@echo "Linking u-boot-ec900.bb to ${YOCTO_ROOT_DIR}/meta-inhand/recipes-bsp/u-boot/u-boot-ec900.bb"
	rm -fr $(YOCTO_ROOT_DIR)/meta-inhand/recipes-bsp
	ln -s ${THIS_MAKEFILE_DIR}/recipes-bsp ${YOCTO_ROOT_DIR}/meta-inhand/recipes-bsp
	@echo "EC900 SDK extracted to $(EC_900_SDK_DIR)"


build-image: ${OE_ENV_FILE_PATH}
	docker run --volume ${THIS_MAKEFILE_DIR}:${THIS_MAKEFILE_DIR} \
			--workdir ${YOCTO_ROOT_DIR} \
			--rm \
			-it crops/poky:latest \
			bash -c "source ${OE_ENV_FILE_PATH} && bitbake u-boot-ec900 -c cleansstate && bitbake u-boot-ec900 -c clean && bitbake -v -D u-boot-ec900"


deploy:
	@echo '${RKDEVELOPTOOL_PATH} db ${DEPLOY_DIR_PATH}/loader.bin'
	@echo '${RKDEVELOPTOOL_PATH} wl 0x40 ${DEPLOY_DIR_PATH}/loader.bin'
	@echo '${RKDEVELOPTOOL_PATH} wl 0x4000 ${DEPLOY_DIR_PATH}/u-boot.bin'
	@echo '${RKDEVELOPTOOL_PATH} wl 0x8000 ${DEPLOY_DIR_PATH}/boot.img'

# bitbake u-boot-ec900 -c do_fitimage -f
# bitbake ec900-image -c do_updateimg
# bitbake u-boot-ec900 -c compile -f
# bitbake u-boot-ec900 -c cleanall && bitbake u-boot-ec900"

clean:
	$(MAKE) -C build_image clean
	rm -rf $(BUILD_DIR)