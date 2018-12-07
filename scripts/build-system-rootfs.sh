#!/bin/sh

set -eu

SYSTEM_IMG=/src/out/system-rootfs.img
ROOTFS_IMG=/src/out/rootfs.img

ROOTFS_START=64

ROOTFS_IMG_SIZE=$(stat -L --format='%s' "${ROOTFS_IMG}")
GPT_IMG_MIN_SIZE=$((ROOTFS_IMG_SIZE))
GPT_IMG_SIZE=$((GPT_IMG_MIN_SIZE / 1024 / 1024 + 2))

# Create system image
rm -rf "${SYSTEM_IMG}"
dd if=/dev/zero of="${SYSTEM_IMG}" bs=1M count=0 seek="${GPT_IMG_SIZE}"

parted -s "${SYSTEM_IMG}" mklabel gpt
parted -s "${SYSTEM_IMG}" -- unit s mkpart rootfs "${ROOTFS_START}" -34s

# Set UUIDs
gdisk "${SYSTEM_IMG}" <<-'EOF'
	x
	g
	9843E996-DBBA-11E8-98E7-1B9399CACE72
	c
	B921B045-1DF0-41C3-AF44-4C6F280D3FAE
	w
	y
EOF

# Burn rootfs image
dd if="${ROOTFS_IMG}" of="${SYSTEM_IMG}" conv=notrunc,fsync seek="${ROOTFS_START}"
