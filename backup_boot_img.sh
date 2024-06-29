#!/bin/bash

# Script to backup essential images to recover from bootloop

# Set variables
echo -e "\e[1mPlease enter the name of the directory to back up images into:\e[0m"
# Read input
read dir_name
# Create directory
mkdir "$dir_name"

# Confirm directory is made
if [ -d "$dir_name" ]; then
  echo -e "\e[32mDirectory '$dir_name' created successfully\e[0m"
else
  echo -e "\e[31mFailed to create '$dir_name'. Exiting script.\e[0m"
  exit 1
fi

# Enter directory
cd "$dir_name" || { echo -e "\e[31mFailed to enter directory '$dir_name'. Exiting script.\e[0m"; exit 1; }

echo -e "\e[1mInitializing Android Debug Bridge (ADB) daemon\e[0m"
sleep 2
echo -e "\e[1mChecking for Android platform tools\e[0m"
adb devices

echo -e "\e[32mDevice found in ADB\e[0m"
echo -e "\e[1mLet's continue\e[0m"
sleep 2
echo -e "\e[1mIs your device rooted? (yes/no)\e[0m"
# Read device root status
read root_status

if [ "$root_status" == "yes" ]; then
  echo -e "\e[1mPlease grant root permission to ADB shell\e[0m"
else
  echo -e "\e[31mThis script can only work on a rooted device, sorry\e[0m"
  exit 1
fi

# Enter adb shell and get root access
adb shell su -c "exit"
if [ $? -ne 0 ]; then
  echo -e "\e[31mFailed to get root access on the device. Exiting script.\e[0m"
  exit 1
fi

# Function to backup partitions
backup_partition() {
    local partition=$1
    local output=$2
    adb shell su -c "dd if=/dev/block/by-name/$partition of=/sdcard/$output.img"
    adb pull "/sdcard/$output.img" .
    if [ $? -eq 0 ]; then
        echo -e "\e[32m$partition partition backed up successfully to $output.img in '$dir_name'\e[0m"
    else
        echo -e "\e[31mFailed to back up $partition partition.\e[0m"
    fi
}

# Display options
echo -e "\e[1mPlease enter the partitions you want to back up (comma-separated list):\e[0m"
echo -e "\e[1mFor bootloop protection, 1, 2, and 3 are recommended\e[0m"
sleep 1
echo "1 - boot"
echo "2 - dtbo"
echo "3 - vbmeta"
echo "4 - recovery"
echo "A or a - All"

# Read input
read -p "Your choice: " user_input

# Convert to lowercase
user_input=$(echo "$user_input" | tr 'A-Z' 'a-z')

# Split input into array
IFS=',' read -r -a partitions <<< "$user_input"

# Iterate over the array and back up the selected partitions
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
            echo -e "\e[31mInvalid option: $part\e[0m"
            ;;
    esac
done

echo -e "\e[32mBackup process completed.\e[0m"

# Delete all .img files from /sdcard on the device
adb shell su -c "rm -rf /sdcard/*.img"
if [ $? -eq 0 ]; then
    echo -e "\e[32mAll .img files on /sdcard have been deleted.\e[0m"
else
    echo -e "\e[31mFailed to delete .img files on /sdcard.\e[0m"
fi

echo -e "\e[32mScript finished.\e[0m"

