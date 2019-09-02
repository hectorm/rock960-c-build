#!/bin/sh

set -eu

TYPE=${1:?}
IMAGE=${2:?}
DEVICE=${3:?}

# Print to stderr and exit
abort() { >&2 printf -- '%s\n' "$@" && exit 1; }

# Set number of blocks to skip
if   [ "${TYPE}" = 'system-u-boot'  ]; then SEEK=0
elif [ "${TYPE}" = 'system-rootfs'  ]; then SEEK=0
elif [ "${TYPE}" = 'system-all'     ]; then SEEK=0
elif [ "${TYPE}" = 'loader1'        ]; then SEEK=64
elif [ "${TYPE}" = 'loader2'        ]; then SEEK=16384
elif [ "${TYPE}" = 'trust'          ]; then SEEK=24576
elif [ "${TYPE}" = 'boot'           ]; then SEEK=32768
elif [ "${TYPE}" = 'rootfs'         ]; then SEEK=262144
else abort 'Error, unrecognized type'; fi

# Burn image
pv "${IMAGE}" | dd bs=512k iflag=fullblock oflag=direct,sync seek="${SEEK}" of="${DEVICE}"

# Expand GPT
sgdisk --move-second-header "${DEVICE}"

# Resize rootfs partition
grow() {
	d="${1:?}"; n="${2:?}"
	if   [ -b "${d}${n}"  ]; then p="${d}${n}"
	elif [ -b "${d}p${n}" ]; then p="${d}p${n}"
	else abort 'Error, partition not found'; fi
	growpart "${d}" "${n}"
	resize2fs "${p}"
}
if   [ "${TYPE}" = 'system-rootfs'  ]; then grow "${DEVICE}" 1
elif [ "${TYPE}" = 'system-all'     ]; then grow "${DEVICE}" 5
fi
