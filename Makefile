# --------------------------------------------------------------------
#
#  LKDE
#  by Giovanni Santini
#
# --------------------------------------------------------------------

PWD=${shell pwd}

# Environment selected
ENV?=linux
# Include the environment
include .env-${ENV}

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
# Name of the directory with the kernel sources
KERNEL_SOURCE?=${ENV}
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
# Qemu flags
QEMU_FLAGS?=-append "root=/dev/sda console=ttyS0 rw"\
            --enable-kvm\
            -virtfs local,path=${PWD},mount_tag=host0,security_model=passthrough,id=host0\
            -nic user,hostfwd=tcp::${QEMU_SSH_PORT}-:22 \
            -m ${QEMU_MEM}\
            -smp ${QEMU_SOCKETS}
# Other dependencies
DEPS_EXTERNAL_FEDORA?=libcap-ng-devel wget
# HTTP kernel sources, for example https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.16.tar.gz
KERNEL_SOURCE_HTTP?=https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.16.tar.gz
# Git kernel sources. Use either HTTP or git.
KERNEL_SOURCE_GIT?= #https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/

### Commands ---------------------------------------------------------


## Config dir --------------------------------------------------------

.PHONY: ${CONFIG_DIR}
${CONFIG_DIR}:
	mkdir -p ${CONFIG_DIR}

.PHONY: configure
defconfig: ${CONFIG_DIR} env # Generate the default .config file
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} defconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

.PHONY: tinyconfig
tinyconfig: ${CONFIG_DIR} env # Generate the tinyconfig
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} tinyconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

.PHONY: menuconfig
menuconfig: ${CONFIG_DIR} env # Run menuconfig
	cp ${CONFIG_DIR}/${CONFIG_NAME} ${SOURCE_DIR}/.config
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} menuconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}


## Building ----------------------------------------------------------


.PHONY: build
build: env ${CONFIG_DIR}/${CONFIG_NAME} # Build the kernel
	cp ${CONFIG_DIR}/${CONFIG_NAME} ${SOURCE_DIR}/.config
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} ${MAKE_FLAGS}

.PHONY: install
install: env ${INSTALL_DIR} # Copy the image to the install directory
	cp ${SOURCE_DIR}/arch/${ARCH_LINUX_BUILD_NAME}/boot/bzImage ${INSTALL_DIR}/${KERNEL_NAME}

.PHONY: clean
clean: install-clean env # Clean the build and installation files
	make -C ${SOURCE_DIR} clean
	if [ -d ${IMG_TMP_MOUNT} ]; then rm -r ${IMG_TMP_MOUNT}; fi

.PHONY: clean
install-clean: env # Clean the installation files
	if [ "${INSTALL_DIR}" != "" ]; then rm -rf ${INSTALL_DIR}/; fi

.PHONY: distclean
distclean: env # Clean config files
	make -C ${SOURCE_DIR} distclean
	rm ${CONFIG_DIR}/${CONFIG_NAME}


## Image -------------------------------------------------------------

.PHONY: ${IMG_TMP_MOUNT}
${IMG_TMP_MOUNT}:
	mkdir -p ${IMG_TMP_MOUNT}

.PHONY: image
image: env ${INSTALL_DIR} ${IMG_TMP_MOUNT} # Create the image
	${DEPS_INSTALL_DIR}/bin/qemu-img create  ${INSTALL_DIR}/${IMG_NAME} ${IMG_SIZE}
	mkfs.${IMG_FS} ${INSTALL_DIR}/${IMG_NAME}
	@echo -e "#\n# * Sudo in needed to mount the installation image to make modifiations\n#\n"
	if mountpoint -q ${IMG_TMP_MOUNT}; then sudo umount -R ${IMG_TMP_MOUNT}; fi
	sync
	@echo -e "#\n# * If you get error \"Structure needs cleaning\", just try again\n#"
	sudo mount -o loop ${INSTALL_DIR}/${IMG_NAME} ${IMG_TMP_MOUNT}
	sudo ${DEPS_INSTALL_DIR}/bin/debootstrap --arch ${ARCH_DEBOOTSTRAP} --include=${IMG_PACKAGES} stable ${IMG_TMP_MOUNT} https://deb.debian.org/debian
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "echo 'root:root' | chpasswd"
	sudo cp -a ${IMG_DIR}/. ${IMG_TMP_MOUNT}
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "chown root:root /etc/sudoers"
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "useradd -m -u 1000 -s /bin/bash ${IMG_USER}"
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "groupadd wheel"
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "usermod -a -G wheel ${IMG_USER}"
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "chown -R ${IMG_USER}:${IMG_USER} /lkde"
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "echo '${IMG_USER}:${IMG_PASSWD}' | chpasswd"
	sudo umount -R ${IMG_TMP_MOUNT}

.PHONY: mount
mount: env # Mount the image
	sudo mount -o loop ${INSTALL_DIR}/${IMG_NAME} ${IMG_TMP_MOUNT}

.PHONY: umount
umount: env # Unmount the image
	sudo umount -R ${IMG_TMP_MOUNT}

.PHONY: ${INSTALL_DIR}
${INSTALL_DIR}:
	mkdir -p ${INSTALL_DIR}

.PHONY: qemu
qemu: env # Run qemu
	${DEPS_INSTALL_DIR}/bin/qemu-system-${ARCH_QEMU} -kernel ${INSTALL_DIR}/${KERNEL_NAME} -drive format=raw,file=${INSTALL_DIR}/${IMG_NAME},if=ide ${QEMU_FLAGS}


### git --------------------------------------------------------------
# Some git wrappers

.PHONY: log
git-log: env # Git log
	cd ${SOURCE_DIR} && git log

.PHONY: fetch
git-fetch: env # Git fetch
	cd ${SOURCE_DIR} && git fetch

.PHONY: merge
git-merge: env # Git merge
	cd ${SOURCE_DIR} && git merge

.PHONY: diff-origin
git-diff-origin: env # Git diff origin
	cd ${SOURCE_DIR} && git diff origin

.PHONY: diff
git-diff: env # Git diff local
	cd ${SOURCE_DIR} && git diff

.PHONY: pull
git-pull: env # Git pull
	cd ${SOURCE_DIR} && git pull


### Dependencies -----------------------------------------------------
# Download, compile and install major dependencies
# - gcc
# - binutils
# - qemu
# - debootstrap


${DEPS_INSTALL_DIR}:
	mkdir -p ${DEPS_INSTALL_DIR}
	mkdir -p ${DEPS_INSTALL_DIR}/${TARGET_ARCH}

deps: deps-gcc deps-binutils deps-qemu deps-debootstrap env ## Download and build dependencies

${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}:
	mkdir -p ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}

${SOURCE_DIR}: ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}
ifneq (${KERNEL_SOURCE_HTTP},"")
	wget ${KERNEL_SOURCE_HTTP} -O ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}.tar.gz
	tar -xf ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}.tar.gz -C ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}/ --strip-components 1
	rm -rf ${DEPS_SOURCE_DIR}/*.tar.gz*
	mv ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE} ${SOURCE_DIR}
else ifneq (${KERNEL_SOURCE_GIT},"")
	git clone ${KERNEL_SOURCE_GIT} ${SOURCE_DIR}
else
	@echo "Neither KERNEL_SOURCE_HTTP nor KERNEL_SOURCE_GIT were specified"
endif

download: ${SOURCE_DIR} # Download kernel sources from HTTP or GIT


## GCC ---------------------------------------------------------------

GCC_BUILD_DIR=${DEPS_SOURCE_DIR}/gcc-${GCC_VERSION}/build
GCC_BUILD_FLAGS=--prefix=${DEPS_INSTALL_DIR}/${TARGET_ARCH}\
	             --disable-multilib      \
	             --with-system-zlib      \
	             --enable-default-pie    \
	             --enable-default-ssp    \
	             --enable-host-pie       \
	             --disable-fixincludes   \
	             --enable-languages=c,m2 \
	             --with-mpfr             \
	             --with-mpc              \
	             --with-gmp              \
               --target ${ARCH_GCC}

${DEPS_SOURCE_DIR}/gcc-${GCC_VERSION}:
	wget --directory-prefix ${DEPS_SOURCE_DIR}/ https://${GCC_MIRROR}/unix/languages/gcc/releases/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz
	tar -xf ${DEPS_SOURCE_DIR}/gcc-${GCC_VERSION}.tar.xz -C ${DEPS_SOURCE_DIR}/
	rm -rf ${DEPS_SOURCE_DIR}/*.tar.xz*

.PHONY: ${GCC_BUILD_DIR}
${GCC_BUILD_DIR}: ${DEPS_SOURCE_DIR}/gcc-${GCC_VERSION}
	mkdir -p ${GCC_BUILD_DIR}

deps-gcc: env ${DEPS_SOURCE_DIR}/gcc-${GCC_VERSION} ${GCC_BUILD_DIR} ${DEPS_INSTALL_DIR} ## Download, compile and install gcc
	cd ${GCC_BUILD_DIR} && ../configure ${GCC_BUILD_FLAGS}
	cd ${GCC_BUILD_DIR} && make ${MAKE_FLAGS}
	cd ${GCC_BUILD_DIR} && make install


## Binutils ----------------------------------------------------------

BINUTILS_BUILD_DIR=${DEPS_SOURCE_DIR}/binutils-${BINUTILS_VERSION}/build
BINUTILS_BUILD_FLAGS=--prefix=${DEPS_INSTALL_DIR}/${TARGET_ARCH}\
                    --sysconfdir=${IMG_DIR}/etc \
                    --enable-ld=default \
                    --enable-plugins    \
                    --enable-shared     \
                    --disable-werror    \
                    --enable-64-bit-bfd \
                    --enable-new-dtags  \
                    --with-system-zlib  \
                    --enable-default-hash-style=gnu \
                    --target=${ARCH_GCC} \
                    --program-prefix=${ARCH_GCC}-

${DEPS_SOURCE_DIR}/binutils-${BINUTILS_VERSION}:
	wget --directory-prefix ${DEPS_SOURCE_DIR} https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz
	tar -xf ${DEPS_SOURCE_DIR}/binutils-${BINUTILS_VERSION}.tar.gz -C ${DEPS_SOURCE_DIR}/
	rm -rf ${DEPS_SOURCE_DIR}/*.tar.gz*

${BINUTILS_BUILD_DIR}: ${DEPS_SOURCE_DIR}/binutils-${BINUTILS_VERSION}
	mkdir -p ${BINUTILS_BUILD_DIR}

deps-binutils: env ${DEPS_SOURCE_DIR}/binutils-${BINUTILS_VERSION} ${BINUTILS_BUILD_DIR} ${DEPS_INSTALL_DIR} ## Download, compile and install binutils
	cd ${BINUTILS_BUILD_DIR} && ../configure ${BINUTILS_BUILD_FLAGS}
	cd ${BINUTILS_BUILD_DIR} && make ${MAKE_FLAGS}
	cd ${BINUTILS_BUILD_DIR} && make install


## Qemu --------------------------------------------------------------

QEMU_BUILD_DIR=${DEPS_SOURCE_DIR}/qemu-${QEMU_VERSION}/build
QEMU_BUILD_FLAGS?=--prefix=${DEPS_INSTALL_DIR} \
                  --sysconfdir=/etc           \
                  --localstatedir=/var        \
                  --target-list=${ARCH_QEMU}-softmmu  \
                  --audio-drv-list=jack       \
                  --disable-pa                \
                  --enable-slirp

${DEPS_SOURCE_DIR}/qemu-${QEMU_VERSION}:
	wget --directory-prefix ${DEPS_SOURCE_DIR} https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz
	tar -xf ${DEPS_SOURCE_DIR}/qemu-${QEMU_VERSION}.tar.xz -C ${DEPS_SOURCE_DIR}/
	rm -rf ${DEPS_SOURCE_DIR}/*.tar.xz*


${QEMU_BUILD_DIR}: ${DEPS_SOURCE_DIR}/qemu-${QEMU_VERSION}
	mkdir -p ${QEMU_BUILD_DIR}

deps-qemu: env ${DEPS_SOURCE_DIR}/qemu-${QEMU_VERSION} ${QEMU_BUILD_DIR} ${DEPS_INSTALL_DIR}
	cd ${QEMU_BUILD_DIR} && ../configure ${QEMU_BUILD_FLAGS}
	cd ${QEMU_BUILD_DIR} && make ${MAKE_FLAGS}
	cd ${QEMU_BUILD_DIR} && make install


## Debootstrap -------------------------------------------------------

${DEPS_SOURCE_DIR}/debootstrap:
	wget --directory-prefix ${DEPS_SOURCE_DIR} http://deb.debian.org/debian/pool/main/d/debootstrap/debootstrap_${DEBOOTSTRAP_VERSION}.tar.gz
	tar -xf ${DEPS_SOURCE_DIR}/debootstrap_${DEBOOTSTRAP_VERSION}.tar.gz -C ${DEPS_SOURCE_DIR}/
	rm -rf ${DEPS_SOURCE_DIR}/*.tar.gz*

deps-debootstrap: ${DEPS_SOURCE_DIR}/debootstrap ${DEPS_INSTALL_DIR}
	ln -s ${DEPS_SOURCE_DIR}/debootstrap/debootstrap ${DEPS_INSTALL_DIR}/bin


## External dependencies ---------------------------------------------

.PHONY: deps-fedora
deps-fedora: env ## Install build dependencies in fedora
	sudo dnf install -y ${DEPS_EXTERNAL_FEDORA}


### Misc -------------------------------------------------------------

all: help

.PHONY: env
# This is a dependency for most of the other commands so the user will
# always be informed on which env is active
env: # Print the ENV value
	@echo Using ENV=${ENV}

.PHONY: source-dir
# This is used by other tools, like emacs, to know where to look for
# the sources
source-dir: # Output the kernel source directory
	@echo ${SOURCE_DIR}

.PHONY: settings
# Please, when you add a new config variable, add an entry here
settings: # Shows value of variables
	@echo -e "# build -----------------------------------------------#"
	@echo ENV=${ENV}
	@echo BUILD_ARCH=${BUILD_ARCH}
	@echo HOST_ARCH=${HOST_ARCH}
	@echo TARGET_ARCH=${TARGET_ARCH}
	@echo KERNEL_NAME=${KERNEL_NAME}
	@echo NPROC=${NPROC}
	@echo MAKE_FLAGS=\"${MAKE_FLAGS}\"
	@echo KERNEL_FLAGS=\"${KERNEL_FLAGS}\"
	@echo -e "# directories -----------------------------------------#"
	@echo WORKTREE=${WORKTREE}
	@echo KERNEL_SOURCE=${KERNEL_SOURCE}
	@echo SOURCE_DIR=${SOURCE_DIR}
	@echo INSTALL_DIR=${INSTALL_DIR}
	@echo CONFIG_DIR=${CONFIG_DIR}
	@echo CONFIG_NAME=${CONFIG_NAME}
	@echo DEPS_SOURCE_DIR=${DEPS_SOURCE_DIR}
	@echo DEPS_INSTALL_DIR=${DEPS_INSTALL_DIR}
	@echo -e "# rootfs image ----------------------------------------#"
	@echo IMG_NAME=${IMG_NAME}
	@echo IMG_DIR=${IMG_DIR}
	@echo IMG_TMP_MOUNT=${IMG_TMP_MOUNT}
	@echo IMG_FS=${IMG_FS}
	@echo IMG_PACKAGES=${IMG_PACKAGES}
	@echo IMG_USER=${IMG_USER}
	@echo IMG_PASSWD=${IMG_PASSWD}
	@echo IMG_SIZE=${IMG_SIZE}
	@echo -e "# dependencies ----------------------------------------#"
	@echo GCC_VERSION=${GCC_VERSION}
	@echo GCC_MIRROR=${GCC_MIRROR}
	@echo BINUTILS_VERSION=${BINUTILS_VERSION}
	@echo CC_DIR=${CC_DIR}
	@echo DEBOOTSTRAP_VERSION=${DEBOOTSTRAP_VERSION}
	@echo QEMU_VERSION=${QEMU_VERSION}
	@echo QEMU_SSH_PORT=${QEMU_SSH_PORT}
	@echo QEMU_MEM=${QEMU_MEM}
	@echo QEMU_SOCKETS=${QEMU_SOCKETS}
	@echo QEMU_FLAGS=${QEMU_FLAGS}
	@echo DEPS_EXTERNAL_FEDORA=${DEPS_EXTERNAL_FEDORA}
	@echo KERNEL_SOURCE_HTTP=${KERNEL_SOURCE_HTTP}
	@echo KERNEL_SOURCE_GIT=${KERNEL_SOURCE_GIT}

.PHONY: help
help: # Shows help
	@echo "Linux Kernel Development Environment"
	@echo
	@echo "make targets:"
	@echo
	@sed -e's/^\([^: 	]\+\):.*#\(.*\)$$/\1 \2/p;d' Makefile | column -t -l 2 | sort


### End --------------------------------------------------------------
