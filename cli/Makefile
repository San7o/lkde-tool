# SPDX-License-Identifier: MIT
# Author:  Giovanni Santini
# Mail:    giovanni.santini@proton.me
# License: MIT

CLI_DIR     ?= cli
CLI_RUSTC   ?= rustc
CLI_RFLAGS  ?= --edition 2021
CLI_LDFLAGS ?= -L libc
CLI_ARGS    ?=

CLI_SRC     ?= ${CLI_DIR}/cli.rs
CLI_OUT     ?= ${CLI_DIR}/cli

##@ Cli

cli: ${CLI_OUT} ## Build the cli tool

cli-debug: CLI_RFLAGS += -g
cli-debug: cli ## Build the cli with debug info

${CLI_OUT}: ${CLI_SRC}
	${CLI_RUSTC} ${CLI_LDFLAGS} ${CLI_SRC} ${CLI_RFLAGS} -o ${CLI_OUT}

cli-copy: ${CLI_OUT} ## Copy the cli tool in the image
	if mountpoint -q ${IMG_TMP_MOUNT}; then sudo umount -R ${IMG_TMP_MOUNT}; fi
	mkdir -p ${IMG_TMP_MOUNT}
	sudo mount -o loop ${INSTALL_DIR}/${IMG_NAME} ${IMG_TMP_MOUNT}
	sudo cp ${CLI_OUT} ${IMG_TMP_MOUNT}/root
	sudo umount -R ${IMG_TMP_MOUNT}
	rmdir ${IMG_TMP_MOUNT}
	sync

