#!/bin/sh

set -eu

SYSTEM_IMG=/src/out/system-all.img
ROOTFS_IMG=/src/out/rootfs.img
BOOT_IMG=/src/out/boot.img
UBOOT_IMG=/src/out/u-boot/uboot.img
IDBLOADER_IMG=/src/out/u-boot/idbloader.img
TRUST_IMG=/src/out/u-boot/trust.img

# http://opensource.rock-chips.com/wiki_Partitions
LOADER1_SIZE=8000
RESERVED1_SIZE=128
RESERVED2_SIZE=8192
LOADER2_SIZE=8192
ATF_SIZE=8192
BOOT_SIZE=229376

LOADER1_START=64
RESERVED1_START=$((LOADER1_START + LOADER1_SIZE))
RESERVED2_START=$((RESERVED1_START + RESERVED1_SIZE))
LOADER2_START=$((RESERVED2_START + RESERVED2_SIZE))
ATF_START=$((LOADER2_START + LOADER2_SIZE))
BOOT_START=$((ATF_START + ATF_SIZE))
ROOTFS_START=$((BOOT_START + BOOT_SIZE))

ROOTFS_IMG_SIZE=$(stat -L --format='%s' "${ROOTFS_IMG}")
GPT_IMG_MIN_SIZE=$((ROOTFS_IMG_SIZE + (LOADER1_SIZE + RESERVED1_SIZE + RESERVED2_SIZE + LOADER2_SIZE + ATF_SIZE + BOOT_SIZE + 35) * 512))
GPT_IMG_SIZE=$((GPT_IMG_MIN_SIZE / 1024 / 1024 + 2))

# Create system image
rm -rf "${SYSTEM_IMG}"
dd if=/dev/zero of="${SYSTEM_IMG}" bs=1M count=0 seek="${GPT_IMG_SIZE}"

parted -s "${SYSTEM_IMG}" mklabel gpt
parted -s "${SYSTEM_IMG}" unit s mkpart loader1 "${LOADER1_START}" "$((RESERVED1_START - 1))"
# parted -s "${SYSTEM_IMG}" unit s mkpart reserved1 "${RESERVED1_START}" "$((RESERVED2_START - 1))"
# parted -s "${SYSTEM_IMG}" unit s mkpart reserved2 "${RESERVED2_START}" "$((LOADER2_START - 1))"
parted -s "${SYSTEM_IMG}" unit s mkpart loader2 "${LOADER2_START}" "$((ATF_START - 1))"
parted -s "${SYSTEM_IMG}" unit s mkpart trust "${ATF_START}" "$((BOOT_START - 1))"
parted -s "${SYSTEM_IMG}" unit s mkpart boot "${BOOT_START}" "$((ROOTFS_START - 1))"
parted -s "${SYSTEM_IMG}" set 4 boot on
parted -s "${SYSTEM_IMG}" -- unit s mkpart rootfs "${ROOTFS_START}" -34s

# Set UUIDs
gdisk "${SYSTEM_IMG}" <<-'EOF'
	x
	g
	149AB1F9-6DE9-EC4D-92E7-C31F5B1569AD
	c
	1
	00043DC6-ABC7-F645-8599-626F460BB5A0
	c
	2
	913761F5-9D0A-CF4C-85CC-D13818B79846
	c
	3
	3988739B-8041-D74E-BD56-70C108D4964F
	c
	4
	2F0EA2CC-8A3E-8341-BDB2-A7898DDE41B2
	c
	5
	B921B045-1DF0-41C3-AF44-4C6F280D3FAE
	w
	y
EOF

# Burn u-boot
dd if="${IDBLOADER_IMG}" of="${SYSTEM_IMG}" seek="${LOADER1_START}" conv=notrunc
dd if="${UBOOT_IMG}" of="${SYSTEM_IMG}" seek="${LOADER2_START}" conv=notrunc
dd if="${TRUST_IMG}" of="${SYSTEM_IMG}" seek="${ATF_START}" conv=notrunc

# Burn boot image
dd if="${BOOT_IMG}" of="${SYSTEM_IMG}" conv=notrunc seek="${BOOT_START}"

# Burn rootfs image
dd if="${ROOTFS_IMG}" of="${SYSTEM_IMG}" conv=notrunc,fsync seek="${ROOTFS_START}"
