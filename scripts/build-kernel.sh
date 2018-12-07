#!/bin/sh

set -eu

KERNEL_DIR=/src/kernel/
KERNEL_VERSION=$(make -sC "${KERNEL_DIR}" kernelversion)
BOOT_IMG=/src/out/boot.img
OUT_DIR=/src/out/

# Build kernel
(cd "${KERNEL_DIR}" && make -j"$(nproc)" \
	KDEB_PKGVERSION="${KERNEL_VERSION}"-1 \
	LOCALVERSION=-"${BOARD}" \
	"${DEFCONFIG}" bindeb-pkg \
)

# Copy kernel image and device tree
rm -rf "${OUT_DIR}"/kernel/
mkdir -p "${OUT_DIR}"/kernel/
cp "${KERNEL_DIR}"/arch/arm64/boot/Image "${OUT_DIR}"/kernel/vmlinuz-"${KERNEL_VERSION}"-"${BOARD}"
cp "${KERNEL_DIR}"/arch/arm64/boot/dts/rockchip/"${DTB}" "${OUT_DIR}"/kernel/

# Create extlinux config
mkdir -p "${OUT_DIR}"/kernel/extlinux/
cat > "${OUT_DIR}"/kernel/extlinux/extlinux.conf <<-EOF
	LABEL kernel-${KERNEL_VERSION}-${BOARD}
	    KERNEL /vmlinuz-${KERNEL_VERSION}-${BOARD}
	    FDT /${DTB}
	    APPEND $(printf -- '%s ' \
			'earlyprintk' 'console=ttyFIQ0,1500000n8' \
			'root=PARTUUID=B921B045-1D' 'rootfstype=ext4' 'rw' 'rootwait' 'init=/sbin/init' \
			'cgroup_enable=memory' 'swapaccount=1' \
		)
EOF

# Create boot image
rm -f "${BOOT_IMG}"
dd if=/dev/zero of="${BOOT_IMG}" bs=1M count=0 seek=100
mkfs.vfat -n 'boot' "${BOOT_IMG}"

# Copy files
mmd -i "${BOOT_IMG}" ::/extlinux
mcopy -i "${BOOT_IMG}" -s "${OUT_DIR}"/kernel/* ::

# Copy Debian packages
mkdir -p "${OUT_DIR}"/kernel/debian/
cp "${KERNEL_DIR}"/../linux-image-*.deb "${OUT_DIR}"/kernel/debian/
cp "${KERNEL_DIR}"/../linux-headers-*.deb "${OUT_DIR}"/kernel/debian/
