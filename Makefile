ENV?=linux
include .env-${ENV}

PWD=${shell pwd}
ARCH?=amd64
SOURCE_DIR?=${PWD}/sources/${ENV}
INSTALL_DIR?=${PWD}/install/${ENV}
KERNEL_NAME?=kernel-${ENV}
MAKE_FLAGS?=
MAKE_FLAGS+=-j${shell nproc}
CONFIG_DIR?=${PWD}/config
CONFIG_NAME?=.config-${ENV}
IMG_NAME?=image-${ENV}.img
IMG_TMP_MOUNT?=${PWD}/mnt/${IMG_NAME}
IMG_FS?=ext4
IMG_PACKAGES?=curl,make,vim,git,bsdextrautils,gcc,build-essential,libc6-dev,flex,bison,bc,tmux
IMG_USER?=test
IMG_SIZE?=10G
DEBOOTSTRAP_DIR?=/usr/sbin
QEMU_DIR?=/usr/bin
QEMU_FLAGS?=-append "root=/dev/sda console=ttyS0 rw"\
            --enable-kvm\
            -virtfs local,path=${PWD},mount_tag=host0,security_model=passthrough,id=host0\
            -netdev user,id=net0 \
            -device virtio-net-pci,netdev=net0\
            -m 6G\
            -smp 4

# Internal variables
ifeq (${ARCH},amd64)
ARCH_LINUX_BUILD_NAME=x86
ARCH_QEMU=x86_64
else
ARCH_LINUX_BUILD_NAME=unknown
ARCH_QEMU=unknown
endif

all: help

.PHONY: env
env: # Print the ENV value
	@echo Using ENV=${ENV}

.PHONY: ${CONFIG_DIR}
${CONFIG_DIR}:
	mkdir -p ${CONFIG_DIR}

.PHONY: configure
defconfig: ${CONFIG_DIR} env # Generate the default .config file
	make -C ${SOURCE_DIR} defconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

.PHONY: tinyconfig
tinyconfig: ${CONFIG_DIR} env # Generate the tinyconfig
	make -C ${SOURCE_DIR} tinyconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

.PHONY: menuconfig
menuconfig: ${CONFIG_DIR} env # Run menuconfig
	cp ${CONFIG_DIR}/${CONFIG_NAME} ${SOURCE_DIR}/.config
	make -C ${SOURCE_DIR} menuconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

.PHONY: build
build: env ${CONFIG_DIR}/${CONFIG_NAME} # Build the kernel
	cp ${CONFIG_DIR}/${CONFIG_NAME} ${SOURCE_DIR}/.config
	make -C ${SOURCE_DIR} ${MAKE_FLAGS}

.PHONY: ${IMG_TMP_MOUNT}
${IMG_TMP_MOUNT}:
	mkdir -p ${IMG_TMP_MOUNT}

.PHONY: image
image: env ${INSTALL_DIR} ${IMG_TMP_MOUNT} # Create the image
	${QEMU_DIR}/qemu-img create  ${INSTALL_DIR}/${IMG_NAME} ${IMG_SIZE}
	mkfs.${IMG_FS} ${INSTALL_DIR}/${IMG_NAME}
	if mountpoint -q ${IMG_TMP_MOUNT}; then sudo umount -R ${IMG_TMP_MOUNT}; fi
	sync
	sudo mount -o loop ${INSTALL_DIR}/${IMG_NAME} ${IMG_TMP_MOUNT}
	sudo ${DEBOOTSTRAP_DIR}/debootstrap --arch ${ARCH} --include=${IMG_PACKAGES} stable ${IMG_TMP_MOUNT} https://deb.debian.org/debian
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "echo 'root:root' | chpasswd"
	sudo cp -a image/. ${IMG_TMP_MOUNT}
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "useradd -m -u 1000 -s /bin/bash ${IMG_USER}"
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "chown -R ${IMG_USER}:${IMG_USER} /lkde"
	sudo chroot ${IMG_TMP_MOUNT} /bin/bash -c "echo '${IMG_USER}:${IMG_USER}' | chpasswd"
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

.PHONY: install
install: env ${INSTALL_DIR} # Copy the image to the install directory
	cp ${SOURCE_DIR}/arch/${ARCH_LINUX_BUILD_NAME}/boot/bzImage ${INSTALL_DIR}/${KERNEL_NAME}

.PHONY: qemu
qemu: env # Run qemu
	${QEMU_DIR}/qemu-system-${ARCH_QEMU} -kernel ${INSTALL_DIR}/${KERNEL_NAME} -drive format=raw,file=${INSTALL_DIR}/${IMG_NAME},if=ide ${QEMU_FLAGS}

.PHONY: clean
clean: env # Clean the build and installation files
	make -C ${SOURCE_DIR} clean
	if [ "${INSTALL_DIR}" != "" ]; then rm -rf ${INSTALL_DIR}/; fi
	if [ -d ${IMG_TMP_MOUNT} ]; then rm -r ${IMG_TMP_MOUNT}; fi

.PHONY: distclean
distclean: env # Clean config files
	make -C ${SOURCE_DIR} distclean
	rm ${CONFIG_DIR}/${CONFIG_NAME}

.PHONY: log
log: env # Git log
	cd ${SOURCE_DIR} && git log

.PHONY: fetch
fetch: env # Git fetch
	cd ${SOURCE_DIR} && git fetch

.PHONY: merge
merge: env # Git merge
	cd ${SOURCE_DIR} && git merge

.PHONY: diff-origin
diff-origin: env # Git diff origin
	cd ${SOURCE_DIR} && git diff origin

.PHONY: diff
diff: env # Git diff local
	cd ${SOURCE_DIR} && git diff

.PHONY: pull
pull: env # Git pull
	cd ${SOURCE_DIR} && git pull

.PHONY: settings
settings: # Shows value of variables
	@echo ENV=${ENV}
	@echo ARCH=${ARCH}
	@echo SOURCE_DIR=${SOURCE_DIR}
	@echo INSTALL_DIR=${INSTALL_DIR}
	@echo KERNEL_NAME=${KERNEL_NAME}
	@echo MAKE_FLAGS=${MAKE_FLAGS}
	@echo CONFIG_DIR=${CONFIG_DIR}
	@echo CONFIG_NAME=${CONFIG_NAME}
	@echo IMG_NAME=${IMG_NAME}
	@echo IMG_TMP_MOUNT=${IMG_TMP_MOUNT}
	@echo IMG_FS=${IMG_FS}
	@echo IMG_PACKAGES=${IMG_PACKAGES}
	@echo IMG_USER=${IMG_USER}
	@echo IMG_SIZE=${IMG_SIZE}
	@echo DEBPPTSTRAP_DIR=${DEBOOTSTRAP_DIR}
	@echo QEMU_DIR=${QEMU_DIR}
	@echo QEMU_FLAGS=${QEMU_FLAGS}


.PHONY: help
help: # Shows help
	@echo "Linux Kernel Development Environment"
	@echo
	@echo "make targets:"
	@echo
	@sed -e's/^\([^: 	]\+\):.*#\(.*\)$$/\1 \2/p;d' Makefile | column -t -l 2 | sort
