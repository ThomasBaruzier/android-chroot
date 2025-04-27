# Android Chroot Script

## Disclaimer:
```
/*
* Your warranty is now void.
*
* I am not responsible for bricked devices, dead SD cards,
* thermonuclear war, or the current economic crisis caused by you following
* these directions. YOU are choosing to make these modifications, and if
* you point your finger at me for messing up your device, I will laugh at you.
*/
```
This script uses root capabilities to be able to run. Please read this ENTIRE readme to limit the risk of harming your device, or even brick it. I really encourage you to use this tool with care, as I almost bricked my device and wiped all my data while developing it. Please see #Limitations/UNSAFE for further details.

## Description:
The Android Chroot Script is a powerful tool that enables you to run a chrooted Linux distribution on your Android device. It provides a convenient way to access and utilize various Linux applications and tools on your Android device, enhancing its functionality and versatility. This script automates the process of setting up and managing the chroot environment, allowing you to make the most out of your Android device's capabilities.

## Features:
1. **Chroot Environment**: The script sets up a chroot environment, isolating the Linux distribution from your Android system, ensuring an independent environment for running Linux applications.

2. **Mounting and Unmounting**: The script provides options to mount and unmount specific directories within the chroot environment, allowing seamless access to the Android system (/sys, /dev, /dev/pts and /proc) and the user's directories. This includes the user storage (/storage/emulated/0) and the Termux home directory (/data/data/com.termux/files/home).

3. **VNC Server and Viewer**: The script includes functionality to start a VNC server in the background, enabling remote desktop access to the chrooted Linux distribution. It also offers an option to launch a VNC viewer to connect to the VNC server with customizable profiles.

4. **Firefox Integration**: The script supports launching Firefox within the chroot environment using the bspwmrc configuration file.

5. **Graceful Termination**: The script ensures a graceful termination of the chroot session by unmounting directories and killing processes associated with the chroot environment. It offers options for forceful termination if necessary.

6. **Multiple sessions**: Before terminating and unmounting the chroot session upon shell exit, the script checks for any other parallel chroot session. If one or more are found, the current session will exit without impacting the state of the other concurrent sessions.

## Limitations:
1. **UNSAFE**: Even though the chroot script logs into a non-su account, any abuse or risky behavior can and will impact your Android device. To limit risks, do not mount the system directories using the option `--no-mount`. Remember that the parent process of the session is root, which means that the ressource usage priority will be equal to the Android system itself, and will be prioritized over any user process. For instance, launching a program that exceeds the RAM capabilities of your Android device will result in a freeze and crash of the system, including the screen itself. Only the 10 second poweroff button can save you in such a case.</br></br>
Also, here is a stupid mistake I made that you should avoid: I tried to "sudo rm -rf" the linux distribution folder itself with /sdcard, /data/data/com.termux/files/home, /sys, /dev, /dev/pts and /proc mounted. That made my device crash so hard that the command wasn't able to complete, or at least that's what I believe. Just after entering this command, my screen froze and I realized my mistake. I crushed the power button as hard as I can, only to expect the next reboot to not complete, even though it miraculously did with no data loss.

2. **Manual Setup**: This script is NOT a ONE-CLICK solution. You will have to configure and dig stuff by yourself. You will need and use some Linux knowledge. If you don't, don't go further. ChatGPT will not unbrick your device.

3. **Compatibility**: The script's compatibility may vary depending on the Android device and the Linux distribution used. This script was tested on a Mi 11 Ultra and a Mi 9T Pro, running Miui 14 EU ROM and LineageOS 20, both based on Android 13 and rooted with Magisk. The Linux distribution used is Arch Linux ARM and was configured to specifically run with chroot capabilities in mind. More on that later.

4. **Root Access**: The script requires root access in Termux or any other terminal emulator on the Android device, in order to use the chroot command in the first place.

5. **Resource Requirements**: Running a chrooted Linux distribution on an Android device may require significant system resources, including storage space, RAM, and CPU power.

## Getting Started:
In this tutorial, we are going to use Arch Linux ARM. To use any other distribution, additionnal configuration and script editing is required.

1. Read the `Disclaimer` and the `Limitations` section above if not already.

2. Do not skip step 1.

3. Never copy and paste any of the following commands blindly. Please.

4. Ensure your Android device is rooted. Don't go further if you don't have any idea of how this can be done. For those who don't care about potentially breaking their device, search how to unlock your device's bootloader, and then flash Magisk after following every wiki or guide related to these subjects. Again, I am not responsible if this fails.

5. Download Termux, install git, clone this repo.
```
apt update -y && apt upgrade -y && apt install git wget nano sudo -y
git clone https://github.com/ThomasBaruzier/android-chroot ~/chroot
cd ~/chroot
chmod +x chroot.sh
```

6. Download the Arch Linux ARM distribution tarball. This is for ARMv8/aarch64 ONLY. Here is the official website: [https://archlinuxarm.org/platforms/armv8/generic](https://archlinuxarm.org/platforms/armv8/generic)
```
wget -c http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
```

7. Extract it under /data/archlinux
```
sudo mkdir -p /data/archlinux/
sudo tar xf ArchLinuxARM-aarch64-latest.tar.gz -C /data/archlinux/
```

8. Modify /data/archlinux/etc/bash.bashrc. Add the following code.
```
sudo nano /data/archlinux/etc/bash.bashrc
```
```
if [ "$(id -u)" != 0 ]; then
    HOME="/home/$(whoami)"
    cd
else
    HOME='/root'
fi

LD_PRELOAD=''
TMPDIR='/tmp'
PREFIX='/usr'
HISTFILE="$HOME/.bash_history"
PATH='/system/bin:/system/xbin:/sbin:/sbin/bin'
```

9. Setup and configure the distribution (basic setup).
```
# Enter chroot
./chroot.sh --mount-only
LD_PRELOAD='' sudo chroot /data/archlinux bash

# Setup DNS (Use any DNS you like)
rm -f /etc/resolv.conf
echo 'nameserver 9.9.9.9' > /etc/resolv.conf
curl ip.3z.ee # check internet access

# Setup pacman and packages
pacman-key --init
pacman-key --populate
nano /etc/pacman.conf # disable `CheckSpace`, enable `Color` and `ParallelDownloads`
pacman -R linux-aarch64 linux-firmware linux-firmware-whence openssh net-tools # remove optional packages
pacman -Syu # run this command a few times if packages sync fails
pacman -Sc --noconfirm # remove cache to save space

# Setup users and sudo. Please modify the `user` value accordingly in chroot.sh
userdel --remove alarm
useradd -m <user>
usermod -aG wheel <user>
passwd root
passwd <user>
pacman -S sudo
EDITOR=nano visudo # uncomment `%wheel ALL=(ALL:ALL) NOPASSWD: ALL`

# Basic arch install wiki steps
ln -sf /usr/share/zoneinfo/<Region>/<City> /etc/localtime
nano /etc/locale.gen # uncomment 'en_US.UTF-8 UTF-8' or another locale
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
nano /etc/hostname # set the hostname of your choice

# Exit
exit
./chroot.sh --umount-only
```

10. If everything worked as expected, you can try using the script for the first time.
```
./chroot.sh
```
Warning: It is possible that the script kills itself while using the chroot session. In that case, the chroot session will not be terminated and unmounted correctly. To fix this issue, use `./chroot.sh --umount-only`

11. The system should be around 630MB. Get my bashrc and execute clean() to save around 100MB
```
# In chroot:
curl -L 3z.ee/bashrc > ~/.bashrc
source ~/.bashrc
clean
```
Note: You can remove my bashrc after this if you don't like it

12. Build fakeroot with tcp ipc (dependency for yay)
```
# In chroot:
pacman -S base-devel --needed --noconfirm
pacman -Rdd fakeroot --noconfirm
curl -Os http://ftp.debian.org/debian/pool/main/f/fakeroot/fakeroot_1.37.orig.tar.gz
tar xvf fakeroot_1.37.orig.tar.gz
cd fakeroot-1.37/
./bootstrap
./configure --prefix=/opt/fakeroot --libdir=/opt/fakeroot/libs --disable-static --with-ipc=tcp
make
sudo make install
sudo ln -s /opt/fakeroot/bin/fakeroot /bin/fakeroot
fakeroot # For testing
exit
cd ..
rm -rf fakeroot-1.37 fakeroot_1.37.orig.tar.gz
```

13. Install yay, a popular package manager for the AUR
```
# In chroot:
pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si
cd ..
rm -rf yay-bin
```

14. Setup the VNC server and viewer, bspwm, sxhkd, and firefox.
```
<TODO>
```
