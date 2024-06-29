#!/bin/bash

# script to backup essential images to recover from bootloop
#set variables
echo "Please enter the name of the directory to back up images into:"
# read input
read dir_name
#create directory
mkdir "$dir_name"

# confirm directory is made
if [ -d "$dir_name" ]; then
  echo "Directory '$dir_name' created successfully"
else
  echo "Failed to create '$dir_name'. Exiting script."
  exit 1
fi

# enter directory
cd "$dir_name" || { echo "Failed to enter directory '$dir_name'. Exiting script."; exit 1; }

echo "Initializing Android Debug Bridge (ADB) daemon"
sleep 2
echo "Checking for Android platform tools"
adb devices

echo "Device found in ADB"
echo "Let's continue"
sleep 2
echo "Is your device rooted? (yes/no)"
# read device root status
read root_status

if [ "$root_status" == "yes" ]; then
  echo "Please grant root permission to ADB shell"
else
  echo "This script can only work on a rooted device, sorry"
  exit 1
fi

# enter adb shell and get root access
adb shell su -c "exit"
if [ $? -ne 0 ]; then
  echo "Failed to get root access on the device. Exiting script."
  exit 1
fi

# function to backup partitions
backup_partition() { 
    local partition=$1
    local output=$2
    adb shell su -c "dd if=/dev/block/by-name/$partition of=/sdcard/$output.img"
    adb pull "/sdcard/$output.img" .
    if [ $? -eq 0 ]; then
        echo "$partition partition backed up successfully to $output.img in '$dir_name'"
    else 
        echo "Failed to back up $partition partition."
    fi
}

# display options
echo "Please enter the partitions you want to back up (comma-separated list):"
echo "For bootloop protection, 1, 2, and 3 are recommended"
sleep 1
echo "1 - boot"
echo "2 - dtbo"
echo "3 - vbmeta"
echo "4 - recovery"
echo "A or a - All"

# read input
read -p "Your choice: " user_input

# convert to lowercase
user_input=$(echo "$user_input" | tr 'A-Z' 'a-z')

# split input into array
IFS=',' read -r -a partitions <<< "$user_input"

# iterate over the array and back up the selected partitions
for part in "${partitions[@]}"; do
    case "$part" in
        1)
            backup_partition "boot" "boot"
            ;;
        2)
            backup_partition "dtbo" "dtbo"
            ;;
        3)
            backup_partition "vbmeta" "vbmeta"
            ;;
        4)
            backup_partition "recovery" "recovery"
            ;;
        a)
            backup_partition "boot" "boot"
            backup_partition "dtbo" "dtbo"
            backup_partition "vbmeta" "vbmeta"
            backup_partition "recovery" "recovery"
            break
            ;;
        *)
            echo "Invalid option: $part"
            ;;
    esac
done

echo "Backup process completed."

# delete all .img files from /sdcard on the device
adb shell su -c "rm -rf /sdcard/*.img"
if [ $? -eq 0 ]; then
    echo "All .img files on /sdcard have been deleted."
else
    echo "Failed to delete .img files on /sdcard."
fi

echo "Script finished."
