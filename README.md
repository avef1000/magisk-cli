# magisk-cli
no need to patch your boot images on your phone anymore, just do it on the cli
THIS TOOL WAS MADE POSSIBLE BY USING AND ADAPTING MAGISK TOOLS AND SCRIPTS BY TOPJOHNWU
TOPJOHNWU HAS BEEN MY INSPIRATION FOR EVERYTHING I DO COMPUTER-WISE.

just clone the repository
# git clone https://github.com/avef1000/magisk-cli.git
# cd magisk-cli
# cp /path/to/boot.img .

then run:
# sudo ./Magisk-Cli.sh /path/to/boot.img

simply choose from the menu

1. patch boot.img
2. split boot.img to kernel and ramdisk.cpio
3. patch boot.img with verbose logging
4. exit

it shouldnt take more that 30 seconds.
you will have many ne files, your one is "patched_boot.img"
# EXTRAS
# BACKUP_BOOT_IMG.SH

SIMPLY RUN
# SUDO ./BACKUP_BOOT_IMG.SH
WHAT IT DOES: it works on rooted phones only, it alows you to choose to backup
1. boot.img
2. dtbo.img
3. vbmeta.img
4. recovery.img
essentially it goes into your device in a shell and uses the dd if= of= command to backup
then pulls them out, and then removes and cleans the imgs from your sdcard
