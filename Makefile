include settings.mk

.PHONY: all toolchain clean

all:
	@make clean toolchain

toolchain:
	@$(SCRIPTS_DIR)/toolchain.sh

clean:
	@rm -rf out

download:
	@wget -c -i wget-list -P $(SOURCES_DIR)
