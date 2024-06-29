#!/bin/bash

echo -e "\e[1;36m#################################################################################\e[0m"
echo -e "\e[1;36m#                                                                               #\e[0m"
echo -e "\e[1;36m#                      \e[1;33mMAGISK FOR THE COMMAND LINE\e[0m                 #\e[0m"
echo -e "\e[1;36m#                                                                               #\e[0m"
echo -e "\e[1;36m#                      \e[1;33mADAPTED BY: Avraham Freeman\e[0m                 #\e[0m"
echo -e "\e[1;36m#                     \e[1;33mFROM THE SCRIPTS OF TOPJOHNWU\e[0m                #\e[0m"
echo -e "\e[1;36m#          \e[1;33mUsing the tools of the legendary TOPJOHNWU's MAGISK\e[0m     #\e[0m"
echo -e "\e[1;36m#                                                                               #\e[0m"
echo -e "\e[1;36m#################################################################################\e[0m"
sleep 3
echo ""
echo ""
echo ""
echo -e "\e[1;34m            checking for all required resources, please wait\e[0m"
sleep 1
echo -e "\e[1;34m            please ensure that you run \e[0m\e[1;32m\$ ./magisk-cli.sh boot.img\e[0m"
sleep 1
echo -e "\e[1;34m            please ensure to run this command with sudo or as root\e[0m"
echo -e "\e[1;34m    if you have not, please do ctrl c run with sudo and specify boot.img\e[0m"
sleep 2
echo ""
echo -e "\e[1;34m                  all done lets get this party started!!\e[0m"
sleep 1
echo -e "\e[1;34m start with a quick update\e[0m"
sudo apt update
echo -e "\e[1;35m############\e[0m"
echo -e "\e[1;35m# Functions\e[0m"
echo -e "\e[1;35m############\e[0m"

# Pure bash dirname implementation
getdir() {
  case "$1" in
    */*)
      dir=${1%/*}
      if [ -z $dir ]; then
        echo "/"
      else
        echo $dir
      fi
    ;;
    *) echo "." ;;
  esac
}

# Function to display the menu and read choice
display_menu() {
    echo -e "\e[1;34m======= Magisk CLI Script ========\e[0m"
    echo -e "\e[1;34m1. Patch Boot Image\e[0m"
    echo -e "\e[1;34m2. (only) Split Boot Image\e[0m"
    echo -e "\e[1;34m3. Display Verbose Patching Logs\e[0m"
    echo -e "\e[1;34m4. Exit\e[0m"
    echo -e "\e[1;34m==================================\e[0m"
    read -p "\e[1;32mEnter your choice: \e[0m" choice
    case $choice in
        1) patch_boot_image ;;
        2) split_boot_image ;;
        3) display_verbose ;;
        4) exit 0 ;;
        *) echo -e "\e[1;31mInvalid choice, please select a valid option\e[0m"
           display_menu ;;
    esac
}

echo -e "\e[1;34mdetecting boot.img\e[0m"
# Function to automatically detect or specify boot image
detect_boot_image() {
    if [ $# -eq 0 ]; then
        # No argument provided, use the boot image in current directory
        BOOTIMAGE="./boot.img"
    else
        # Argument provided, use the specified boot image
        BOOTIMAGE="$1"
    fi

    echo -e "\e[1;32mFound! Using image: $BOOTIMAGE\e[0m"

    # Check if boot image file exists
    if [ ! -f "$BOOTIMAGE" ]; then
        echo -e "\e[1;31mError: Boot image file '$BOOTIMAGE' not found.\e[0m"
        exit 1
    fi
}

echo -e "\e[1;34minitializing Magiskboot, the most advanced boot script to exist\e[0m"
sleep 1
# Function to split the boot image
split_boot_image() {
    ui_print "- Unpacking boot image"
    ./magiskboot unpack "$BOOTIMAGE" -v || abort "! Unable to unpack boot image"
    ui_print "- Boot image unpacked successfully"
}

# Function to display verbose patching logs
display_verbose() {
    set -x
    patch_boot_image
    set +x
}

# Function to patch the boot image
patch_boot_image() {
    #################
    # Initialization
    #################
    ui_print "- Loading Helper Utility To Assist In The Boot.img surgery"
    sleep 2
    if [ -z $SOURCEDMODE ]; then
        # Switch to the location of the script file
        cd "$(getdir "${BASH_SOURCE:-$0}")"
        # Load utility functions
        . ./util_functions.sh
        # Check if 64-bit
        api_level_arch_detect
    fi

    detect_boot_image "$@"

    # Dump image for MTD/NAND character device boot partitions
    if [ -c "$BOOTIMAGE" ]; then
        nanddump -f boot.img "$BOOTIMAGE"
        BOOTNAND="$BOOTIMAGE"
        BOOTIMAGE=boot.img
    fi

    # Flags
    [ -z $KEEPVERITY ] && KEEPVERITY=false
    [ -z $KEEPFORCEENCRYPT ] && KEEPFORCEENCRYPT=false
    [ -z $PATCHVBMETAFLAG ] && PATCHVBMETAFLAG=false
    [ -z $RECOVERYMODE ] && RECOVERYMODE=false
    [ -z $LEGACYSAR ] && LEGACYSAR=false
    export KEEPVERITY
    export KEEPFORCEENCRYPT
    export PATCHVBMETAFLAG

    chmod -R 755 .

    #########
    # Unpack
    #########

    CHROMEOS=false
    ui_print "- Initializing magiskboot for unpacking"
    sleep 1
    ui_print "- Unpacking boot image"
    ./magiskboot unpack "$BOOTIMAGE"

    case $? in
        0 ) ;;
        1 )
            abort "! Unsupported/Unknown image format"
            ;;
        2 )
            ui_print "- ChromeOS boot image detected"
            CHROMEOS=true
            ;;
        * )
            abort "! Unable to unpack boot image"
            ;;
    esac

    ###################
    # Ramdisk Restores
    ###################

    # Test patch status and do restore
    ui_print "- Checking ramdisk status"
    if [ -e ramdisk.cpio ]; then
        ./magiskboot cpio ramdisk.cpio test
        STATUS=$?
        SKIP_BACKUP=""
    else
        # Stock A only legacy SAR, or some Android 13 GKIs
        STATUS=0
        SKIP_BACKUP="#"
    fi
    case $((STATUS & 3)) in
        0 )  # Stock boot
            ui_print "- Stock boot image detected"
            SHA1=$(./magiskboot sha1 "$BOOTIMAGE" 2>/dev/null)
            cat $BOOTIMAGE > stock_boot.img
            cp -af ramdisk.cpio ramdisk.cpio.orig 2>/dev/null
            ;;
        1 )  # Magisk patched
            ui_print "- Magisk patched boot image detected"
            ./magiskboot cpio ramdisk.cpio \
            "extract .backup/.magisk config.orig" \
            "restore"
            cp -af ramdisk.cpio ramdisk.cpio.orig
            rm -f stock_boot.img
            ;;
        2 )  # Unsupported
            ui_print "! Boot image patched by unsupported programs"
            abort "! Please restore back to stock boot image"
            ;;
    esac

    # Workaround custom legacy Sony /init -> /(s)bin/init_sony : /init.real setup
    INIT=init
    if [ $((STATUS & 4)) -ne 0 ]; then
        INIT=init.real
    fi

    if [ -f config.orig ]; then
        # Read existing configs
        chmod 0644 config.orig
        SHA1=$(grep_prop SHA1 config.orig)
        if ! $BOOTMODE; then
            # Do not inherit config if not in recovery
            PREINITDEVICE=$(grep_prop PREINITDEVICE config.orig)
        fi
        rm config.orig
    fi

    ##################
    # Ramdisk Patches
    ##################
    ui_print "- Using Magiskboot to patch the ramdisk"
    ui_print "- Patching ramdisk"

    # Compress to save precious ramdisk space
    SKIP32="#"
    SKIP64="#"
    if [ -f magisk64 ]; then
        $BOOTMODE && [ -z "$PREINITDEVICE" ] && PREINITDEVICE=$(./magisk64 --preinit-device)
        ./magiskboot compress=xz magisk64 magisk64.xz
        unset SKIP64
    fi
    if [ -f magisk32 ]; then
        $BOOTMODE && [ -z "$PREINITDEVICE" ] && PREINITDEVICE=$(./magisk32 --preinit-device)
        ./magiskboot compress=xz magisk32 magisk32.xz
        unset SKIP32
    fi
    ./magiskboot compress=xz stub.apk stub.xz

    echo "KEEPVERITY=$KEEPVERITY" > config
    echo "KEEPFORCEENCRYPT=$KEEPFORCEENCRYPT" >> config
    echo "RECOVERYMODE=$RECOVERYMODE" >> config
    if [ -n "$PREINITDEVICE" ]; then
        ui_print "- Pre-init storage partition: $PREINITDEVICE"
        echo "PREINITDEVICE=$PREINITDEVICE" >> config
    fi
    [ -n "$SHA1" ] && echo "SHA1=$SHA1" >> config

    ./magiskboot cpio ramdisk.cpio \
    "add 0750 $INIT magiskinit" \
    "mkdir 0750 overlay.d" \
    "mkdir 0750 overlay.d/sbin" \
    "$SKIP32 add 0644 overlay.d/sbin/magisk32.xz magisk32.xz" \
    "$SKIP64 add 0644 overlay.d/sbin/magisk64.xz magisk64.xz" \
    "add 0644 overlay.d/sbin/stub.xz stub.xz" \
    "patch" \
    "$SKIP_BACKUP backup ramdisk.cpio.orig" \
    "mkdir 000 .backup" \
    "add 000 .backup/.magisk config"

    ########
    # Repack
    ########
    echo " Getting ready to repack the boot.img"
    ui_print "- Repacking boot image"
    ./magiskboot repack "$BOOTIMAGE" || abort "! Unable to repack boot image"
    mv -f new-boot.img patched_boot.img

    # Sign chromeos boot
    if $CHROMEOS; then
        sign_chromeos
    fi

    ui_print "- All done!"
}

echo -e "\e[1;36m##########################################################################\e[0m"
echo -e "\e[1;36m||======================Magisk For The Command Line=====================||\e[0m"
echo -e "\e[1;36m||                                                                        #\e[0m"
echo -e "\e[1;36m||                  \e[1;33mscript by: TOPJOHNWU\e[0m                     #\e[0m"
echo -e "\e[1;36m||             \e[1;33mthe greatest developer of all time!\e[0m           #\e[0m"
echo -e "\e[1;36m||       \e[1;33mAdapted For The Command Line By: Avraham Freeman\e[0m    #\e[0m"
echo -e "\e[1;36m||               \e[1;33mAll Rights Are TOPJOHNWU'S\e[0m                  #\e[0m"
echo -e "\e[1;36m#########################################################################\e[0m"


#############
# Main logic
#############
display_menu
