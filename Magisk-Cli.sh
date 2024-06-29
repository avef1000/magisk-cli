#!/bin/bash
echo "#################################################################################"
echo "#                                                                               #"
echo "#                      MAGISK FOR THE COMMAND LINE                              #"
echo "#                                                                               #"
echo "#                      ADAPTED BY: Avraham Freeman                              #"
echo "#                     FROM THE SCRIPTS OF TOPJOHNWU                              #"
echo "#          Using the tools of the legendary TOPJOHNWU's MAGISK                  #"
echo "#                                                                               #"
echo "#################################################################################"
sleep 3
echo ""
echo ""
echo ""
echo "            checking for all required resources, please wait"
sleep 1
echo "            please ensure that you run $ ./magisk-cli.sh boot.img"
sleep 1
echo "            please ensure to run this command with sudo or as root"
echo "    if you have not, please do ctrl c run with sudo and specify boot.img"
sleep 2
echo ""
echo "                  all done lets get this party started!!"
sleep 1
echo " start with a quick update"
sudo apt update
############
# Functions
############

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
    echo "======= Magisk CLI Script ========"
    echo "1. Patch Boot Image"
    echo "2. (only) Split Boot Image"
    echo "3. Display Verbose Patching Logs"
    echo "4. Exit"
    echo "=================================="
    read -p "Enter your choice: " choice
    case $choice in
        1) patch_boot_image ;;
        2) split_boot_image ;;
        3) display_verbose ;;
        4) exit 0 ;;
        *) echo "Invalid choice, please select a valid option"
           display_menu ;;
    esac
}

echo "detecting boot.img"
# Function to automatically detect or specify boot image
detect_boot_image() {
    if [ $# -eq 0 ]; then
        # No argument provided, use the boot image in current directory
        BOOTIMAGE="./boot.img"
    else
        # Argument provided, use the specified boot image
        BOOTIMAGE="$1"
    fi

    echo "Found! Using image: $BOOTIMAGE"

    # Check if boot image file exists
    if [ ! -f "$BOOTIMAGE" ]; then
        echo "Error: Boot image file '$BOOTIMAGE' not found."
        exit 1
    fi
}

echo  "initializing Magiskboot, the most advanced boot script to exist" 
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

echo "##########################################################################"
echo "||======================Magisk For The Command Line=====================||"
echo "||                                                                      #"
echo "||                  script by: TOPJOHNWU                                #"
echo "||             the greatest developer of all time!                      #"
echo "||       Adapted For The Command Line By: Avraham Freeman               #"
echo "||               All Rights Are TOPJOHNWU'S                             #"
echo "#########################################################################"


#############
# Main logic
#############
display_menu
