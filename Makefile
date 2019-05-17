#!/usr/bin/make -f

SHELL := /bin/sh
.SHELLFLAGS := -eu -c

DOCKER := $(shell command -v docker 2>/dev/null)

DISTDIR := ./dist

DOCKER_IMAGE_NAMESPACE := hectormolinero
DOCKER_IMAGE_NAME := rock960c-build
DOCKER_IMAGE_TAG := latest
DOCKER_IMAGE := $(DOCKER_IMAGE_NAMESPACE)/$(DOCKER_IMAGE_NAME)
DOCKER_VOLUME := $(DOCKER_IMAGE_NAME)-$(DOCKER_IMAGE_TAG)-out
DOCKERFILE := ./Dockerfile

.PHONY: all
all: build

.PHONY: build
build: build-kernel build-u-boot build-rootfs build-system-u-boot build-system-rootfs build-system-all

.PHONY: build-image
build-image:
	'$(DOCKER)' build --tag '$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' --file '$(DOCKERFILE)' ./

.PHONY: build-kernel
build-kernel: $(DISTDIR)/kernel/boot.img
$(DISTDIR)/kernel/boot.img: | build-image
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock \
		--mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-kernel.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/kernel/ '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: build-u-boot
build-u-boot: $(DISTDIR)/u-boot/u-boot.img
$(DISTDIR)/u-boot/u-boot.img: | build-image
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock \
		--mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-u-boot.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/u-boot/ '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: build-rootfs
build-rootfs: $(DISTDIR)/rootfs.img
$(DISTDIR)/rootfs.img: | build-kernel
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock --privileged \
		--mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-rootfs.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/rootfs.img '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: build-system-u-boot
build-system-u-boot: $(DISTDIR)/system-u-boot.img
$(DISTDIR)/system-u-boot.img: | build-kernel build-u-boot
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock \
		--mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-system-u-boot.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/system-u-boot.img '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: build-system-rootfs
build-system-rootfs: $(DISTDIR)/system-rootfs.img
$(DISTDIR)/system-rootfs.img: | build-rootfs
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock \
		--mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-system-rootfs.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/system-rootfs.img '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: build-system-all
build-system-all: $(DISTDIR)/system-all.img
$(DISTDIR)/system-all.img: | build-kernel build-u-boot build-rootfs
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock \
		--mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ \
		'$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)' /src/scripts/build-system-all.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='${DOCKER_VOLUME}',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/system-all.img '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: clean
clean: clean-image clean-volume clean-dist

.PHONY: clean-image
clean-image:
	-'$(DOCKER)' rmi '$(DOCKER_IMAGE):$(DOCKER_IMAGE_TAG)'

.PHONY: clean-volume
clean-volume:
	-'$(DOCKER)' volume rm '$(DOCKER_VOLUME)'

.PHONY: clean-dist
clean-dist:
	rm -rf '$(DISTDIR)'
