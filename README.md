# Fujitsu-OEM LSI SAS1068E → SAS3041E-R + native UEFI boot (EFI-BSD)

**[English](README.md) | [Deutsch](README.de.md)**

> **TL;DR:** A Fujitsu-OEM **LSI SAS1068E B3** (`C1064E` die) had been
> crossflashed to generic LSI IR firmware. This repo documents the
> remaining cleanup: rewriting the leftover OEM manufacturing strings
> to a retail **SAS3041E-R** identity via `lsiutil` (no reflash), and
> flashing the previously empty **EFI-BSD slot** with the official LSI
> retail UEFI driver **3.22.00.00** — verified to load on a modern
> (2026) AMI Aptio board and boot an ESP on the IR RAID volume. All
> backups, tools, images, commands and verification logs are included.

---

## Hardware

| Component | Value |
|---|---|
| Card | Fujitsu-OEM board, LSI **SAS1068E B3** (`C1064E` die, 4-port variant) |
| PCI | `04:00.0`, `1000:0058`, subsystem `1734:1130` (Fujitsu — unchanged) |
| Firmware | `MPTFW-01.33.00.00-IE` (generic LSI **IR**) |
| x86 BIOS | `MPTBIOS-6.36.00.00` |
| EFI-BSD | `3.22.00.00` *(newly flashed, slot was empty)* |
| SAS WWID | `5003005700d067e0` (unchanged) |
| Board identity | `SAS3041E-R` / `SAS3041E-R00` / `SP3041ER01` |
| Mainboard | MSI MPG B550 GAMING PLUS (MS-7C56), pure UEFI (Secure Boot off) |
| OS | Kubuntu, kernel driver `mptsas`, access via `/dev/mptctl` |
| Disks | Backplane + 4 drives behind the controller, RAID 1E (~598 GB) |

**Goal:** Multi-boot system — NVMe = Windows, SATA SSD = media server,
IR RAID volume on the controller = Linux. The card must be usable
directly under UEFI — **no** extra bootloader on NVMe and **no**
CSM/legacy mode.

---

## History

### 1. Original state (Fujitsu OEM)

PRIMERGY OEM board. Manufacturing pages carried Fujitsu identity:

- `BoardName = 1064SASIME-3030` — "IME" = Fujitsu **I**ntegrated
  **M**irroring **E**nhanced (LSI IR feature set)
- `BoardAssembly = 2010-02-26-0`, `BoardTracer = FTS00000001`
- `ManufacturingPage4`: `LSILOGIC Logical Volume` (IR RAID metadata)
- PCI subsystem `1734:1130` / NVRAM entry `1734:1195` (Fujitsu)

→ Raw state: `backup/config_pages_pre_20261003_235801.txt`

### 2. Debranding (crossflash to generic LSI firmware)

The card had previously been **crossflashed** from Fujitsu OEM firmware
to generic **LSI IR 1.33.00.00** (Phase 21 GCA, per
`Firmware_release_notes.txt`) + `mptsas.rom` BIOS 6.36. Afterwards it
is manageable with Windows MegaRAID Storage Manager (RAID 0/1/1E/10E).
Leftovers before our cleanup: OEM strings in the manufacturing pages
(NVData) and the Fujitsu subsystem ID.

**The flashable files** live in `firmware/debrand/` (from the official
LSI `SAS3041ER` P21 package, mirrored in cm68/lsi-mpt-large):

| File | Purpose |
|---|---|
| `3041ERB3.fw` | **IR/RAID firmware for B3 silicon — what this card runs** |
| `3041ETB3.fw` | IT (pure HBA/JBOD) firmware for B3 silicon |
| `3041ERB2.fw` / `3041ETB2.fw` | same for older B2 silicon |
| `mptsas.rom` | x86 option-ROM BIOS 6.36.00.00 |
| `hbaFlash.bat` | original LSI flash script (DOS) |
| `*_release_notes.txt`, `MPT_READ.TXT` | official LSI docs |

Command (Linux after `modprobe mptctl`, or DOS/FreeDOS USB stick):

```bash
sasflash -o -f 3041ERB3.fw -b mptsas.rom   # IR mode: RAID 0/1/1E/10E
sasflash -o -f 3041ETB3.fw -b mptsas.rom   # IT mode: pure HBA
```

Pick the file for your **chip revision** — `sasflash -listall` shows
`1068E(B3)` → `*B3.fw` (B2 cards → `*B2.fw`).

Vendor-locked OEM firmware may reject the image; then erase first:
`sasflash -o -e 6` (clears everything except the manufacturing area —
the SAS address survives) or `-e 7` (complete erase; the SAS address
must be reprogrammed via `-sasadd`, it is printed on the card label).

**Provenance proof:** our `-ufirmware` dump
(`backup/fw_pre_efibsd_*.fw`) is **byte-identical to `3041ERB3.fw` up to
offset 276 949** — only the trailing card-specific NVRAM region
differs. The version string `MPTFW-01.33.00.00-IE` matches. And
`3041ERB3.fw` is byte-identical to the independently published
`1064E_P21_IR_B3.fw` blob in the cm68/lsi-mpt-large repo (SHA256
`44b93238…`). The package's `mptsas.rom` carries the same
`MPTBIOS-6.36.00.00` signature as our BIOS dump.

### 3. Identity unification → SAS3041E-R

Surgical edit of `ManufacturingPage0` via `lsiutil`
(config page editor, option 9 → page type 9 → page 0 → NVRAM),
**no reflash needed**, SAS WWID and PCI IDs untouched:

| Field | Offset | Before | After |
|---|---|---|---|
| BoardName | 0x1c | `1064SASIME-3030` | `SAS3041E-R` |
| BoardAssembly | 0x2c | `2010-02-26-0` | `SAS3041E-R00` |
| BoardTracer | 0x3c | `FTS00000001` | `SP3041ER01` |

The diff `backup/config_pages_pre_*` ↔ `backup/config_pages_post_*`
shows exactly the 9 changed 32-bit words — nothing else.

> Rationale: the SAS3041E-R is the LSI retail counterpart with an
> internal SFF-8087 connector — built on exactly this card's `C1064E`
> die. The Fujitsu subsystem ID (`1734:1130`) was deliberately **kept**.

### 4. Flashing EFI-BSD 3.22.00.00 (current state)

Problem: the B550 UEFI cannot load the legacy x86 option ROM →
controller/RAID invisible before OS start, no Ctrl-C menu, no boot
device.

Solution: the 1068E-family flash has a dedicated **EFI-BSD slot**
(alongside firmware/x86 BIOS/NVData) which was empty (`No Image`).
We flashed the **original LSI retail image** from
`EFI_BSD_PH_21-3.22.00.zip` (Phase 21, 08/2011 — compatible with all
`SAS106X` + `SAS1078` per the readme):

- Image: `firmware/lsisasx64.rom` (137 728 B, PCI ROM, code type `0x03`
  = EFI, variant `IRSCSI_NONIRSAS` = IR volumes exported as SCSI boot
  devices, non-IR disks as SAS)
- SHA256: `50acc0f3fd18a48bbccd0a7a5745429179518cc600b04a8a4665e52155ecb445`

```bash
# BEFORE: full backup
sasflash -o -uflash fullflash.bin -unvdata nvdata.bin \
         -ubios bios.rom -ufirmware fw.fw

# Flash (only the empty EFI-BSD slot is written)
sasflash -o -b lsisasx64.rom
```

`sasflash` validates header signature, checksum and controller
compatibility before writing.

**Verification** (`sasflash -listall` / `lsiutil -i`):

```
Num  Ctlr       FW Ver       NVDATA   x86-BIOS     EFI-BSD    PCI Addr
1    1068E(B3)  01.33.00.00  2d.54    06.36.00.00  03.22.00.00  00:04:00:00
```

Firmware, x86 BIOS, SAS WWID, board identity: all unchanged; `lsiutil
-i` additionally reports `EFI BIOS image's version is 3.22.00.00`.

### 5. Verified working on modern UEFI (MSI B550, Aptio)

Tested with a UEFI shell booted from the board itself:

- `drivers` lists **"LSI Logic Fusion MPT SAS Driver"** with image
  source `Offset(...)` = loaded **from the card's option ROM** ✅
- Driver bound to the controller (1 device, 1 child) ✅
- `map`/`dh -p BlockIo` show the RAID volume as block device
  (`BLK6`, path `.../Scsi(0x0,0x0)`) ✅
- A FAT32 ESP created on the volume with `\EFI\BOOT\BOOTX64.EFI`
  booted the UEFI shell **end-to-end** and was registered by the
  firmware as boot entry **"UEFI OS"** ✅

Harmless side effects: HDDs spin up during POST (the driver scans the
SAS topology), and the mainboard splash logo is suppressed (the driver
resets the display console during init). BIOS setup remains reachable
via DEL/F11.

---

## Repo contents

```
backup/    Backups & state dumps
           ├─ fullflash_pre_efibsd_*.bin   complete 2 MiB flash image
           ├─ nvdata_pre_efibsd_*.bin      raw NVRAM
           ├─ bios_pre_efibsd_*.rom        boot-services region
           ├─ fw_pre_efibsd_*.fw           firmware
           ├─ firmware_01210000.bin        firmware dump (lsiutil)
           ├─ bios_061a00.rom              earlier BIOS region dump
           ├─ config_pages_pre/post_*.txt  full config-page dumps
           ├─ board_info/port_settings/targets_*.txt
           └─ SHA256SUMS_all.txt, flash/backup logs
firmware/  Original packages & flash images
           ├─ debrand/                  ← Debranding files (section 2):
           │    ├─ 3041ERB3.fw          IR fw B3 — this card's image
           │    ├─ 3041ETB3.fw          IT fw B3 (HBA alternative)
           │    ├─ 3041E{B,R}B2.fw      B2 silicon variants
           │    ├─ 1064E_P21_*.fw       same blobs, cm68 mirror
           │    ├─ mptsas.rom           x86 BIOS 6.36.00.00
           │    ├─ hbaFlash.bat         original LSI DOS flash script
           │    └─ release notes, SHA256SUMS.txt
           ├─ EFI_BSD_PH_21-3.22.00.zip    LSI EFI-BSD (retail, P21)
           ├─ Installer_P21_for_EFI.zip    incl. sasflash.efi (x64/EBC/Itanium)
           ├─ lsisasx64.rom               ← the flashed image (IRSCSI_NONIRSAS)
           ├─ x64sas.efi                  driver as loadable file (shell test)
           ├─ sasflash_x64.efi            UEFI-shell flash tool (bios32)
           ├─ Readme_EFI_BSD.txt          original readme
           └─ SHA256SUMS.txt
tools/     lsiutil.x86_64 (v1.71, 64-bit) + sasflash (Linux, static)
```

---

## Requirements & usage

`lsiutil`/`sasflash` (Linux) talk to the card via `/dev/mptctl`:

```bash
sudo modprobe mptctl
sudo chmod 0666 /dev/mptctl     # or run lsiutil/sasflash as root

tools/lsiutil.x86_64 -p 1 -i    # port info, FW/BIOS/EFI versions, WWID
tools/lsiutil.x86_64 -p 1 -b    # board identity
tools/lsiutil.x86_64 -p 1 -d > dump.txt   # full config pages
tools/sasflash_linux -listall   # flash slot overview
```

Creating a RAID volume: `lsiutil` option 21 (RAID actions) under Linux,
or via the EFI-BSD's UEFI setup page (if shown). Monitoring:
`mpt-status` (apt) via `/dev/mptctl`.

## Rollback

| Case | Command |
|---|---|
| Remove EFI-BSD | `sasflash -o -e 5` (erase Boot Services segment), then `sasflash -o -b backup/bios_pre_efibsd_*.rom` (restore x86 BIOS) |
| Restore firmware | `sasflash -o -f backup/fw_pre_efibsd_*.fw` |
| NVRAM/identity | `lsiutil` page editor with original words from `config_pages_pre_*`, or `-sasadd/-assem/-tracer` |
| Full restore | from `fullflash_pre_efibsd_*.bin` (bit-exact, incl. boot loader) |

Worst case (power loss mid-flash → corrupt boot loader): external SPI
programmer (e.g. CH341A) on the card's flash chip.

## Sources & references

- LSI EFI-BSD P21 package (original download, archived):
  `http://www.lsi.com/downloads/Public/Host%20Bus%20Adapters/Host%20Bus%20Adapters%20Common%20Files/SAS_SATA_3G_P21/EFI_BSD_PH_21-3.22.00.zip`
  → Wayback: https://web.archive.org/web/20130329133656/http://www.lsi.com/downloads/Public/Host%20Bus%20Adapters/Host%20Bus%20Adapters%20Common%20Files/SAS_SATA_3G_P21/EFI_BSD_PH_21-3.22.00.zip
- `Installer_P21_for_EFI.zip` (sasflash.efi): same directory,
  Wayback snapshot 2013-03-29
- `lsiutil` 1.71: scene.org mirror —
  http://http.pl.scene.org/packages/LSI/sw/lsiutil-1.71/lsiutil.x86_64
- LSI download tree (tools/packages): http://http.pl.scene.org/packages/LSI/
- IBM ServeRAID BR10i v2.75 (alternative EFI-BSD 3.16.00.06,
  `uefi_3.16.00.06.rom`): Lenovo Doc DS108321 —
  https://www.ibm.com/support/pages/lsi-1068e-sas-controller-bios-and-firmware-update-v275-linux-ibm-system-x
  (original file behind IBM login; extraction guide:
  https://andidittrich.com/2016/06/firmware-update-of-ibm-serveraid-br10i-with-ubuntu.html)
- EFI-BSD existence evidence on 1068E (`sasflash -listall` with `No Image`):
  http://sunhelp.org/pipermail/rescue_sunhelp.org/2020-July/142244.html
- LSI EFI driver history (XServe era): InsanelyMac thread
  https://www.insanelymac.com/forum/topic/94679-sas-controllers-w-efi-for-mac-os-x-osx86-solutions/
- Firmware research 1064/1068E (P21 IT/IR blobs):
  https://github.com/cm68/lsi-mpt-large
- UEFI Shell binaries: https://github.com/pbatard/UEFI-Shell

## Notes

- All firmware/driver files are **original LSI/Avago releases** (or
  dumps of our own card) and serve documentation/recovery purposes.
  Trademarks belong to their respective owners (LSI, Broadcom, Fujitsu,
  IBM, MSI).
- The EFI-BSD driver dates from 2011 — loading was **verified** on a
  2026 MSI B550 Aptio firmware (see section 5). Other boards may behave
  differently; a rejected driver leaves the card working as before.
- Flash at your own risk — always `sasflash -o -uflash` first.
- The SAS WWID in the dumps is a hardware address (also printed on the
  card's sticker), not credentials.
