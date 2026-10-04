# Fujitsu-OEM LSI SAS1068E → SAS3041E-R + nativer UEFI-Boot (EFI-BSD)

**[English](README.md) | [Deutsch](README.de.md)**

> **TL;DR:** Eine Fujitsu-OEM **LSI SAS1068E B3** (`C1064E`-Die) wurde
> zuvor auf generische LSI-IR-Firmware gecrossflasht. Dieses Repo
> dokumentiert die verbleibende Vereinheitlichung: die OEM-Reste in den
> Manufacturing-Pages wurden per `lsiutil` auf die Retail-Identität
> **SAS3041E-R** umgeschrieben (ohne Reflash), und der leere
> **EFI-BSD-Slot** wurde mit dem offiziellen LSI-Retail-UEFI-Treiber
> **3.22.00.00** geflasht — verifiziert lauffähig auf einem modernen
> (2026) AMI-Aptio-Board, inkl. Boot einer ESP auf dem IR-RAID-Volume.
> Alle Backups, Tools, Images, Befehle und Verifikations-Logs sind
> enthalten.

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
| Board-Identität | `SAS3041E-R` / `SAS3041E-R00` / `SP3041ER01` |
| Mainboard | MSI MPG B550 GAMING PLUS (MS-7C56), reines UEFI (Secure Boot aus) |
| OS | Kubuntu, Kernel-Treiber `mptsas`, Zugriff via `/dev/mptctl` |
| Disks | Backplane + 4 Platten am Controller, RAID 1E (~598 GB) |

**Zielsetzung:** Multi-Boot-System — NVMe = Windows, SATA-SSD =
Mediaserver, IR-RAID-Volume auf dem Controller = Linux. Die Karte soll
direkt unter UEFI nutzbar sein — **ohne** zusätzlichen Bootloader auf
NVMe und **ohne** CSM/Legacy-Modus.

---

## Historie

### 1. Originalzustand (Fujitsu-OEM)

PRIMERGY-OEM-Board. Manufacturing-Pages trugen Fujitsu-Identität:

- `BoardName = 1064SASIME-3030` — „IME" = Fujitsu **I**ntegrated
  **M**irroring **E**nhanced (LSI-IR-Featureset)
- `BoardAssembly = 2010-02-26-0`, `BoardTracer = FTS00000001`
- `ManufacturingPage4`: `LSILOGIC Logical Volume` (IR-RAID-Metadaten)
- PCI-Subsystem `1734:1130` / NVRAM-Eintrag `1734:1195` (Fujitsu)

→ Rohzustand: `backup/config_pages_pre_20261003_235801.txt`

### 2. Debranding (Crossflash auf generische LSI-Firmware)

Die Karte wurde zuvor bereits **gecrossflasht**: Fujitsu-OEM-Firmware →
generisches **LSI IR 1.33.00.00** (Phase 21 GCA, lt.
`Firmware_release_notes.txt`) + `mptsas.rom` BIOS 6.36. Danach mit
Windows-„MegaRAID SAS Manager" verwaltbar (RAID 0/1/1E/10E). Vor
unserer Bereinigung zurückgeblieben: OEM-Strings in den
Manufacturing-Pages (NVData) und die Fujitsu-Subsystem-ID.

**Die Flash-Dateien** liegen in `firmware/debrand/` (aus dem offiziellen
LSI-`SAS3041ER`-P21-Paket, gespiegelt in cm68/lsi-mpt-large):

| Datei | Zweck |
|---|---|
| `3041ERB3.fw` | **IR/RAID-Firmware für B3-Silizium — die Firmware dieser Karte** |
| `3041ETB3.fw` | IT-Firmware (reiner HBA/JBOD) für B3 |
| `3041ERB2.fw` / `3041ETB2.fw` | dasselbe für ältere B2-Silizium-Revision |
| `mptsas.rom` | x86-Option-ROM-BIOS 6.36.00.00 |
| `hbaFlash.bat` | originales LSI-Flash-Skript (DOS) |
| `*_release_notes.txt`, `MPT_READ.TXT` | offizielle LSI-Doku |

**Schritt-für-Schritt-Reproduktion** (Linux; die DOS/FreeDOS-Variante
per `hbaFlash.bat` macht denselben Flash interaktiv):

```bash
# 0. Device-Node + Kartenidentifikation
sudo modprobe mptctl && sudo chmod 0666 /dev/mptctl
tools/sasflash_linux -listall          # zeigt z. B. "LSI SAS 1068E(B3)"

# 1. ERST BACKUP — alles, bevor am Flash geschrieben wird
tools/sasflash_linux -o -uflash fullflash.bin -unvdata nvdata.bin \
                     -ubios bios.rom -ufirmware fw.fw -l backup.log -listall

# 2. Crossflash  (IR = RAID 0/1/1E/10E; 3041ETB3.fw = IT / reiner HBA)
tools/sasflash_linux -o -f 3041ERB3.fw -b mptsas.rom

# 3. Reboot, dann verifizieren
tools/sasflash_linux -listall          # → FW 01.33.00.00, BIOS 06.36.00.00
```

Erwarteter Dialog (vgl. `backup/flash_efibsd_*.log`):

```
Adapter Selected is a LSI SAS 1068E(B3):
Executing Operation: Flash Firmware Image  →  Flash Firmware: SUCCESSFUL!
Executing Operation: Flash BIOS Image      →  BIOS Flash: SUCCESSFUL!
```

Wichtige Details:

- **Chip-Revision:** `sasflash -listall` zeigt `1068E(B3)` → `*B3.fw`;
  B2-Silizium → `*B2.fw`.
- **Tool:** `tools/sasflash_linux` = LSI **SASFlash 1.24.00.00**
  (13.11.2009), statisches 32-bit-ELF — läuft auf aktuellen Kerneln;
  SHA256 `7374058c…94e6c`. Alle Flags: `SASFlash_Reference_Guide_
  v1_2-2008.pdf`.
- **Vendor-locked OEM-Firmware** verweigert evtl. das Image → erst
  löschen: `sasflash -o -e 6` (löscht alles außer der
  Manufacturing-Area; die SAS-Adresse bleibt erhalten) oder `-e 7`
  (komplett; SAS-Adresse danach per `-sasadd` neu programmieren —
  steht auf dem Kartenaufkleber).
- **Historischer Weg dieser Karte:** das Community-P20-Toolkit
  (`firmware/debrand/p20_toolkit/`, nummerierte Skripte `1_list →
  2_backup → 3_flash → 4_verify`, Firmware `3081ERB3.fw` + `mptsas.rom`
  6.34). Der Endzustand der Karte ist das obige P21-Set — wer es direkt
  flasht, erreicht denselben Stand in einem Schritt.

**Beleg der Provenienz:** Unser `-ufirmware`-Dump
(`backup/fw_pre_efibsd_*.fw`) ist **byteidentisch mit `3041ERB3.fw` bis
zu Byte 276.949** — nur die dahinterliegende kartenspezifische
NVRAM-Region weicht ab. Der Versionsstring `MPTFW-01.33.00.00-IE`
stimmt überein. Und `3041ERB3.fw` ist byteidentisch mit dem unabhängig
veröffentlichten Blob `1064E_P21_IR_B3.fw` aus cm68/lsi-mpt-large
(SHA256 `44b93238…`). Das `mptsas.rom` des Pakets trägt dieselbe
Signatur `MPTBIOS-6.36.00.00` wie unser BIOS-Dump.

### 3. Identity-Vereinheitlichung → SAS3041E-R

Chirurgischer Edit der `ManufacturingPage0` per `lsiutil` — **kein
Reflash nötig**, SAS-WWID und PCI-IDs unberührt. Komplette Sitzung:

```text
$ tools/lsiutil.x86_64 -p 1 -e            # -e = Expertenmenü
Select a device:  [1-1 or 0 to quit]  1
Main menu, select an option:          9   # Read/change config pages
Enter page type:   9                      # MANUFACTURING
Enter page number: 0
Read NVRAM or current values?  0          # 0 = NVRAM
    → 76-Byte-Hexdump der MfgPage0 erscheint
Do you want to make changes?  yes
Enter offset of value to change: <Hex-Offset>
Enter value:                     <8-stelliger Hex-DWord>
    → pro Zeile unten wiederholen, RETURN zum Abschluss
Do you want to write your changes?  yes   → "Changes have been written"
0 → Beenden        # Prüfen: lsiutil -p 1 -b
```

`lsiutil` zeigt die Page als little-endian-32-Bit-Wörter
(`Offset : DWord`) — den DWord exakt wie in der Tabelle eingeben
(`SAS3` wird als `33534153` gespeichert). Felder lt. `mpi_cnfg.h`:
BoardName@0x1c, BoardAssembly@0x2c, BoardTracer@0x3c (je 16 Byte,
NUL-terminiert):

| Offset | Wert | Bytes | Feld |
|---|---|---|---|
| `1c` | `33534153` | `SAS3` | BoardName → `SAS3041E-R` |
| `20` | `45313430` | `041E` | |
| `24` | `0000522d` | `-R\0\0` | |
| `28` | `00000000` | | *löscht OEM-Reste* |
| `2c` | `33534153` | `SAS3` | BoardAssembly → `SAS3041E-R00` |
| `30` | `45313430` | `041E` | |
| `34` | `3030522d` | `-R00` | |
| `38` | `00000000` | | |
| `3c` | `30335053` | `SP30` | BoardTracer → `SP3041ER01` |
| `40` | `52453134` | `41ER` | |
| `44` | `00003130` | `01\0\0` | |
| `48` | `00000000` | | |

`lsiutil` führt den nötigen IOC-Reinit um den Schreibvorgang automatisch
aus. Zustand vorher/nachher:

| Feld | Vorher (OEM) | Nachher |
|---|---|---|
| BoardName | `1064SASIME-3030` | `SAS3041E-R` |
| BoardAssembly | `2010-02-26-0` | `SAS3041E-R00` |
| BoardTracer | `FTS00000001` | `SP3041ER01` |

Der Diff `backup/config_pages_pre_*` ↔ `backup/config_pages_post_*`
zeigt die geänderten 32-Bit-Worte — sonst nichts. (Unser Edit hatte
Offset `28` ausgelassen, daher enthält `post` noch tote Bytes
`30 33 30` = `"030"` *hinter* der NUL an 0x26 — unsichtbarer Rest;
wer es sauber will, nullt ihn wie oben.)

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

- Image: `firmware/lsisasx64.rom` (137 728 B, PCI-ROM, CodeType `0x03`
  = EFI, Variante `IRSCSI_NONIRSAS` = IR-Volumes als SCSI-Bootdevices,
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

### 5. Verifiziert auf modernem UEFI (MSI B550, Aptio)

Getestet mit einer UEFI-Shell, gebootet direkt vom Board:

- `drivers` listet **„LSI Logic Fusion MPT SAS Driver"** mit
  Image-Quelle `Offset(...)` = geladen **aus dem Karten-Option-ROM** ✅
- Treiber an den Controller gebunden (1 Device, 1 Child) ✅
- `map`/`dh -p BlockIo` zeigen das RAID-Volume als Blockdevice
  (`BLK6`, Pfad `.../Scsi(0x0,0x0)`) ✅
- Eine FAT32-ESP auf dem Volume mit `\EFI\BOOT\BOOTX64.EFI` hat die
  UEFI-Shell **Ende-zu-Ende gebootet** und wurde von der Firmware als
  Boot-Eintrag **„UEFI OS"** registriert ✅

Harmlose Nebeneffekte: Die HDDs drehen bereits im POST hoch (der
Treiber scannt die SAS-Topologie), und das Board-Splash-Logo wird
unterdrückt (der Treiber greift in die Grafikkonsole ein). Das
BIOS-Setup bleibt per DEL/F11 erreichbar.

**Boot-Test reproduzieren** (jede EFI-App geht; wir nutzten
`shellx64.efi` von pbatard/UEFI-Shell):

```bash
# auf dem RAID-Volume (/dev/sdX lt. lsblk -o NAME,MODEL):
sudo parted -s /dev/sdX mklabel gpt mkpart ESP fat32 1MiB 1025MiB \
            mkpart rootfs 1025MiB 100% set 1 esp on
sudo mkfs.vfat -F32 /dev/sdX1
sudo mount /dev/sdX1 /mnt && sudo mkdir -p /mnt/EFI/BOOT
sudo cp shellx64.efi /mnt/EFI/BOOT/BOOTX64.EFI && sync && sudo umount /mnt
```

Reboot → F11-Bootmenü → das Volume taucht als **„UEFI OS"** auf
(`LSILOGIC Logical Volume`) → Auswahl startet die EFI-App =
Ende-zu-Ende-Beweis (UEFI → Karten-ROM-Treiber → RAID-Volume →
FAT32-ESP → EFI-Binary). Das Board registriert es außerdem als
persistenten `efibootmgr`-Eintrag (`BootXXXX UEFI OS →
HD(1,GPT,…)\EFI\BOOT\BOOTX64.EFI`).

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
           ├─ debrand/                  ← Debranding-Dateien (Abschn. 2):
           │    ├─ 3041ERB3.fw          IR-FW B3 — Image dieser Karte
           │    ├─ 3041ETB3.fw          IT-FW B3 (HBA-Alternative)
           │    ├─ 3041E{B,R}B2.fw      B2-Silizium-Varianten
           │    ├─ 1064E_P21_*.fw       gleiche Blobs, cm68-Mirror
           │    ├─ mptsas.rom           x86-BIOS 6.36.00.00
           │    ├─ hbaFlash.bat         orig. LSI-DOS-Flash-Skript
           │    ├─ p20_toolkit/         Community-P20-Kit (Skripte+FW)
           │    ├─ SASFlash_Reference_Guide…pdf   offizielle Flag-Referenz
           │    └─ Release-Notes, SHA256SUMS.txt
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

RAID-Volume anlegen: `lsiutil` Option 21 (RAID actions) unter Linux
oder über die UEFI-Setup-Seite des EFI-BSD (falls angezeigt).
Monitoring: `mpt-status` (apt) via `/dev/mptctl`.

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
- Firmware-Forschung 1064/1068E (P21 IT/IR-Blobs, SAS3041ER-Paket):
  https://github.com/cm68/lsi-mpt-large
- P20-Debrand-Toolkit (`SAS1068E_P20_Linux.zip`, Community-Bundle):
  enthalten als `firmware/debrand/p20_toolkit/`; `SASFlash_Reference_
  Guide_v1_2-2008.pdf` = offizielle Flag-Referenz für sasflash 1.24
- UEFI-Shell-Binaries: https://github.com/pbatard/UEFI-Shell

## Hinweise

- Alle Firmware-/Treiberdateien sind **originale LSI/Avago-Releases**
  (bzw. Dumps der eigenen Karte) und dienen Dokumentations-/Recovery-
  Zwecken. Marken gehören den jeweiligen Eigentümern (LSI, Broadcom,
  Fujitsu, IBM, MSI).
- Der EFI-BSD-Treiber ist Baujahr 2011 — das Laden wurde auf einer
  2026er MSI-B550-Aptio-Firmware **verifiziert** (siehe Abschnitt 5).
  Andere Boards können sich anders verhalten; ein abgelehnter Treiber
  lässt die Karte unverändert arbeiten.
- Flashen erfolgt auf eigene Gefahr — immer erst `sasflash -o -uflash`.
- Der SAS-WWID in den Dumps ist eine hardwareeigene Adresse (steht auch
  auf dem Kartenaufkleber), keine Zugangsdaten.
