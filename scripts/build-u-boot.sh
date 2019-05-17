#!/bin/sh

set -eu

RKBIN_DIR=/src/rkbin/
UBOOT_DIR=/src/u-boot/
OUT_DIR=/src/out/

# Build u-boot
(cd "${UBOOT_DIR}" && make -j"$(nproc)" \
	"${UBOOT_DEFCONFIG}" all \
)

rm -rf "${OUT_DIR}"/u-boot/
mkdir -p "${OUT_DIR}"/u-boot/

RK3399_DDR_800MHZ_BIN=$(readlink -f "${RKBIN_DIR}"/bin/rk33/rk3399_ddr_800MHz_v[0-9].[0-9][0-9].bin)
RK3399_MINILOADER_BIN=$(readlink -f "${RKBIN_DIR}"/bin/rk33/rk3399_miniloader_v[0-9].[0-9][0-9].bin)
RK3399_BL31_BIN=$(readlink -f "${RKBIN_DIR}"/bin/rk33/rk3399_bl31_v[0-9].[0-9][0-9].elf)

# Package u-boot.bin into miniloader loadable format
"${RKBIN_DIR}"/tools/loaderimage --pack --uboot "${UBOOT_DIR}"/u-boot-dtb.bin "${UBOOT_DIR}"/u-boot.img 0x200000
cp "${UBOOT_DIR}"/u-boot.img "${OUT_DIR}"/u-boot/

# Package idbloader into miniloader loadable format
"${UBOOT_DIR}"/tools/mkimage -n rk3399 -T rksd -d "${RK3399_DDR_800MHZ_BIN}" "${UBOOT_DIR}"/idbloader.img
cat "${RK3399_MINILOADER_BIN}" >> "${UBOOT_DIR}"/idbloader.img
cp "${UBOOT_DIR}"/idbloader.img "${OUT_DIR}"/u-boot/

# Package trust into miniloader loadable format
cat > "${UBOOT_DIR}"/trust.ini <<-EOF
	[VERSION]
	MAJOR=1
	MINOR=0
	[BL30_OPTION]
	SEC=0
	[BL31_OPTION]
	SEC=1
	PATH=${RK3399_BL31_BIN}
	ADDR=0x10000
	[BL32_OPTION]
	SEC=0
	[BL33_OPTION]
	SEC=0
	[OUTPUT]
	PATH=${UBOOT_DIR}/trust.img
EOF
"${RKBIN_DIR}"/tools/trust_merger "${UBOOT_DIR}"/trust.ini
cp "${UBOOT_DIR}"/trust.img "${OUT_DIR}"/u-boot/
