this-makefile := $(lastword $(MAKEFILE_LIST))
abs_srctree := $(realpath $(dir $(this-makefile)))

-include $(abs_srctree)/../../../build.conf

BUILD_DIR := $(abs_srctree)/build/$(PLATFORM)
BUILD_DIR_MAKEFILE := $(BUILD_DIR)/Makefile

KDIR = $(abs_srctree)/../../linux

obj-m := access_mod.o

access_mod-objs += access.o rpisense.o

.PHONY: module clean

module: $(abs_srctree)/../../../build.conf $(BUILD_DIR_MAKEFILE)
	@make -C $(KDIR) M=$(BUILD_DIR) src=$(abs_srctree) modules
	@mkdir -p ../out/$(PLATFORM)
	@cp $(BUILD_DIR)/*.ko ../out/$(PLATFORM)

$(BUILD_DIR):
	@mkdir -p "$@"

$(BUILD_DIR_MAKEFILE): $(BUILD_DIR)
	@touch "$@"

clean:
	@make -C $(KDIR) M=$(BUILD_DIR) src=$(abs_srctree) clean
	@rm -r $(BUILD_DIR)

