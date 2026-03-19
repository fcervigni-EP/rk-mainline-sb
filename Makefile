SHELL := /bin/bash

THIS_MAKEFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
IMAGE_NAME ?= ec942-flash-builder
U_BOOT_DOCKER_BUILD_IMAGE ?= trini/u-boot-gitlab-ci-runner:jammy-20240227-14Mar2024
BUILD_DIR ?= $(THIS_MAKEFILE_DIR)/build

.PHONY: all build-image kernel uboot print-flash-hints clean

all: uboot print-flash-hints

build-image:
	$(MAKE) -C build_image

kernel: build-image
	docker run --rm \
		-v $(THIS_MAKEFILE_DIR):$(THIS_MAKEFILE_DIR) \
		--workdir $(THIS_MAKEFILE_DIR) \
		-e BUILD_DIR=$(BUILD_DIR) \
		-u $$(id -u):$$(id -g) \
		$(IMAGE_NAME) \
		make -f kernel.mk

uboot: kernel
	docker run --rm \
		-v $(THIS_MAKEFILE_DIR):$(THIS_MAKEFILE_DIR) \
		--workdir $(THIS_MAKEFILE_DIR) \
		-e BUILD_DIR=$(BUILD_DIR) \
		-u $$(id -u):$$(id -g) \
		$(U_BOOT_DOCKER_BUILD_IMAGE) \
		make -f uboot.mk all

print-flash-hints:
	@echo "Build complete. To flash the device, run the following commands:"
	@echo './rkdeveloptool db loader.bin'
	@echo './rkdeveloptool wl 0x40 loader.bin'
	@echo './rkdeveloptool wl 0x4000 u-boot.bin'
	@echo './rkdeveloptool wl 0x8000 boot.img'

clean:
	$(MAKE) -C build_image clean
	rm -rf $(BUILD_DIR)

