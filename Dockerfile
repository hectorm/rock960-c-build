##################################################
## "prepare" stage
##################################################

FROM docker.io/ubuntu:18.04 AS prepare

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		automake \
		bc \
		binfmt-support \
		bison \
		build-essential \
		ca-certificates \
		ccache \
		cmake \
		cpio \
		crossbuild-essential-arm64 \
		curl \
		device-tree-compiler \
		devscripts \
		dh-exec \
		dh-make \
		dosfstools \
		dpkg-dev \
		fakeroot \
		flex \
		gdisk \
		git \
		kmod \
		libssl-dev \
		locales \
		mtools \
		parted \
		pkg-config \
		pv \
		python-dev \
		python3-dev \
		qemu-user-static \
		rsync \
		sudo \
		swig \
		udev \
	&& rm -rf /var/lib/apt/lists/*

# Setup locale
RUN printf '%s\n' 'en_US.UTF-8 UTF-8' > /etc/locale.gen
RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8 ||:
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Clone kernel
ARG KERNEL_REMOTE=https://github.com/96rocks/kernel.git
ARG KERNEL_TREEISH=release-4.4-rock960
RUN mkdir -p /src/kernel/ && cd /src/kernel/ \
	&& git clone --no-checkout "${KERNEL_REMOTE}" ./ \
	&& git checkout "${KERNEL_TREEISH}" \
	&& git submodule update --recursive

# Clone u-boot
ARG UBOOT_REMOTE=https://github.com/96rocks/u-boot.git
ARG UBOOT_TREEISH=stable-4.4-rock960
RUN mkdir -p /src/u-boot/ && cd /src/u-boot/ \
	&& git clone --no-checkout "${UBOOT_REMOTE}" ./ \
	&& git checkout "${UBOOT_TREEISH}" \
	&& git submodule update --recursive

# Clone firmware and tool binaries
ARG RKBIN_REMOTE=https://github.com/rockchip-linux/rkbin.git
ARG RKBIN_TREEISH=stable-4.4-rk3399-linux
RUN mkdir -p /src/rkbin/ && cd /src/rkbin/ \
	&& git clone --no-checkout "${RKBIN_REMOTE}" ./ \
	&& git checkout "${RKBIN_TREEISH}" \
	&& git submodule update --recursive

# Download Ubuntu Base rootfs
ARG UBUNTU_BASE_URL=http://cdimage.ubuntu.com/ubuntu-base/releases/bionic/release/ubuntu-base-18.04.3-base-arm64.tar.gz
ARG UBUNTU_BASE_CHECKSUM=9193fd5f648e12c2102326ee6fdc69ac59c490fac3eb050758cee01927612021
RUN mkdir -p /src/ubuntu-base/rootfs/ && cd /src/ubuntu-base/ \
	&& curl -o ./ubuntu-base.tar.gz "${UBUNTU_BASE_URL}" \
	&& printf '%s  %s' "${UBUNTU_BASE_CHECKSUM}" ./ubuntu-base.tar.gz | sha256sum -c \
	&& tar -xpf ./ubuntu-base.tar.gz -C ./rootfs/ \
	&& rm ./ubuntu-base.tar.gz

# Set board config
ARG DEFCONFIG=rockchip_linux_defconfig
ENV DEFCONFIG=${DEFCONFIG}

ARG UBOOT_DEFCONFIG=rock960-c-rk3399_defconfig
ENV UBOOT_DEFCONFIG=${UBOOT_DEFCONFIG}

ARG DTB=rock960-model-c-linux.dtb
ENV DTB=${DTB}

ARG BOARD=rock960c
ENV BOARD=${BOARD}

ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-linux-gnu-

# Apply patches
COPY ./patches/ /src/patches/
RUN cd /src/kernel/ && git apply -v /src/patches/kernel-*.patch

# Copy files
COPY ./overlay/ /src/overlay/
COPY ./scripts/ /src/scripts/
