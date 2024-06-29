# magisk-cli
no need to patch your boot images on your phone anymore, just do it on the cli
THIS TOOL WAS MADE POSSIBLE BY USING AND ADAPTING MAGISK TOOLS AND SCRIPTS BY TOPJOHNWU
TOPJOHNWU HAS BEEN MY INSPIRATION FOR EVERYTHING I DO COMPUTERWISE.

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
