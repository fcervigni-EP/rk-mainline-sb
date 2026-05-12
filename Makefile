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
	@echo "Linking ${YOCTO_ROOT_DIR}/meta-inhand/recipes-bsp to ${THIS_MAKEFILE_DIR}/recipes-bsp"
	rm -fr $(YOCTO_ROOT_DIR)/meta-inhand/recipes-bsp
	ln -s ${THIS_MAKEFILE_DIR}/recipes-bsp ${YOCTO_ROOT_DIR}/meta-inhand/recipes-bsp
	@echo "Linking ${YOCTO_ROOT_DIR}/meta-inhand/recipes-core to ${THIS_MAKEFILE_DIR}/recipes-core"
	rm -fr $(YOCTO_ROOT_DIR)/meta-inhand/recipes-core
	ln -s ${THIS_MAKEFILE_DIR}/recipes-core ${YOCTO_ROOT_DIR}/meta-inhand/recipes-core
	@echo "Linking package-file to ${THIS_MAKEFILE_DIR}/package-file"
	rm -fr ${YOCTO_ROOT_DIR}/tools/package-file
	ln -s ${THIS_MAKEFILE_DIR}/package-file ${YOCTO_ROOT_DIR}/tools/package-file
	@echo "EC900 SDK extracted to $(EC_900_SDK_DIR)"


build-u-boot: ${OE_ENV_FILE_PATH}
	docker run --volume ${THIS_MAKEFILE_DIR}:${THIS_MAKEFILE_DIR} \
			--workdir ${YOCTO_ROOT_DIR} \
			--rm \
			-it crops/poky:latest \
			bash -c "source ${OE_ENV_FILE_PATH} && bitbake u-boot-ec900 -c cleansstate && bitbake u-boot-ec900 -c clean && bitbake -v -D -f u-boot-ec900"

build-image: ${OE_ENV_FILE_PATH}
	docker run --volume ${THIS_MAKEFILE_DIR}:${THIS_MAKEFILE_DIR} \
			--workdir ${YOCTO_ROOT_DIR} \
			--rm \
			-it crops/poky:latest \
			bash -c "source ${OE_ENV_FILE_PATH} && bitbake ec900-image -c do_updateimg"


deploy:
	@echo '${RKDEVELOPTOOL_PATH} db ${DEPLOY_DIR_PATH}/loader.bin'
	@echo '${RKDEVELOPTOOL_PATH} wl 0x40 ${DEPLOY_DIR_PATH}/loader.bin'
	@echo '${RKDEVELOPTOOL_PATH} wl 0x4000 ${DEPLOY_DIR_PATH}/u-boot.bin'
	@echo '${RKDEVELOPTOOL_PATH} wl 0x8000 ${DEPLOY_DIR_PATH}/boot.img'


# bitbake u-boot-ec900 -c do_fitimage -f
# bitbake ec900-image -c do_updateimg
# bitbake u-boot-ec900 -c compile -f
# bitbake u-boot-ec900 -c cleanall && bitbake u-boot-ec900"


## 1. Generate the private key and self-signed certificate
#mkdir -p keys
#openssl genrsa -out keys/dev.key 2048
#openssl req -batch -new -x509 -key keys/dev.key -out keys/dev.crt \
#    -days 7300 -subj "/CN=dev/"
#
## 2. Encode them (single line, no line-wrapping)
#export UBOOT_SIGNING_KEY_B64=$(base64 -w0 keys/dev.key)
#export UBOOT_SIGNING_CERT_B64=$(base64 -w0 keys/dev.crt)
#
## 3. Verify they decode correctly
#echo "$UBOOT_SIGNING_KEY_B64"  | base64 -d | openssl rsa  -noout -text 2>&1 | head -3
#echo "$UBOOT_SIGNING_CERT_B64" | base64 -d | openssl x509 -noout -text 2>&1 | head -5


clean:
	$(MAKE) -C build_image clean
	rm -rf $(BUILD_DIR)