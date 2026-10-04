@echo off
cls
echo .
echo .     Welcome to LSI Logic Integrated SAS Flash Utility
echo .     This Utility will upgrade your LSI SAS HBA 
echo.
echo.
REM     ========================================================
REM         Start procedure to save old firmware and BIOS

echo            !!!             WARNING              !!!
echo            !!! LSI strongly recommends you save !!!
echo            !!!  the existing firmware and BIOS  !!!
echo            !!!    currently installed on your   !!!
echo            !!!          SAS Controller          !!!
echo.
echo.
echo .     Your existing firmware will be saved as Firmware.fw
echo .     Your existing BIOS will be saved as     BIOS.rom
echo .     in the current directory
echo.

CHOICE /N                    press y or n     (yes or no)
REM Errollevel 1 = Save old firmware and BIOS
REM Errorlevel 2 = Don't save old firmware and BIOS
IF errorlevel 2 goto BoardType    
IF errorlevel 1 echo yes

:SaveOld
echo.
echo .     Saving old firmware and BIOS
echo.
sasflash -ufirmware Firmware.fw
sasflash -ubios BIOS.rom

:BoardType

REM             End procedure to save old firmware and BIOS
REM     ==========================================================

echo .    TO FLASH  3080     press  1
echo .    TO FLASH  3081     press  2
echo .    TO FLASH  3800     press  3
echo .    TO FLASH  3801     press  4
echo .    TO FLASH  3442     press  5
echo .    TO FLASH  3041     press  6
echo .    TO FLASH  3444     press  7
echo .    TO FLASH  31601    press  8
echo.
echo .    TO EXIT press 9
echo .

CHOICE /N /C:123456789       press 1 to 9
IF errorlevel 9 goto exit
IF errorlevel 8 goto 31601
IF errorlevel 7 goto 3444
IF errorlevel 6 goto 3041
IF errorlevel 5 goto 3442
IF errorlevel 4 goto 3801
IF errorlevel 3 goto 3800
IF errorlevel 2 goto 3081
IF errorlevel 1 goto 3080
:3080 
set board=3080
goto skip1
:3081 
set board=3081
goto skip1
:3800 
set board=3800
goto skip1
:3801 
set board=3801
goto skip1
:3442 
set board=3442
goto skip1
:3041 
set board=3041
goto skip1
:3444 
set board=3444
goto skip1
:31601 
set board=1601

:skip1
echo.
echo.
echo .    The HBA is PCI-X or PCIe
echo .    For PCI-X press  X or x
echo .    For PCIe  press  E or e
echo.
echo .    To Exit press    Q or q
echo .

CHOICE /N /C:exq       press X, E or Q
IF errorlevel 3 GOTO EXIT
IF errorlevel 2 goto pcix
IF errorlevel 1 goto pcie
:pcix 
set pci=X
goto skip2
:pcie 
set pci=E

:skip2
IF %board%==3800 goto IT
IF %board%==3801 goto IT
IF %board%==31601 goto IT
echo.
echo.
echo.     IR or IT Firmware
echo.
echo .    For Integrated RAID (IR) press   R or r
echo .    For Initator-Target (IT) press   T or t
echo.
echo .    TO EXIT press   q
echo .

CHOICE /N /C:rtq       press R, T or q
IF errorlevel 3 GOTO EXIT
IF errorlevel 2 goto IT
IF errorlevel 1 set fw=R
goto skip3

:it 
set fw=T

:skip3
sasflash -listall
echo.     Which Chip Version?
echo .    For A3  press  1
echo .    For A4  press  2
echo .    For B0  press  3
echo .    For B1  press  4
echo .    For B2  press  5
echo .    For B3  press  6
echo.
echo .    To Exit press  7
echo .

CHOICE /N /C:1234567       press 1 to 6 (or 7 to quit)
IF errorlevel 7 goto EXIT
IF errorlevel 6 goto chipb3
IF errorlevel 5 goto chipb2
IF errorlevel 4 goto chipb1
IF errorlevel 3 goto chipb0
IF errorlevel 2 goto chipa4
IF errorlevel 1 goto chipa3
:chipb3
set ver=B3
goto skip4
:chipb2
set ver=B2
goto skip4
:chipb1
set ver=B1
goto skip4
:chipb0
set ver=B0
goto skip4
:chipa4
set ver=A4
goto skip4
:chipa3
set ver=A3

:skip4
set name=%board%%pci%%fw%%ver%.fw
echo.
echo.
echo .  You have slected %board%%pci% I%fw% firmware with chip %ver%
echo.
echo    sasflash -f %name% -b MPTSAS.ROM
echo.
echo .    OK to Flash  press  F or f
echo.
echo .    TO EXIT press       q
echo .

CHOICE /N /C:fq       press F or q
IF errorlevel 2 GOTO EXIT
IF errorlevel 1 GOTO flash

:flash
sasflash -o -f %name% -b MPTSAS.ROM

:EXIT