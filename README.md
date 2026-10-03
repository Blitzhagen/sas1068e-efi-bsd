# Fujitsu-OEM LSI SAS1068E → SAS3041E-R + nativer UEFI-Boot (EFI-BSD)

> **TL;DR (EN):** A Fujitsu-OEM **LSI SAS1068E B3** (`C1064E` die) had
> been crossflashed to generic LSI IR firmware. This repo documents the
> remaining cleanup: rewriting the leftover OEM manufacturing strings
> to a retail **SAS3041E-R** identity via `lsiutil` (no reflash), and
> flashing the previously empty **EFI-BSD slot** with the official LSI
> retail UEFI driver **3.22.00.00** — so the IR RAID volume can be
> exposed directly to a modern UEFI BIOS without CSM. All backups,
> tools, images, commands and verification logs are included.

---

## Hardware

| Komponente | Wert |
|---|---|
| Karte | Fujitsu-OEM-Board, LSI **SAS1068E B3** (Chip `C1064E`, 4-Port-Variante) |
| PCI | `04:00.0`, `1000:0058`, Subsystem `1734:1130` (Fujitsu — unverändert) |
| Firmware | `MPTFW-01.33.00.00-IE` (generisches LSI **IR**) |
| x86-BIOS | `MPTBIOS-6.36.00.00` |
| EFI-BSD | `3.22.00.00` *(neu geflasht, Slot war leer)* |
| SAS-WWID | `5003005700d067e0` (unverändert) |
| Board | `SAS3041E-R` / `SAS3041E-R00` / `SP3041ER01` |
| Mainboard | MSI MPG B550 GAMING PLUS (MS-7C56), UEFI (Secure Boot aus) |
| OS | Kubuntu, Kernel-Treiber `mptsas`, Zugriff via `/dev/mptctl` |

**Zielsetzung:** Multi-Boot-System — NVMe = Windows, SATA-SSD =
Mediaserver, IR-RAID-Volume auf dem Controller = Linux. Die Karte soll
direkt unter UEFI nutzbar sein, **ohne** Umweg über einen zusätzlichen
Bootloader auf NVMe und **ohne** CSM/Legacy-Modus.

---

## Historie

### 1. Originalzustand (Fujitsu-OEM)

PRIMERGY-OEM-Board. Manufacturing-Pages trugen noch Fujitsu-Identität:

- `BoardName = 1064SASIME-3030` — „IME" = Fujitsu **I**ntegrated
  **M**irroring **E**nhanced (LSI-IR-Featureset)
- `BoardAssembly = 2010-02-26-0`, `BoardTracer = FTS00000001`
- `ManufacturingPage4`: `LSILOGIC Logical Volume` (IR-RAID-Metadata)
- PCI-Subsystem `1734:1130` / NVRAM-Eintrag `1734:1195` (Fujitsu)

→ Rohzustand: `backup/config_pages_pre_20261003_235801.txt`

### 2. Debranding (früher durchgeführt, Bestandszustand)

Die Karte wurde zuvor bereits **gecrossflasht**: Fujitsu-Firmware →
generisches **LSI IR 1.33.00.00** + MPT-BIOS 6.36. Danach mit
Windows-„MegaRAID SAS Manager" verwaltbar (RAID 0/1/1E/10E). Zurück
blieben nur die OEM-Strings in den Manufacturing-Pages (NVData) und die
Fujitsu-Subsystem-ID.

### 3. Identity-Vereinheitlichung → SAS3041E-R

Chirurgischer Edit der `ManufacturingPage0` per `lsiutil`
(Config-Page-Editor, Option 9 → PageType 9 → Page 0 → NVRAM), **kein
Reflash nötig**, SAS-WWID und PCI-IDs unberührt:

| Feld | Offset | Vorher | Nachher |
|---|---|---|---|
| BoardName | 0x1c | `1064SASIME-3030` | `SAS3041E-R` |
| BoardAssembly | 0x2c | `2010-02-26-0` | `SAS3041E-R00` |
| BoardTracer | 0x3c | `FTS00000001` | `SP3041ER01` |

Der Diff `backup/config_pages_pre_*` ↔ `backup/config_pages_post_*`
zeigt exakt die 9 geänderten 32-Bit-Worte — sonst nichts.

> Hintergrund der Wahl: Die SAS3041E-R ist das LSI-Retail-Pendant mit
> internem SFF-8087 — baut auf exakt dem `C1064E`-Die dieser Karte auf.
> Die Fujitsu-Subsystem-ID (`1734:1130`) wurde bewusst **behalten**.

### 4. EFI-BSD 3.22.00.00 flashen (aktueller Stand)

Problem: Das UEFI des B550-Boards kann das Legacy-x86-Option-ROM nicht
laden → Controller/RAID vor dem OS-Start unsichtbar, kein Ctrl-C-Menü,
kein Boot-Device.

Lösung: Der Flash der 1068E-Familie hat einen separaten **EFI-BSD-Slot**
(neben Firmware/x86-BIOS/NVData), der hier leer war (`No Image`).
Geflasht wurde das **originale LSI-Retail-Image** aus
`EFI_BSD_PH_21-3.22.00.zip` (Phase 21, 08/2011 — kompatibel laut
Readme mit allen `SAS106X` + `SAS1078`):

- Image: `firmware/lsisasx64.rom` (137 728 B, PCI-ROM, CodeType `0x03` =
  EFI, Variante `IRSCSI_NONIRSAS` = IR-Volumes als SCSI-Bootdevices,
  nicht-IR-Disks als SAS)
- SHA256: `50acc0f3fd18a48bbccd0a7a5745429179518cc600b04a8a4665e52155ecb445`

```bash
# VORHER: komplette Sicherung
sasflash -o -uflash fullflash.bin -unvdata nvdata.bin \
         -ubios bios.rom -ufirmware fw.fw

# Flash (nur der leere EFI-BSD-Slot wird beschrieben)
sasflash -o -b lsisasx64.rom
```

`sasflash` validiert dabei Header-Signatur, Checksumme und
Controller-Kompatibilität vor dem Schreiben.

**Verifikation** (`sasflash -listall` / `lsiutil -i`):

```
Num  Ctlr       FW Ver       NVDATA   x86-BIOS     EFI-BSD    PCI Addr
1    1068E(B3)  01.33.00.00  2d.54    06.36.00.00  03.22.00.00  00:04:00:00
```

Firmware, x86-BIOS, SAS-WWID, Board-Identität: alle unverändert;
`lsiutil -i` meldet zusätzlich `EFI BIOS image's version is 3.22.00.00`.

---

## Repo-Inhalt

```
backup/    Sicherungen & Zustandsdumps
           ├─ fullflash_pre_efibsd_*.bin   komplettes 2-MiB-Flash-Image
           ├─ nvdata_pre_efibsd_*.bin      rohes NVRAM
           ├─ bios_pre_efibsd_*.rom        Boot-Services-Region
           ├─ fw_pre_efibsd_*.fw           Firmware
           ├─ firmware_01210000.bin        Firmware-Dump (lsiutil)
           ├─ bios_061a00.rom              früherer BIOS-Regions-Dump
           ├─ config_pages_pre/post_*.txt  komplette Config-Page-Dumps
           ├─ board_info/port_settings/targets_*.txt
           └─ SHA256SUMS_all.txt, Flash-/Backup-Logs
firmware/  Original-Pakete & Flash-Images
           ├─ EFI_BSD_PH_21-3.22.00.zip    LSI EFI-BSD (Retail, P21)
           ├─ Installer_P21_for_EFI.zip    inkl. sasflash.efi (x64/EBC/Itanium)
           ├─ lsisasx64.rom               ← geflashtes Image (IRSCSI_NONIRSAS)
           ├─ x64sas.efi                  Treiber als ladbare Datei (Shell-Test)
           ├─ sasflash_x64.efi            UEFI-Shell-Flashtool (bios32)
           ├─ Readme_EFI_BSD.txt          Original-Readme
           └─ SHA256SUMS.txt
tools/     lsiutil.x86_64 (v1.71, 64-bit) + sasflash (Linux, statisch)
```

---

## Voraussetzungen & Bedienung

`lsiutil`/`sasflash` (Linux) reden über `/dev/mptctl` mit der Karte:

```bash
sudo modprobe mptctl
sudo chmod 0666 /dev/mptctl     # oder lsiutil/sasflash als root

tools/lsiutil.x86_64 -p 1 -i    # Port-Info, FW/BIOS/EFI-Versionen, WWID
tools/lsiutil.x86_64 -p 1 -b    # Board-Identität
tools/lsiutil.x86_64 -p 1 -d > dump.txt   # komplette Config-Pages
tools/sasflash_linux -listall   # Flash-Slot-Übersicht
```

RAID-Volume anlegen: `lsiutil` Option 21 (RAID actions) unter Linux oder
später im UEFI-Setup-Utility des EFI-BSD (falls geladen). Monitoring:
`mpt-status` (apt) via `/dev/mptctl`.

## Rollback

| Fall | Kommando |
|---|---|
| EFI-BSD entfernen | `sasflash -o -e 5` (Boot-Services-Segment löschen), dann `sasflash -o -b backup/bios_pre_efibsd_*.rom` (x86-BIOS zurück) |
| Firmware zurück | `sasflash -o -f backup/fw_pre_efibsd_*.fw` |
| NVRAM/Identität | `lsiutil` Page-Editor mit Original-Worten aus `config_pages_pre_*` bzw. `-sasadd/-assem/-tracer` |
| Total-Restore | aus `fullflash_pre_efibsd_*.bin` (bitgenau, inkl. Bootloader) |

Worst Case (Stromausfall mittendrin → Bootloader korrupt): externer
SPI-Flasher (z. B. CH341A) an den Flash-Chip der Karte.

## Quellen & Referenzen

- LSI EFI-BSD P21 Paket (Original-Download, archiviert):
  `http://www.lsi.com/downloads/Public/Host%20Bus%20Adapters/Host%20Bus%20Adapters%20Common%20Files/SAS_SATA_3G_P21/EFI_BSD_PH_21-3.22.00.zip`
  → Wayback: https://web.archive.org/web/20130329133656/http://www.lsi.com/downloads/Public/Host%20Bus%20Adapters/Host%20Bus%20Adapters%20Common%20Files/SAS_SATA_3G_P21/EFI_BSD_PH_21-3.22.00.zip
- `Installer_P21_for_EFI.zip` (sasflash.efi): gleiches Verzeichnis,
  Wayback-Snapshot 2013-03-29
- `lsiutil` 1.71: scene.org-Mirror —
  http://http.pl.scene.org/packages/LSI/sw/lsiutil-1.71/lsiutil.x86_64
- LSI-Downloadbaum (Tools/Pakete): http://http.pl.scene.org/packages/LSI/
- IBM ServeRAID BR10i v2.75 (alternativer EFI-BSD 3.16.00.06,
  `uefi_3.16.00.06.rom`): Lenovo Doc DS108321 —
  https://www.ibm.com/support/pages/lsi-1068e-sas-controller-bios-and-firmware-update-v275-linux-ibm-system-x
  (Originaldatei hinter IBM-Login; Extraktionsanleitung:
  https://andidittrich.com/2016/06/firmware-update-of-ibm-serveraid-br10i-with-ubuntu.html)
- EFI-BSD-Existenznachweis auf 1068E (`sasflash -listall` mit `No Image`):
  http://sunhelp.org/pipermail/rescue_sunhelp.org/2020-July/142244.html
- LSI-EFI-Treiber-Historie (XServe-Ära): InsanelyMac-Thread
  https://www.insanelymac.com/forum/topic/94679-sas-controllers-w-efi-for-mac-os-x-osx86-solutions/
- Firmware-Forschung 1064/1068E (P21 IT/IR-Blobs):
  https://github.com/cm68/lsi-mpt-large

## Hinweise

- Alle Firmware-/Treiberdateien sind **originale LSI/Avago-Releases**
  (bzw. Dumps der eigenen Karte) und dienen Dokumentations-/Recovery-
  Zwecken. Marken gehören den jeweiligen Eigentümern (LSI, Broadcom,
  Fujitsu, IBM, MSI).
- **Verifiziert (2026-10-04, MSI MPG B550 Gaming Plus, Aptio):**
  Der Treiber lädt aus dem Option-ROM (UEFI-Shell `drivers` zeigt
  „LSI Logic Fusion MPT SAS Driver" mit Image-Quelle `Offset`),
  exportiert ein RAID-1E-Volume als `BlockIo`-Device, und eine
  FAT32-ESP auf dem Volume mit `\EFI\BOOT\BOOTX64.EFI` wird von der
  Firmware gebootet (Boot-Eintrag „UEFI OS"). Nebeneffekte: HDDs
  drehen bereits im POST hoch (Bustopologie-Scan) und der
  Board-Splashscreen wird unterdrückt (Treiber greift in die
  Grafikkonsole ein) — beides harmlos.
- Flashen erfolgt auf eigene Gefahr — immer erst `sasflash -o -uflash`.
- Der SAS-WWID in den Dumps ist eine hardwareeigene Adresse
  (steht auch auf dem Kartenaufkleber), keine Zugangsdaten.
