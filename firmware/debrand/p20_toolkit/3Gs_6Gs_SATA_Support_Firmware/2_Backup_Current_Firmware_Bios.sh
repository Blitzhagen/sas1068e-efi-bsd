#!/bin/bash
/root/mdcmd status | strings | grep "mdState=STOPPED" >/dev/null 2>&1
if [ $? != 0 ]
then
	echo "Array found STARTED, stop array before proceeding"
	exit
fi
echo -e "\n"
echo "Your existing firmware will be saved as 1068E-FW-Backup.fw"
echo "Your existing BIOS will be saved as     1068E-Backup-BIOS.rom"
echo "in the current directory"
echo -e "\n"
read -p "Press Enter key to start, or CTRL-C to quit."
echo -e "\n"
echo "Saving old firmware and BIOS"
echo -e "\n"
sasflash -ufirmware 1068E-FW-Backup.fw
sasflash -ubios 1068E-Backup-BIOS.rom
