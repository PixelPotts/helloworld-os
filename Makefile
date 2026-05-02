ARCH          = x86_64
GNUEFI_INC    = /usr/include/efi
GNUEFI_INC_A  = /usr/include/efi/x86_64
GNUEFI_LIB    = /usr/lib
CRT0          = /usr/lib/crt0-efi-x86_64.o
LDSCRIPT      = /usr/lib/elf_x86_64_efi.lds

CC            = gcc
LD            = ld
OBJCOPY       = objcopy

CFLAGS  = -I$(GNUEFI_INC) -I$(GNUEFI_INC_A) \
          -ffreestanding -fno-stack-protector -fpic -fshort-wchar \
          -mno-red-zone -Wall -DEFI_FUNCTION_WRAPPER

LDFLAGS = -nostdlib -znocombreloc -T $(LDSCRIPT) -shared \
          -Bsymbolic -L $(GNUEFI_LIB)

TARGET  = build/hello.efi
DISKIMG = disk/helloworld.img

.PHONY: all clean disk run

all: $(TARGET)

build/hello.o: hello.c | build
	$(CC) $(CFLAGS) -c -o $@ $<

build/hello.so: build/hello.o
	$(LD) $(LDFLAGS) $(CRT0) $< -o $@ -lefi -lgnuefi

$(TARGET): build/hello.so
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic \
	           -j .dynsym -j .rel -j .rela -j .reloc \
	           --target=efi-app-x86_64 $< $@
	@echo "Built: $(TARGET)"
	@file $(TARGET)

build:
	mkdir -p build

disk:
	mkdir -p disk

$(DISKIMG): $(TARGET) | disk
	./create-disk-image.sh

run: $(DISKIMG)
	./run-qemu.sh

clean:
	rm -rf build/ disk/
