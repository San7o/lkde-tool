# SPDX-License-Identifier: MIT
# Author:  Giovanni Santini
# Mail:    giovanni.santini@proton.me
# License: MIT

#
# Config
#

obj-m      += hello.o
MODULE_DIR  = ${PWD}/module

#
# Commands
#

##@ Module

.PHONY: module-prepare
module-prepare: oldconfig ## Prepares the kernel to build modules
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} ${MAKE_FLAGS} modules_prepare
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} ${MAKE_FLAGS} modules

.PHONY: module
module: oldconfig ## Build the kernel module
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} ${MAKE_FLAGS} M=${MODULE_DIR} modules 

.PHONY: module-clean
module-clean: oldconfig ## Clean the kernel module
	make ${KERNEL_FLAGS} -C ${SOURCE_DIR} ${MAKE_FLAGS} M=${MODULE_DIR} clean

.PHONY: module-copy
module-copy: module ## Copy the kernel module in the image
	if mountpoint -q ${IMG_TMP_MOUNT}; then sudo umount -R ${IMG_TMP_MOUNT}; fi
	mkdir -p ${IMG_TMP_MOUNT}
	sudo mount -o loop ${INSTALL_DIR}/${IMG_NAME} ${IMG_TMP_MOUNT}
	sudo cp $(patsubst %.o, %.ko, ${MODULE_DIR}/${obj-m}) ${IMG_TMP_MOUNT}/root
	sudo umount -R ${IMG_TMP_MOUNT}
	rmdir ${IMG_TMP_MOUNT}
	sync
