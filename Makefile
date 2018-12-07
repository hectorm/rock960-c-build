#!/usr/bin/make -f

MKFILE_RELPATH := $(shell printf -- '%s' '$(MAKEFILE_LIST)' | sed 's|^\ ||')
MKFILE_ABSPATH := $(shell readlink -f -- '$(MKFILE_RELPATH)')
MKFILE_DIR := $(shell dirname -- '$(MKFILE_ABSPATH)')

DIST_DIR := $(MKFILE_DIR)/dist

DOCKER_IMAGE_NAMESPACE := hectormolinero
DOCKER_IMAGE_NAME := rock960c-build
DOCKER_IMAGE_TAG := latest
DOCKER_IMAGE := $(DOCKER_IMAGE_NAMESPACE)/$(DOCKER_IMAGE_NAME)
DOCKER_VOLUME := $(DOCKER_IMAGE_NAME)-$(DOCKER_IMAGE_TAG)-out
DOCKERFILE := $(MKFILE_DIR)/Dockerfile

.PHONY: all
all: build

.PHONY: build
build: build-kernel build-u-boot build-rootfs build-system build-system-rootfs build-dist

.PHONY: build-image
build-image:
	docker build --tag '$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' --file '$(DOCKERFILE)' '$(MKFILE_DIR)'

.PHONY: build-kernel
build-kernel: build-image
	docker run -ith rock --rm --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-kernel.sh

.PHONY: build-u-boot
build-u-boot: build-image
	docker run -ith rock --rm --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-u-boot.sh

.PHONY: build-rootfs
build-rootfs: build-image
	docker run -ith rock --rm --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ --privileged \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-rootfs.sh

.PHONY: build-system
build-system: build-image
	docker run -ith rock --rm --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-system.sh

.PHONY: build-system-rootfs
build-system-rootfs: build-image
	docker run -ith rock --rm --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-system-rootfs.sh

.PHONY: build-dist
build-dist: clean-dist
	mkdir -p '$(DIST_DIR)'
	ID=$$(docker create --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ alpine) \
		&& docker cp "$${ID}":/src/out/kernel/ '$(DIST_DIR)' \
		&& docker cp "$${ID}":/src/out/u-boot/ '$(DIST_DIR)' \
		&& docker cp "$${ID}":/src/out/boot.img '$(DIST_DIR)' \
		&& docker cp "$${ID}":/src/out/rootfs.img '$(DIST_DIR)' \
		&& docker cp "$${ID}":/src/out/system.img '$(DIST_DIR)' \
		&& docker cp "$${ID}":/src/out/system-rootfs.img '$(DIST_DIR)' \
		&& docker rm "$${ID}"

.PHONY: clean
clean: clean-image clean-volume clean-dist

.PHONY: clean-image
clean-image:
	-docker rmi '$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)'

.PHONY: clean-volume
clean-volume:
	-docker volume rm '$(DOCKER_VOLUME)'

.PHONY: clean-dist
clean-dist:
	rm -rf '$(DIST_DIR)'
