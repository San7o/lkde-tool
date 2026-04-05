# SPDX-License-Identifier: MIT
# Author:  Giovanni Santini
# Mail:    giovanni.santini@proton.me
# Github:  @San7o

#
# LKDE Config variables
# =====================
#

PWD=${shell pwd}

# Environment selected
ENV?=linux
# Directory of the envionment
ENVIRONMENT_DIR?=${PWD}/environments
# Include the environment
include ${ENVIRONMENT_DIR}/.env-${ENV}

### Config variables -------------------------------------------------
# Change the following variables as you requre


## Build -------------------------------------------------------------

# System which you are using to build the compiler
BUILD_ARCH?=${shell arch}
# The system where you want to run the resulting compiler
HOST_ARCH?=x86_64
# The system for which you want the compiler to generate code
TARGET_ARCH?=x86_64
# Name of the kernel image
KERNEL_NAME?=kernel-${ENV}-${TARGET_ARCH}
# Number of processing units to use
NPROC?=${shell nproc}
# General compilation flags
MAKE_FLAGS?=-j${NPROC}
# Flags passed to the kernel build system
KERNEL_FLAGS?=ARCH=${TARGET_ARCH}\
							CROSS_COMPILE=${CC_DIR}/${ARCH_GCC}-


## Internal architecture variables -----------------------------------
# Programs may use different names to refer to the same architecture,
# so we need to do this

ifeq (${TARGET_ARCH},x86_64)
ARCH_DEBOOTSTRAP?=amd64
ARCH_LINUX_BUILD_NAME?=x86
ARCH_QEMU?=x86_64
ARCH_GCC?=x86_64-pc-linux-gnu
else
ARCH_DEBOOTSTRAP?=unknown
ARCH_LINUX_BUILD_NAME?=unknown
ARCH_QEMU?=unknown
ARCH_GCC?=unknown
endif


## Directories -------------------------------------------------------

# Git worktree
WORKTREE?=
# Name of the directory with the kernel sources (not the full path)
KERNEL_SOURCE?=${ENV}
# Version of the Kernel
KERNEL_MAJOR=6
KERNEL_MINOR=16
KERNEL_PATCH=6
# Directory of the kernel sources
SOURCE_DIR?=${PWD}/sources/${KERNEL_SOURCE}/${WORKTREE}
# Output installation directory
INSTALL_DIR?=${PWD}/install/${ENV}-${TARGET_ARCH}
# Directory of the kernel config files
CONFIG_DIR?=${PWD}/config
# Name of the config file
CONFIG_NAME?=.config-${ENV}
# Dependencies source directory
DEPS_SOURCE_DIR?=${PWD}/deps
# Dependencies install directory
DEPS_INSTALL_DIR?=${PWD}/usr


## Rootfs Image ------------------------------------------------------

# Name of the root filesystem image used to boot the kernel
IMG_NAME?=image-${ENV}-${TARGET_ARCH}.img
# Location of the contents of the image that should be copied
IMG_DIR?=${PWD}/image
# A temporary location where the image will be mounted for modification
IMG_TMP_MOUNT?=${PWD}/mnt/${IMG_NAME}
# Filesystem of the root image
IMG_FS?=ext4
# Packages that should be installed in the root image
IMG_PACKAGES?=curl,make,vim,git,bsdextrautils,gcc,build-essential,libc6-dev,flex,bison,bc,tmux,sudo,openssh-server,dhcpcd
# User of the root filesystem image
IMG_USER?=test
# Password of the user in the root filesystem image
IMG_PASSWD?=test
# Size of the root filesystem image
IMG_SIZE?=10G


## Dependencies ------------------------------------------------------

# Version of GCC to download
GCC_VERSION?=15.2.0
# Where to download gcc
GCC_MIRROR?=ftp.fu-berlin.de
# Version of binutils to download
BINUTILS_VERSION?=2.45
# Directory of the compiler toolchain
CC_DIR?=${DEPS_INSTALL_DIR}/${TARGET_ARCH}/bin
# Directory of the debootstrap executable
DEBOOTSTRAP_VERSION?=1.0.141
# Qemu version
QEMU_VERSION?=10.0.3
# SSH port for connecting to the virtual machine
QEMU_SSH_PORT?=2222
# Virtual Machine memory
QEMU_MEM?=6G
# Number of sockets
QEMU_SOCKETS?=4
# Display backend used by qemu
QEMU_DISPLAY_BACKEND=gtk
# Qemu flags
QEMU_FLAGS?=-append "root=/dev/sda console=ttyS0 rw"\
            --enable-kvm\
            -virtfs local,path=${PWD},mount_tag=host0,security_model=passthrough,id=host0\
            -nic user,hostfwd=tcp::${QEMU_SSH_PORT}-:22 \
            -m ${QEMU_MEM}\
            -smp ${QEMU_SOCKETS}
# Other dependencies needed to build the core dependencies and toolchain
DEPS_EXTERNAL_FEDORA?=libcap-ng-devel wget libgmp-dev libmpfr-dev libmpc-dev zlib1g-dev ninja flex bison gtk3-devel
DEPS_EXTERNAL_UBUNTU?=libcap-ng-dev wget libgmp-dev libmpfr-dev libmpc-dev zlib1g-dev ninja-build libglib2.0-dev flex bison libgtk-3-dev
# HTTP kernel sources, for example https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.16.tar.gz
KERNEL_SOURCE_HTTP?=https://www.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_MAJOR}.${KERNEL_MINOR}.tar.gz
# Git kernel sources. Use either HTTP or git.
KERNEL_SOURCE_GIT?= #https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/
