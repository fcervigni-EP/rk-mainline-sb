#!/bin/bash
set -e

IMAGE_NAME="ec942-flash-builder"
THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# build dir
BUILD_DIR="${PWD}/build"
U_BOOT_DOCKER_BUILD_IMAGE="trini/u-boot-gitlab-ci-runner:jammy-20240227-14Mar2024"


# ensure that the build image is built and up-to-date
make -C build_image

docker run --rm \
		-v ${THIS_SCRIPT_DIR}:${THIS_SCRIPT_DIR} \
		--workdir ${THIS_SCRIPT_DIR} \
		-e BUILD_DIR=${BUILD_DIR} \
		-u $(id -u):$(id -g) \
		${IMAGE_NAME} \
		make -f kernel.mk

docker run --rm \
		-v ${THIS_SCRIPT_DIR}:${THIS_SCRIPT_DIR} \
		--workdir ${THIS_SCRIPT_DIR} \
		-e BUILD_DIR=${BUILD_DIR} \
		-u $(id -u):$(id -g) \
		${U_BOOT_DOCKER_BUILD_IMAGE} \
		make -f uboot.mk all

echo

echo "Build complete. To flash the device, run the following commands:"
echo './rkdeveloptool db loader.bin'
echo './rkdeveloptool wl 0x40 loader.bin'
echo './rkdeveloptool wl 0x4000 u-boot.bin'
echo './rkdeveloptool wl 0x8000 boot.img'