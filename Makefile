ENV?=linux
-include .env-${ENV}

PWD=${shell pwd}
SOURCE_DIR?=${PWD}/sources/${ENV}
INSTALL_DIR?=${PWD}/install/${ENV}
MAKE_FLAGS?=
MAKE_FLAGS+=-j${shell nproc}
CONFIG_DIR?=${PWD}/config
CONFIG_NAME?=.config-${ENV}

.PHONY: env
env: # Print the ENV value
	@echo Using ENV=${ENV}

.PHONY: configure
defconfig: env # Generate the default .config file
	make -C ${SOURCE_DIR} defconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

.PHONY: tinyconfig
tinyconfig: env # Generate the tinyconfig
	make -C ${SOURCE_DIR} tinyconfig
	mv ${SOURCE_DIR}/.config ${CONFIG_DIR}/${CONFIG_NAME}

.PHONY: build
build: env ${CONFIG_DIR}/${CONFIG_NAME} # Build the kernel
	cp ${CONFIG_DIR}/${CONFIG_NAME} ${SOURCE_DIR}/.config
	make -C ${SOURCE_DIR} ${MAKE_FLAGS}

.PHONY: install
install: env # Install the kernel
	INSTALL_PATH=${INSTALL_DIR} make -C ${SOURCE_DIR} install

.PHONY: install-modules
install-modules: env # Install the modules
	INSTALL_PATH=${INSTALL_DIR} make -C ${SOURCE_DIR} install-modules

.PHONY: clean
clean: env # Clean the build files
	make -C ${SOURCE_DIR} clean

.PHONY: distclean
distclean: env
	make -C ${SOURCE_DIR} distclean

.PHONY: settings
settings: # Shows value of variables
	@echo ENV=${ENV}
	@echo SOURCE_DIR=${SOURCE_DIR}
	@echo INSTALL_DIR=${INSTALL_DIR}
	@echo MAKE_FLAGS=${MAKE_FLAGS}
	@echo CONFIG_DIR=${CONFIG_DIR}
	@echo CONFIG_NAME=${CONFIG_NAME}

.PHONY: help
help: # Shows help
	@echo "Linux Kernel Development Environment"
	@echo
	@echo "make targets:"
	@echo
	@sed -e's/^\([^: 	]\+\):.*#\(.*\)$$/\1 \2/p;d' Makefile | column -t -l 2 | sort
