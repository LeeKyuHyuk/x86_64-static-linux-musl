-include config.mk

export PARALLEL_JOBS := $(shell cat /proc/cpuinfo | grep cores | wc -l)
export WORKSPACE_DIR := $(shell cd "$(dirname "$0")" && pwd)
export SOURCES_DIR := $(WORKSPACE_DIR)/sources
export SUPPORT_DIR := $(WORKSPACE_DIR)/support
export SCRIPTS_DIR := $(WORKSPACE_DIR)/scripts
export OUTPUT_DIR := $(WORKSPACE_DIR)/out
export BUILD_DIR := $(OUTPUT_DIR)/build
export TOOLS_DIR := $(OUTPUT_DIR)/tools
export SYSROOT_DIR := $(TOOLS_DIR)/$(CONFIG_TARGET)/sysroot
export PATH := "$(TOOLS_DIR)/bin:$(TOOLS_DIR)/sbin:$(TOOLS_DIR)/usr/bin:$(TOOLS_DIR)/usr/sbin:$(PATH)"
export CONFIG_SITE := /dev/null
