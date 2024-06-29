############################################
# Magisk General Utility Functions
############################################

MAGISK_VER='27.0'
MAGISK_VER_CODE=27000

###################
# Global Variables
###################

# True if the script is running on booted Android, not something like recovery
# BOOTMODE=

# The path to store temporary files that don't need to persist
# TMPDIR=

# The path to store files that can be persisted (non-volatile storage)
# Any modification to this variable should go through the function `set_nvbase`
# NVBASE=

# The non-volatile path where magisk executables are stored
# MAGISKBIN=

###################
# Helper Functions
###################

ui_print() {
  if $BOOTMODE; then
    echo "$1"
  else
    echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD
  fi
}

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

grep_cmdline() {
  local REGEX="s/^$1=//p"
  { echo $(cat /proc/cmdline)$(sed -e 's/[^"]//g' -e 's/""//g' /proc/cmdline) | xargs -n 1; \
    sed -e 's/ = /=/g' -e 's/, /,/g' -e 's/"//g' /proc/bootconfig; \
  } 2>/dev/null | sed -n "$REGEX"
}

grep_prop() {
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  cat $FILES 2>/dev/null | dos2unix | sed -n "$REGEX" | head -n 1
}

grep_get_prop() {
  local result=$(grep_prop $@)
  if [ -z "$result" ]; then
    # Fallback to getprop
    getprop "$1"
  else
    echo $result
  fi
}

getvar() {
  local VARNAME=$1
  local VALUE
  local PROPPATH='/data/.magisk /cache/.magisk'
  [ ! -z $MAGISKTMP ] && PROPPATH="$MAGISKTMP/.magisk/config $PROPPATH"
  VALUE=$(grep_prop $VARNAME $PROPPATH)
  [ ! -z $VALUE ] && eval $VARNAME=\$VALUE
}

is_mounted() {
  grep -q " $(readlink -f $1) " /proc/mounts 2>/dev/null
  return $?
}

abort() {
  ui_print "$1"
  $BOOTMODE || recovery_cleanup
  [ ! -z $MODPATH ] && rm -rf $MODPATH
  rm -rf $TMPDIR
  exit 1
}

set_nvbase() {
  NVBASE="$1"
  MAGISKBIN="$1/magisk"
}

print_title() {
  local len line1len line2len bar
  line1len=$(echo -n $1 | wc -c)
  line2len=$(echo -n $2 | wc -c)
  len=$line2len
  [ $line1len -gt $line2len ] && len=$line1len
  len=$((len + 2))
  bar=$(printf "%${len}s" | tr ' ' '*')
  ui_print "$bar"
  ui_print " $1 "
  [ "$2" ] && ui_print " $2 "
  ui_print "$bar"
}

######################
# Environment Related
######################

setup_flashable() {
  ensure_bb
  $BOOTMODE && return
  if [ -z $OUTFD ] || readlink /proc/$$/fd/$OUTFD | grep -q /tmp; then
    # We will have to manually find out OUTFD
    for FD in $(ls /proc/$$/fd); do
      if readlink /proc/$$/fd/$FD | grep -q pipe; then
        if ps | grep -v grep | grep -qE " 3 $FD |status_fd=$FD"; then
          OUTFD=$FD
          break
        fi
      fi
    done
  fi
  recovery_actions
}

ensure_bb() {
  if set -o | grep -q standalone; then
    # We are definitely in busybox ash
    set -o standalone
    return
  fi

  # Find our busybox binary
  local bb
  if [ -f $TMPDIR/busybox ]; then
    bb=$TMPDIR/busybox
  elif [ -f $MAGISKBIN/busybox ]; then
    bb=$MAGISKBIN/busybox
  else
    abort "! Cannot find BusyBox"
  fi
  chmod 755 $bb

  # Busybox could be a script, make sure /system/bin/sh exists
  if [ ! -f /system/bin/sh ]; then
    umount -l /system 2>/dev/null
    mkdir -p /system/bin
    ln -s $(command -v sh) /system/bin/sh
  fi

  export ASH_STANDALONE=1

  # Find our current arguments
  # Run in busybox environment to ensure consistent results
  # /proc/<pid>/cmdline shall be <interpreter> <script> <arguments...>
  local cmds="$($bb sh -c "
  for arg in \$(tr '\0' '\n' < /proc/$$/cmdline); do
    if [ -z \"\$cmds\" ]; then
      # Skip the first argument as we want to change the interpreter
      cmds=\"sh\"
    else
      cmds=\"\$cmds '\$arg'\"
    fi
  done
  echo \$cmds")"

  # Re-exec our script
  echo $cmds | $bb xargs $bb
  exit
}

recovery_actions() {
  # Make sure random won't get blocked
  mount -o bind /dev/urandom /dev/random
  # Unset library paths
  OLD_LD_LIB=$LD_LIBRARY_PATH
  OLD_LD_PRE=$LD_PRELOAD
  OLD_LD_CFG=$LD_CONFIG_FILE
  unset LD_LIBRARY_PATH
  unset LD_PRELOAD
  unset LD_CONFIG_FILE
}

recovery_cleanup() {
  local DIR
  ui_print "- Unmounting partitions"
  (
  if [ ! -d /postinstall/tmp ]; then
    umount -l /system
    umount -l /system_root
  fi
  umount -l /vendor
  umount -l /persist
  umount -l /metadata
  for DIR in /apex /system /system_root; do
    if [ -L "${DIR}_link" ]; then
      rmdir $DIR
      mv -f ${DIR}_link $DIR
    fi
  done
  umount -l /dev/random
  ) 2>/dev/null
  [ -z $OLD_LD_LIB ] || export LD_LIBRARY_PATH=$OLD_LD_LIB
  [ -z $OLD_LD_PRE ] || export LD_PRELOAD=$OLD_LD_PRE
  [ -z $OLD_LD_CFG ] || export LD_CONFIG_FILE=$OLD_LD_CFG
}

#######################
# Installation Related
#######################

# find_block [partname...]
find_block() {
  local BLOCK DEV DEVICE DEVNAME PARTNAME UEVENT
  for BLOCK in "$@"; do
    DEVICE=$(find /dev/block \( -type b -o -type c -o -type l \) -iname $BLOCK | head -n 1) 2>/dev/null
    if [ ! -z $DEVICE ]; then
      readlink -f $DEVICE
      return 0
    fi
  done
  # Fallback by parsing sysfs uevents
  for UEVENT in /sys/dev/block/*/uevent; do
    DEVNAME=$(grep_prop DEVNAME $UEVENT)
    PARTNAME=$(grep_prop PARTNAME $UEVENT)
    for BLOCK in "$@"; do
      if [ "$(toupper $BLOCK)" = "$(toupper $PARTNAME)" ]; then
        echo /dev/block/$DEVNAME
        return 0
      fi
    done
  done
  # Look just in /dev in case we're dealing with MTD/NAND without /dev/block devices/links
  for DEV in "$@"; do
    DEVICE=$(find /dev \( -type b -o -type c -o -type l \) -maxdepth 1 -iname $DEV | head -n 1) 2>/dev/null
    if [ ! -z $DEVICE ]; then
      readlink -f $DEVICE
      return 0
    fi
  done
  return 1
}

# setup_mntpoint <mountpoint>
setup_mntpoint() {
  local POINT=$1
  [ -L $POINT ] && mv -f $POINT ${POINT}_link
  if [ ! -d $POINT ]; then
    rm -f $POINT
    mkdir -p $POINT
  fi
}

# mount_name <partname(s)> <mountpoint> <flag>
mount_name() {
  local PART=$1
  local POINT=$2
  local FLAG=$3
  setup_mntpoint $POINT
  is_mounted $POINT && return
  # First try mounting with fstab
  mount $FLAG $POINT 2>/dev/null
  is_mounted $POINT && return
  # Fallback to searching by name
  mount -o $FLAG $(find_block $PART) $POINT 2>/dev/null
  is_mounted $POINT
}

# mount_ro <partname(s)> <mountpoint>
mount_ro() {
  mount_name "$1" "$2" "-o ro"
}

# mount_rw <partname(s)> <mountpoint>
mount_rw() {
  mount_name "$1" "$2" "-o rw"
}

# umount_recursive <mountpoint>
umount_recursive() {
  local MOUNTPOINT=$1
  grep -qs " $MOUNTPOINT " /proc/mounts && umount -l $MOUNTPOINT
}

#######################
# Android Related
#######################

get_prop() {
  local PROP=$1
  grep_get_prop $PROP /system/build.prop /system/system/build.prop
}

set_perm() {
  local TARGET=$1
  local UID=$2
  local GID=$3
  local MODE=$4
  chown $UID:$GID $TARGET
  chmod $MODE $TARGET
}

#######################
# Magisk Related
#######################

# is_magisk_mounted
is_magisk_mounted() {
  is_mounted /sbin/.core/mirror
}

# remove_magisk_files
remove_magisk_files() {
  rm -rf /sbin/.core /sbin/.magisk /sbin/magisk /data/adb/magisk.db
}

# is_arch_supported <arch>
is_arch_supported() {
  local ARCH=$1
  case $ARCH in
    arm|arm64|x86|x64)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# install_busybox <path>
install_busybox() {
  local BBPATH=$1
  mkdir -p $BBPATH
  # Extract busybox
  unzip -o -q $MAGISKTMP/busybox.zip -d $BBPATH
  chmod 755 $BBPATH/busybox
}

# cleanup_magisk_tmp
cleanup_magisk_tmp() {
  rm -rf $MAGISKTMP
}

#######################
# Module Related
#######################

# copy_files <src> <dst>
copy_files() {
  local SRC=$1
  local DST=$2
  cp -af $SRC $DST
}

# set_perm_recursive <path> <uid> <gid> <dmode> <fmode>
set_perm_recursive() {
  local PATH=$1
  local UID=$2
  local GID=$3
  local DMODE=$4
  local FMODE=$5
  local DIR FILE
  chmod $DMODE $PATH
  chown $UID:$GID $PATH
  for DIR in $(find $PATH -type d 2>/dev/null); do
    chmod $DMODE $DIR
    chown $UID:$GID $DIR
  done
  for FILE in $(find $PATH -type f 2>/dev/null); do
    chmod $FMODE $FILE
    chown $UID:$GID $FILE
  done
}

# set_metadata_recursive <path> <uid> <gid> <dmode> <fmode>
set_metadata_recursive() {
  local PATH=$1
  local UID=$2
  local GID=$3
  local DMODE=$4
  local FMODE=$5
  local DIR FILE
  for DIR in $(find $PATH -type d 2>/dev/null); do
    chmod $DMODE $DIR
    chown $UID:$GID $DIR
  done
  for FILE in $(find $PATH -type f 2>/dev/null); do
    chmod $FMODE $FILE
    chown $UID:$GID $FILE
  done
}

#######################
# Validation
#######################

# magisk_version_check <min_version>
magisk_version_check() {
  local MIN_VER=$1
  local CUR_VER=$MAGISK_VER_CODE
  if [ $CUR_VER -lt $MIN_VER ]; then
    abort "! This module requires Magisk version $MIN_VER or higher."
  fi
}

# architecture_check <arch>
architecture_check() {
  local ARCH=$1
  if ! is_arch_supported $ARCH; then
    abort "! Unsupported architecture: $ARCH"
  fi
}

#######################
# Entry Point
#######################

# Start main logic
main() {
  echo "Starting main logic..."
  # Example code to use functions
  ui_print "Example script started."
}

# Initialize
main "$@"
