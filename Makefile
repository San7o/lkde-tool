# --------------------------------------------------------------------
#
#  LKDE
#  by Giovanni Santini | giovanni.santini@proton.me
#
# --------------------------------------------------------------------


# Imports

include conf.make
include ${KERNEL_MODULE_DIR}/Makefile
include ${CLI_DIR}/Makefile

#
# Commands
#
all: help


##@ Config

${CONFIG_DIR}:
	@mkdir -p ${CONFIG_DIR}
	@echo "*" > ${CONFIG_DIR}/.gitignore

.PHONY: configure
defconfig: ${CONFIG_DIR} env ## Generate the default .config file
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} defconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

.PHONY: tinyconfig
tinyconfig: ${CONFIG_DIR} env ## Generate the tinyconfig
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} tinyconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

.PHONY: menuconfig
menuconfig: ${CONFIG_DIR} env ## Run menuconfig
	cp ${CONFIG_DIR}/${CONFIG_NAME} ${SOURCE_DIR}/.config
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} menuconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

gdbconfig: ${CONFIG_DIR} ## Add gdb support to config
	cp ${CONFIG_DIR}/${CONFIG_NAME} ${SOURCE_DIR}/.config
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --enable CONFIG_GDB_SCRIPTS
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --enable CONFIG_DEBUG_INFO
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --enable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --disable CONFIG_DEBUG_INFO_REDUCED
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --enable CONFIG_FRAME_POINTER
	make -C ${SOURCE_DIR} olddefconfig
	make -C ${SOURCE_DIR} scripts_gdb
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

kdumpconfig: ${CONFIG_DIR} ## Add kdump support to config
	cp ${CONFIG_DIR}/${CONFIG_NAME} ${SOURCE_DIR}/.config
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --enable CONFIG_CRASH_DUMP
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --enable CONFIG_DEBUG_INFO
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --enable CONFIG_KEXEC
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --enable CONFIG_RELOCATABLE
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --enable CONFIG_MAGIC_SYSRQ
	${SOURCE_DIR}/scripts/config --file ${SOURCE_DIR}/.config --enable CONFIG_PROC_VMCORE
	make -C ${SOURCE_DIR}/ olddefconfig
	cp ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

${CONFIG_DIR}/${CONFIG_NAME}: ${CONFIG_DIR}
	touch ${CONFIG_DIR}/${CONFIG_NAME}

##@ Building

.PHONY: build
build: env ${CONFIG_DIR}/${CONFIG_NAME} ## Build the kernel
	cp ${CONFIG_DIR}/${CONFIG_NAME} ${SOURCE_DIR}/.config
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} KVERSION=${KERNEL_MAJOR}.${KERNEL_MINOR}.${KERNEL_PATCH} ${MAKE_FLAGS}

.PHONY: install
install: env ${INSTALL_DIR} ## Copy the image to the install directory
	cp ${SOURCE_DIR}/arch/${ARCH_LINUX_BUILD_NAME}/boot/bzImage ${INSTALL_DIR}/${KERNEL_NAME}

.PHONY: clean
clean: install-clean env ## Clean the build and installation files
	make -C ${SOURCE_DIR} clean || :
	if [ -d ${IMG_TMP_MOUNT} ]; then rm -r ${IMG_TMP_MOUNT}; fi

.PHONY: install-clean
install-clean: env ## Clean the installation files
	if [ "${INSTALL_DIR}" != "" ]; then rm -rf ${INSTALL_DIR}/; fi

.PHONY: deps-clean
deps-clean: env ## Clean the dependencies files
	if [ "${DEPS_SOURCE_DIR}" != "" ]; then rm -rf ${DEPS_SOURCE_DIR}/; fi

.PHONY: distclean
distclean: env ## Clean config files
	make -C ${SOURCE_DIR} distclean
	rm ${CONFIG_DIR}/${CONFIG_NAME}


##@ Image

.PHONY: ${IMG_TMP_MOUNT}
${IMG_TMP_MOUNT}:
	mkdir -p ${IMG_TMP_MOUNT}

.PHONY: image
image: env ${INSTALL_DIR} ${IMG_TMP_MOUNT} ## Create the image
	if mountpoint -q ${IMG_TMP_MOUNT}; then sudo umount -R ${IMG_TMP_MOUNT}; fi
	sync
	${DEPS_INSTALL_DIR}/bin/qemu-img create  ${INSTALL_DIR}/${IMG_NAME} ${IMG_SIZE}
	sudo mkfs.${IMG_FS} ${INSTALL_DIR}/${IMG_NAME}
	@echo -e "#\n# * Sudo in needed to mount the installation image to make modifiations\n#\n"
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
mount: env ## Mount the image
	sudo mount -o loop ${INSTALL_DIR}/${IMG_NAME} ${IMG_TMP_MOUNT}

.PHONY: umount
umount: env ## Unmount the image
	sudo umount -R ${IMG_TMP_MOUNT}

.PHONY: ${INSTALL_DIR}
${INSTALL_DIR}:
	mkdir -p ${INSTALL_DIR}

.PHONY: qemu
qemu: env ## Run qemu
	${DEPS_INSTALL_DIR}/bin/qemu-system-${ARCH_QEMU} -kernel ${INSTALL_DIR}/${KERNEL_NAME} -drive format=raw,file=${INSTALL_DIR}/${IMG_NAME},if=ide ${QEMU_FLAGS}

qemu-gdb: env ## Run qemu and wait for gdb
	${DEPS_INSTALL_DIR}/bin/qemu-system-${ARCH_QEMU} -kernel ${INSTALL_DIR}/${KERNEL_NAME} -drive format=raw,file=${INSTALL_DIR}/${IMG_NAME},if=ide -s -S ${QEMU_FLAGS}


##@ Git wrappers

.PHONY: log
git-log: env ## Git log
	cd ${SOURCE_DIR} && git log

.PHONY: fetch
git-fetch: env ## Git fetch
	cd ${SOURCE_DIR} && git fetch

.PHONY: merge
git-merge: env ## Git merge
	cd ${SOURCE_DIR} && git merge

.PHONY: diff-origin
git-diff-origin: env ## Git diff origin
	cd ${SOURCE_DIR} && git diff origin

.PHONY: diff
git-diff: env ## Git diff local
	cd ${SOURCE_DIR} && git diff

.PHONY: pull
git-pull: env ## Git pull
	cd ${SOURCE_DIR} && git pull


##@ Dependencies
#
# Download, compile and install major dependencies
# - gcc
# - binutils
# - qemu
# - debootstrap

# Only populate the list if BUILD_DEPS is true
ifeq (${BUILD_DEPS},true)
    DEPS_LIST := deps-gcc deps-binutils deps-qemu deps-debootstrap env
else
    DEPS_LIST :=
endif

${DEPS_INSTALL_DIR}:
	mkdir -p ${DEPS_INSTALL_DIR}
	mkdir -p ${DEPS_INSTALL_DIR}/${TARGET_ARCH}
	echo "*" > ${DEPS_INSTALL_DIR}/.gitignore

deps: ${DEPS_LIST} ## Download and build dependencies

${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}:
	mkdir -p ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}
	echo "*" > ${DEPS_SOURCE_DIR}/.gitignore

${SOURCE_DIR}: ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}
ifneq (${KERNEL_SOURCE_HTTP},"")
	wget ${KERNEL_SOURCE_HTTP} -O ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}.tar.gz
	tar -xf ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}.tar.gz -C ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}/ --strip-components 1
	rm -rf ${DEPS_SOURCE_DIR}/*.tar.gz*
	mkdir -p ${SOURCE_DIR}
	mv ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}/* ${SOURCE_DIR} 2>/dev/null || :
	mv ${DEPS_SOURCE_DIR}/${KERNEL_SOURCE}/.* ${SOURCE_DIR} 2>/dev/null || :
else ifneq (${KERNEL_SOURCE_GIT},"")
	git clone ${KERNEL_SOURCE_GIT} ${SOURCE_DIR}
else
	${error "Neither KERNEL_SOURCE_HTTP nor KERNEL_SOURCE_GIT were specified"}
endif

download: ${SOURCE_DIR} # Download kernel sources from HTTP or GIT


## gcc

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


## Binutils

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


## Qemu

${DEPS_SOURCE_DIR}/qemu-${QEMU_VERSION}:
	wget --directory-prefix ${DEPS_SOURCE_DIR} https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz
	tar -xf ${DEPS_SOURCE_DIR}/qemu-${QEMU_VERSION}.tar.xz -C ${DEPS_SOURCE_DIR}/
	rm -rf ${DEPS_SOURCE_DIR}/*.tar.xz*


${QEMU_BUILD_DIR}: ${DEPS_SOURCE_DIR}/qemu-${QEMU_VERSION}
	mkdir -p ${QEMU_BUILD_DIR}

deps-qemu: env ${DEPS_SOURCE_DIR}/qemu-${QEMU_VERSION} ${QEMU_BUILD_DIR} ${DEPS_INSTALL_DIR} ## Download, compile and install qemu
	cd ${QEMU_BUILD_DIR} && ../configure ${QEMU_BUILD_FLAGS}
	cd ${QEMU_BUILD_DIR} && make ${MAKE_FLAGS}
	cd ${QEMU_BUILD_DIR} && make install


## Debootstrap

${DEPS_SOURCE_DIR}/debootstrap:
	wget --directory-prefix ${DEPS_SOURCE_DIR} http://deb.debian.org/debian/pool/main/d/debootstrap/debootstrap_${DEBOOTSTRAP_VERSION}.tar.gz
	tar -xf ${DEPS_SOURCE_DIR}/debootstrap_${DEBOOTSTRAP_VERSION}.tar.gz -C ${DEPS_SOURCE_DIR}/
	rm -rf ${DEPS_SOURCE_DIR}/*.tar.gz*

deps-debootstrap: ${DEPS_SOURCE_DIR}/debootstrap ${DEPS_INSTALL_DIR} ## Download, compile and install debootstrap
	ln -s ${DEPS_SOURCE_DIR}/debootstrap/debootstrap ${DEPS_INSTALL_DIR}/bin


## External dependencies

.PHONY: deps-fedora
deps-fedora: env ## Install build dependencies in fedora
	sudo dnf install -y ${DEPS_EXTERNAL_FEDORA}

deps-ubuntu: env ## Install build dependencies in ubuntu
	sudo apt install -y ${DEPS_EXTERNAL_UBUNTU}


##@ Misc

.PHONY: full
full: env ## Download and build the dependencies, kernel and image
	make download ENV=${ENV}
	make deps ENV=${ENV}
	make defconfig ENV=${ENV}
	make build ENV=${ENV}
	make install ENV=${ENV}
	make image ENV=${ENV}

.PHONY: env
# This is a dependency for most of the other commands so the user will
# always be informed on which env is active
env: ## Print the ENV value
	@echo Using ENV=${ENV}

.PHONY: source-dir
# This is used by other tools, like emacs, to know where to look for
# the sources
source-dir: ## Output the kernel source directory
	@echo ${SOURCE_DIR}

.PHONY: gdb
gdb: ## Run gdb and load symbols
	gdb ${SOURCE_DIR}/vmlinux.unstripped

.PHONY: settings
# When you add a new config variable, add an entry here
settings: ## Shows value of variables
	@echo -e "\n# build"
	@echo ENV=${ENV}
	@echo ENVIRONMENT_DIR=${ENVIRONMENT_DIR}
	@echo BUILD_ARCH=${BUILD_ARCH}
	@echo HOST_ARCH=${HOST_ARCH}
	@echo TARGET_ARCH=${TARGET_ARCH}
	@echo KERNEL_NAME=${KERNEL_NAME}
	@echo KERNEL_MAJOR=${KERNEL_MAJOR}
	@echo KERNEL_MINOR=${KERNEL_MINOR}
	@echo KERNEL_PATCH=${KERNEL_PATCH}
	@echo NPROC=${NPROC}
	@echo MAKE_FLAGS=\"${MAKE_FLAGS}\"
	@echo KERNEL_FLAGS=\"${KERNEL_FLAGS}\"
	@echo -e "\n# directories"
	@echo WORKTREE=${WORKTREE}
	@echo KERNEL_SOURCE=${KERNEL_SOURCE}
	@echo SOURCE_DIR=${SOURCE_DIR}
	@echo INSTALL_DIR=${INSTALL_DIR}
	@echo CONFIG_DIR=${CONFIG_DIR}
	@echo CONFIG_NAME=${CONFIG_NAME}
	@echo DEPS_SOURCE_DIR=${DEPS_SOURCE_DIR}
	@echo DEPS_INSTALL_DIR=${DEPS_INSTALL_DIR}
	@echo -e "\n# rootfs image"
	@echo IMG_NAME=${IMG_NAME}
	@echo IMG_DIR=${IMG_DIR}
	@echo IMG_TMP_MOUNT=${IMG_TMP_MOUNT}
	@echo IMG_FS=${IMG_FS}
	@echo IMG_PACKAGES=${IMG_PACKAGES}
	@echo IMG_USER=${IMG_USER}
	@echo IMG_PASSWD=${IMG_PASSWD}
	@echo IMG_SIZE=${IMG_SIZE}
	@echo -e "\n# dependencies"
	@echo BUILD_DEPS=${BUILD_DEPS}
	@echo GCC_VERSION=${GCC_VERSION}
	@echo GCC_MIRROR=${GCC_MIRROR}
	@echo GCC_BUILD_DIR=${GCC_BUILD_DIR}
	@echo GCC_BUILD_FLAGS=${GCC_BUILD_FLAGS}
	@echo BINUTILS_VERSION=${BINUTILS_VERSION}
	@echo BINUTILS_BUILD_DIR=${BINUTILS_BUILD_DIR}
	@echo BINUTILS_BUILD_FLAGS=${BINUTILS_BUILD_FLAGS}
	@echo DEBOOTSTRAP_VERSION=${DEBOOTSTRAP_VERSION}
	@echo QEMU_VERSION=${QEMU_VERSION}
	@echo QEMU_BUILD_DIR=${QEMU_BUILD_DIR}
	@echo QEMU_BUILD_FLAGS=${QEMU_BUILD_FLAGS}
	@echo QEMU_SSH_PORT=${QEMU_SSH_PORT}
	@echo QEMU_MEM=${QEMU_MEM}
	@echo QEMU_SOCKETS=${QEMU_SOCKETS}
	@echo QEMU_DISPLAY_BACKEND=${QEMU_DISPLAY_BACKEND}
	@echo QEMU_FLAGS=${QEMU_FLAGS}
	@echo DEPS_EXTERNAL_FEDORA=${DEPS_EXTERNAL_FEDORA}
	@echo DEPS_EXTERNAL_UBUNTU=${DEPS_EXTERNAL_UBUNTU}
	@echo KERNEL_SOURCE_HTTP=${KERNEL_SOURCE_HTTP}
	@echo KERNEL_SOURCE_GIT=${KERNEL_SOURCE_GIT}

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "Linux Kernel Development Environment\n\n    make <target>\n\ntargets:\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  %-15s %s\n", $$1, $$2 } /^##@/ { printf "\n%s\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# End --------------------------------------------------------------
