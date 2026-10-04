#!/bin/bash
/root/mdcmd status | strings | grep "mdState=STOPPED" >/dev/null 2>&1
if [ $? != 0 ]
then
	echo "Array found STARTED, stop array before proceeding"
	exit
fi
echo -e "\n"
echo "Using 3081E Board, PCIe HBA, Integrated RAID IR firmware with chip B3"
echo -e "\n"
echo "COMMANDLINE THAT WILL BE USED:"
echo "sasflash -l Flashlog.txt -o -f 3081ERB3.fw -b MPTSAS.ROM"
echo -e "\n"
read -p "Press Enter key to start, or CTRL-C to quit."
echo -e "\n"
echo "Proceeding to Flash and Log too FlashLog.txt"
echo "in the current directory"
echo -e "\n"
sasflash -l FlashLog.txt -o -f 3081ERB3.fw -b MPTSAS.ROM
