#!/bin/sh

set -eu

CHROOT_DIR=/src/ubuntu-base/rootfs/
ROOTFS_MNT=/src/ubuntu-base/rootfs-mnt/
ROOTFS_IMG=/src/out/rootfs.img
OVERLAY_DIR=/src/overlay/
OUT_DIR=/src/out/

mount_chroot() {
	mount -t proc /proc "${CHROOT_DIR}"/proc
	mount -t sysfs /sys "${CHROOT_DIR}"/sys
	mount -o bind /dev "${CHROOT_DIR}"/dev
	mount -o bind /dev/pts "${CHROOT_DIR}"/dev/pts
}

umount_chroot() {
	umount "${CHROOT_DIR}"/proc
	umount "${CHROOT_DIR}"/sys
	umount "${CHROOT_DIR}"/dev/pts
	umount "${CHROOT_DIR}"/dev
}

# Copy overlay files
rsync -aAXv --exclude='*/.gitkeep' "${OVERLAY_DIR}"/ "${CHROOT_DIR}"/

# Copy kernel packages
cp -f "${OUT_DIR}"/kernel/debian/*.deb "${CHROOT_DIR}"/tmp/

# Copy qemu binary
cp -f /usr/bin/qemu-aarch64-static "${CHROOT_DIR}"/usr/bin/

# Mount chroot
mount_chroot
trap '[ $? -eq 0 ] && exit; umount_chroot' EXIT

# Setup chroot
cat <<-'EOF' | chroot "${CHROOT_DIR}"
	set -eu

	# Install system packages
	export DEBIAN_FRONTEND=noninteractive
	apt update
	apt full-upgrade \
		--assume-yes \
		--option Dpkg::Options::='--force-confdef' \
		--option Dpkg::Options::='--force-confold'
	apt install \
		--assume-yes \
		--option Dpkg::Options::='--force-confdef' \
		--option Dpkg::Options::='--force-confold' \
			ubuntu-minimal \
			ubuntu-standard \
			apparmor \
			apt-transport-https \
			apt-utils \
			bash-completion \
			bc \
			build-essential \
			ca-certificates \
			cloud-guest-utils \
			curl \
			dkms \
			dns-root-data \
			dnsutils \
			e2fsprogs \
			gdisk \
			git \
			gnupg2 \
			hdparm \
			htop \
			iproute2 \
			iputils-ping \
			knot-dnsutils \
			libcap2-bin \
			libssl-dev \
			locales \
			moreutils \
			mtr-tiny \
			nano \
			network-manager \
			nvme-cli \
			openresolv \
			openssh-server \
			parted \
			pv \
			python \
			python3 \
			rsync \
			sudo \
			systemd \
			ufw \
			unattended-upgrades \
			wireless-tools \
			wpasupplicant

	# Fix some permissions
	chmod 600 -v /etc/NetworkManager/system-connections/* 2>/dev/null ||:
	chmod 755 -v /usr/local/bin/* 2>/dev/null ||:

	# Install kernel packages
	dpkg -i /tmp/linux-image-*.deb
	dpkg -i /tmp/linux-headers-*.deb
	apt install --fix-broken --assume-yes

	# Install Docker
	printf '%s' "deb [arch=arm64] https://download.docker.com/linux/ubuntu/ $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
	apt-key adv --keyserver 'keyserver.ubuntu.com' --recv-keys '9DC858229FC7DD38854AE2D88D81803C0EBFCD88'
	apt update && apt install --assume-yes docker-ce docker-ce-cli containerd.io
	chmod 700 -v /etc/docker/ 2>/dev/null ||:

	# Install WireGuard
	printf '%s' "deb [arch=arm64] http://ppa.launchpad.net/wireguard/wireguard/ubuntu/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/wireguard.list
	apt-key adv --keyserver 'keyserver.ubuntu.com' --recv-keys 'E1B39B6EF6DDB96564797591AE33835F504A1A25'
	apt update && apt install --assume-yes wireguard
	chmod 700 -v /etc/wireguard/ 2>/dev/null ||:

	# Create "ssh-user" group
	groupadd --system ssh-user

	# Create "rock" user
	groupadd --gid 1000 rock
	useradd --uid 1000 --gid 1000 --shell "$(command -v bash)" --create-home --groups sudo,ssh-user rock
	printf 'rock:rock' | chpasswd # CHANGE ME!
	cp -vaT /etc/skel/ /home/rock/
	chmod 700 -v /home/rock/ /home/rock/.ssh/
	chown rock:rock -vR /home/rock/

	# Cleanup
	rm -rf /var/lib/apt/lists/* /tmp/*
	rm /usr/bin/qemu-aarch64-static
EOF

# Unmount chroot
umount_chroot

# Create rootfs image
rm -f "${ROOTFS_IMG}"
dd if=/dev/zero of="${ROOTFS_IMG}" bs=1M count=0 seek=10000
mkfs.ext4 -L 'rootfs' "${ROOTFS_IMG}"

# Mount rootfs image to mount point
mkdir -p "${ROOTFS_MNT}"
mount "${ROOTFS_IMG}" "${ROOTFS_MNT}"

# Copy chroot content to mount point
cp -rfp "${CHROOT_DIR}"/* "${ROOTFS_MNT}"

# Unmount rootfs image
umount "${ROOTFS_MNT}"
rmdir "${ROOTFS_MNT}"

# Resize rootfs image
e2fsck -p -f "${ROOTFS_IMG}"
resize2fs -M "${ROOTFS_IMG}"
