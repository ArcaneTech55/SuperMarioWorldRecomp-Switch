# Homebrew platform diagnostic; game core is not linked yet.
.SUFFIXES:
ifeq ($(strip $(DEVKITPRO)),)
$(error DEVKITPRO is not set)
endif
TOPDIR ?= $(CURDIR)
include $(DEVKITPRO)/libnx/switch_rules
TARGET := smw-recomp-platform-check
BUILD := build
SOURCES := .
INCLUDES := .
APP_TITLE := SMW Recomp Platform Check
APP_AUTHOR := ArcaneTech55
APP_VERSION := 0.1
ARCH := -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE
CFLAGS := -O2 -g -Wall -Wextra $(ARCH) -D__SWITCH__ $(INCLUDE) $(shell $(PREFIX)pkg-config --cflags sdl2)
CFLAGS += -std=gnu11
CXXFLAGS := $(CFLAGS) -fno-rtti -fno-exceptions
ASFLAGS := -g $(ARCH)
LDFLAGS := -specs=$(DEVKITPRO)/libnx/switch.specs -g $(ARCH) -Wl,-Map,$(notdir $*.map)
LIBS := $(shell $(PREFIX)pkg-config --libs sdl2) -lnx -lm
LIBDIRS := $(PORTLIBS) $(LIBNX)
CFILES := switch_smoke_main.c smw_switch_video.c smw_switch_input.c smw_switch_audio.c smw_switch_save.c

ifneq ($(BUILD),$(notdir $(CURDIR)))
export OUTPUT := $(CURDIR)/$(TARGET)
export TOPDIR := $(CURDIR)
export VPATH := $(CURDIR)
export DEPSDIR := $(CURDIR)/$(BUILD)
export OFILES := $(CFILES:.c=.o)
export INCLUDE := -I$(CURDIR) $(foreach dir,$(LIBDIRS),-I$(dir)/include) -I$(CURDIR)/$(BUILD)
export LIBPATHS := $(foreach dir,$(LIBDIRS),-L$(dir)/lib)
export NROFLAGS += --nacp=$(CURDIR)/$(TARGET).nacp
.PHONY: all clean
all:
	@mkdir -p $(BUILD)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile
clean:
	@rm -rf $(BUILD) $(TARGET).elf $(TARGET).nro $(TARGET).nacp
else
.PHONY: all
DEPENDS := $(OFILES:.o=.d)
all: $(OUTPUT).nro
$(OUTPUT).nro: $(OUTPUT).elf $(OUTPUT).nacp
$(OUTPUT).elf: $(OFILES)
-include $(DEPENDS)
endif
