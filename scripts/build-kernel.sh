#!/bin/sh

set -eu

KERNEL_DIR=/src/kernel/
KERNEL_VERSION=$(make -sC "${KERNEL_DIR}" kernelversion)
OUT_DIR=/src/out/

# Build kernel
(cd "${KERNEL_DIR}" && make -j"$(nproc)" \
	KDEB_PKGVERSION="${KERNEL_VERSION}"-1 \
	LOCALVERSION=-"${BOARD}" \
	"${DEFCONFIG}" bindeb-pkg \
)

# Copy kernel image and device tree
rm -rf "${OUT_DIR}"/kernel/
mkdir -p "${OUT_DIR}"/kernel/boot/
cp "${KERNEL_DIR}"/arch/arm64/boot/Image "${OUT_DIR}"/kernel/boot/vmlinuz-"${KERNEL_VERSION}"-"${BOARD}"
cp "${KERNEL_DIR}"/arch/arm64/boot/dts/rockchip/"${DTB}" "${OUT_DIR}"/kernel/boot/

# Create extlinux config
mkdir -p "${OUT_DIR}"/kernel/boot/extlinux/
cat > "${OUT_DIR}"/kernel/boot/extlinux/extlinux.conf <<-EOF
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
rm -f "${OUT_DIR}"/kernel/boot.img
dd if=/dev/zero of="${OUT_DIR}"/kernel/boot.img bs=1M count=0 seek=100
mkfs.vfat -n 'boot' "${OUT_DIR}"/kernel/boot.img

# Copy files
mmd -i "${OUT_DIR}"/kernel/boot.img ::/extlinux
mcopy -i "${OUT_DIR}"/kernel/boot.img -s "${OUT_DIR}"/kernel/boot/* ::

# Copy Debian packages
mkdir -p "${OUT_DIR}"/kernel/debian/
cp "${KERNEL_DIR}"/../linux-image-*.deb "${OUT_DIR}"/kernel/debian/
cp "${KERNEL_DIR}"/../linux-headers-*.deb "${OUT_DIR}"/kernel/debian/
