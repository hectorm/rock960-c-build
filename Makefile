#!/usr/bin/make -f

SHELL := /bin/sh
.SHELLFLAGS := -eu -c

DOCKER := $(shell command -v docker 2>/dev/null)

DISTDIR := ./dist
DOCKERFILE := ./Dockerfile

IMAGE_REGISTRY := docker.io
IMAGE_NAMESPACE := hectormolinero
IMAGE_PROJECT := rock960-c-build
IMAGE_NAME := $(IMAGE_REGISTRY)/$(IMAGE_NAMESPACE)/$(IMAGE_PROJECT)
VOLUME_NAME := $(IMAGE_PROJECT)-out

.PHONY: all
all: build

.PHONY: build
build: build-kernel build-u-boot build-rootfs build-system-u-boot build-system-rootfs build-system-all

.PHONY: build-image
build-image:
	'$(DOCKER)' build --tag '$(IMAGE_NAME):latest' --file '$(DOCKERFILE)' ./

.PHONY: build-kernel
build-kernel: $(DISTDIR)/kernel/boot.img
$(DISTDIR)/kernel/boot.img: | build-image
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock \
		--mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ \
		'$(IMAGE_NAME):latest' /src/scripts/build-kernel.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/kernel/ '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: build-u-boot
build-u-boot: $(DISTDIR)/u-boot/u-boot.img
$(DISTDIR)/u-boot/u-boot.img: | build-image
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock \
		--mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ \
		'$(IMAGE_NAME):latest' /src/scripts/build-u-boot.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/u-boot/ '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: build-rootfs
build-rootfs: $(DISTDIR)/rootfs.img
$(DISTDIR)/rootfs.img: | build-kernel
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock --privileged \
		--mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ \
		'$(IMAGE_NAME):latest' /src/scripts/build-rootfs.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/rootfs.img '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: build-system-u-boot
build-system-u-boot: $(DISTDIR)/system-u-boot.img
$(DISTDIR)/system-u-boot.img: | build-kernel build-u-boot
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock \
		--mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ \
		'$(IMAGE_NAME):latest' /src/scripts/build-system-u-boot.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/system-u-boot.img '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: build-system-rootfs
build-system-rootfs: $(DISTDIR)/system-rootfs.img
$(DISTDIR)/system-rootfs.img: | build-rootfs
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock \
		--mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ \
		'$(IMAGE_NAME):latest' /src/scripts/build-system-rootfs.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/system-rootfs.img '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: build-system-all
build-system-all: $(DISTDIR)/system-all.img
$(DISTDIR)/system-all.img: | build-kernel build-u-boot build-rootfs
	'$(DOCKER)' run \
		--rm --interactive --tty --hostname rock \
		--mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ \
		'$(IMAGE_NAME):latest' /src/scripts/build-system-all.sh
	mkdir -p '$(DISTDIR)'
	ID=$$('$(DOCKER)' create --mount type=volume,src='$(VOLUME_NAME)',dst=/src/out/ busybox) \
		&& '$(DOCKER)' cp "$${ID}":/src/out/system-all.img '$(DISTDIR)' \
		&& '$(DOCKER)' rm "$${ID}"

.PHONY: clean
clean: clean-image clean-volume clean-dist

.PHONY: clean-image
clean-image:
	-'$(DOCKER)' rmi '$(IMAGE_NAME):latest'

.PHONY: clean-volume
clean-volume:
	-'$(DOCKER)' volume rm '$(VOLUME_NAME)'

.PHONY: clean-dist
clean-dist:
	rm -rf '$(DISTDIR)'
