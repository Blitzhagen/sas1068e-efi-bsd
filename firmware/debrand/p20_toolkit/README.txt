P20 debrand toolkit (community bundle, 2011) — the toolchain used for
the original Fujitsu->LSI crossflash of this card. Linux sasflash 1.24
binary: identical to ../../tools/sasflash_linux
(SHA256 7374058c41e62fefde9d121a0f7ed5280fdc4aa45ac57a00484c7401b8794e6c).

Two firmware variants per LSI packaging:
- 3Gs_6Gs_SATA_Support_Firmware   full SATA speed support (recommended)
- 1.5Gs_3Gs_SATA_Support_Firmware capped SATA (compat with old expanders)

Each dir contains the numbered scripts (list -> backup -> flash -> verify),
3081E* IR/IT firmware for silicon B1/B2/B3/C0, and mptsas.rom (BIOS 6.34).
Scripts flash 3081ERB3.fw — the 8-port retail build for the same 1068E
die. End state on this card was later updated to P21 (3041ERB3.fw /
BIOS 6.36 in the parent dir), verified byte-identical in the live dump.
