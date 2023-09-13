#!/bin/bash

# Config
user='tyra'
vnc_profile='Localhost'
arch_path="/data/archlinux"
sdcard_path="$arch_path/sdcard"
termux_path="$arch_path/termux"
proc_path="$arch_path/proc"
dev_path="$arch_path/dev"
sys_path="$arch_path/sys"
pts_path="$arch_path/dev/pts"
bspwm_path="/home/$user/.config/bspwm/bspwmrc"

# Defaults
no_mount=false
no_umount=false
mount_only=false
umount_only=false
no_kill=false
no_force_kill=false
mount_termux=false
mount_sdcard=false
vnc_server=false
vnc_viewer=false
firefox=false

get_root() {
  if [ "$(id -u)" != 0 ]; then
    sudo sh $(readlink -f "$0") "$@"
    exit
  fi
}

get_args() {
  while [ "$#" -gt 0 ]; do
    key="$1"
    case "$1" in
      -h|--help)
        local path=$(echo "$0" | sed s:$PWD:.:g)
        echo
        echo "Usage: $path [options]"
        echo 'Options:'
        echo '  -n,  --no-mount-umount    Do not mount or unmount directories'
        echo '  -nm, --no-mount           Do not mount on login. Might break stuff'
        echo '  -nu, --no-umount          Do not unmount on logout. Unsafe'
        echo '  -m,  --mount-only         Mount and exit. No chroot session'
        echo '  -u,  --umount-only        Unmount and exit. No chroot session'
        echo '  -nk, --no-kill            Do not kill on logout. Umount can fail'
        echo '  -nK, --no-force-kill      Do not use SIGKILL if SIGTERM fails'
        echo '  -t,  --termux             Add $HOME to the list of dirs to mount'
        echo '  -s,  --sdcard             Add /sdcard to the list of dirs to mount'
        echo '  -vs, --vnc-server         Start VNC server in background'
        echo "  -vv, --vnc-viewer <name>  Start AVNC, profile $vnc_profile + VNC server"
        echo '  -f,  --firefox            Start firefox, VNC viewer and VNC server'
        echo '  -h,  --help               Show this help message and exit'
        echo
        exit 0
        ;;
      -n|--no-mount-umount) no_mount=true; no_umount=true; shift;;
      -nm|--no-mount) no_mount=true; shift;;
      -nu|--no-umount) no_umount=true; shift;;
      -m|--mount-only) mount_only=true; shift;;
      -u|--umount-only) umount_only=true; shift;;
      -nk|--no-kill) no_kill=true; shift;;
      -nK|--no-force-kill) no_force_kill=true; shift;;
      -t|--termux) mount_termux=true; shift;;
      -s|--sdcard) mount_sdcard=true; shift;;
      -vs|--vnc-server) vnc_server=true; shift;;
      -vv|--vnc-viewer) vnc_viewer=true; vnc_server=true; shift
        first_letter=$(echo $1 | grep -o '^.')
        if [ -n "$1" ] && [ "$first_letter" != '-' ]; then
          vnc_profile="$1"; shift
        fi;;
      -f|--firefox) vnc_viewer=true; vnc_server=true; firefox=true; shift;;
      *) local path=$(echo "$0" | sed s:$PWD:.:g)
         echo "\nERROR: Unknown option: $key"
         echo "For more information, use $path --help\n"
         exit 1;;
    esac
  done
}

mount_directory() {
  local source_dir="$1"
  local target_dir="$2"
  local fs_type="$3"
  local options="$4"

  if ! mount | grep -q "$target_dir "; then
    echo "mount: $source_dir > $target_dir"
    [ -d "$target_dir" ] || mkdir -p "$target_dir"
    [ "$fs_type" = bind ] && flag='-o' || flag='-t'
    [ -n "$options" ] && options=",$options"
    mount $flag "${fs_type}${options}" "$source_dir" "$target_dir"
  fi
}

unmount_directory() {
  local dir="$1"

  if mount | grep -q "$dir"; then
    echo "umount: $dir"
    umount "$dir" || touch ~/.cache/umount
  fi
}

mount_all() {
  [ "$no_mount" = true ] && return
  echo
  mount -o remount,dev,suid /data
  mount_directory /dev "$dev_path" bind && \
  mount_directory /dev/pts "$pts_path" bind &
  mount_directory /proc "$proc_path" proc &
  mount_directory /sys "$sys_path" sysfs &
  [ "$mount_sdcard" = true ] && mount_directory /sdcard "$sdcard_path" bind &
  [ "$mount_termux" = true ] && mount_directory /data/data/com.termux/files/home "$termux_path" bind &
  wait
  echo
}

unmount_all() {
  [ "$no_umount" = true ] && return
  echo
  unmount_directory "$pts_path" && sleep 0.1 && \
  unmount_directory "$dev_path" &
  unmount_directory "$proc_path" &
  unmount_directory "$sys_path" &
  unmount_directory "$sdcard_path" &
  unmount_directory "$termux_path" &
  wait
  echo
}

terminate_chroot() {
  [ -f ~/.cache/umount ] && rm -f ~/.cache/umount || exit
  echo 'Failed to unmount some directories.'
  echo "Killing chroot $1."

  [ "$1" = 'forcefully' ] && intensity='-9' || unset intensity

  lsof +d "$arch_path" -F p | tr -d 'p' | \
  while read -r pid; do
    kill $intensity $pid
  done

  sleep 0.5
  unmount_all
}

end_session() {
  sessions=$(ps a | grep "su .*$0" | grep -v 'grep' | wc -l)
  if [ "$sessions" = 1 ]; then
    if pgrep -x Xvnc; then pkill Xvnc; fi
    unmount_all
    [ "$no_kill" = true ] && return
    terminate_chroot gracefully
    [ "$no_force_kill" = true ] && return
    terminate_chroot forcefully
  else
    if [ "$sessions" = 2 ]; then
      echo "Another chroot session is running."
    else
      echo "Another $sessions chroot sessions are running."
    fi
    echo 'Not terminating or unmounting.'
  fi
}

vnc_viewer() {
  while ! pgrep -x Xvnc; do sleep 0.1; done && \
  echo "Launching VNC viewer, profile '$vnc_profile'" >&2 && \
  su -c "
    am force-stop com.gaurav.avnc
    am start \
    -n 'com.gaurav.avnc/.UriReceiverActivity' \
    -a 'android.intent.action.VIEW' \
    -d 'vnc://?ConnectionName=$vnc_profile'
  " &
}

# Init
get_root "$@"
get_args "$@"

set -e
mkdir -p ~/.cache
unset LD_PRELOAD

# Options
if [ "$mount_only" = true ]; then mount_all; exit; fi
if [ "$umount_only" = true ]; then end_session; exit; fi
if [ "$vnc_viewer" = true ]; then
  vnc_viewer >/dev/null &
fi

# Session
mount_all

chroot "$arch_path" bin/bash -c "
  if [ -f '$bspwm_path' ] && [ '$firefox' = true ]; then
    if pgrep -x firefox >/dev/null; then
      echo 'Firefox is already running'
    else
      echo 'Launching Firefox'
      if ! grep -q 'firefox &' '$bspwm_path'; then
        echo 'firefox &' >> '$bspwm_path'
      fi
    fi
  elif [ -f '$bspwm_path' ] && [ '$firefox' != true ]; then
    grep -v 'firefox &' '$bspwm_path' > '$bspwm_path.tmp'
    mv '$bspwm_path.tmp' '$bspwm_path'
  elif  [ ! -f '$bspwm_path' ] && [ '$firefox' = true ]; then
    echo 'ERROR: bspwm is not setup. Cannot launch firefox'
  fi

  if [ -f '$bspwm_path' ]; then
    chmod 755 '$bspwm_path'
    chown '$user:$user' '$bspwm_path'
  fi

  if [ '$vnc_server' = true ]; then
    if pgrep -x Xvnc >/dev/null; then
      echo 'VNC server is already running'
    else
      echo 'Launching VNC server in the background'
      vncsession '$user' :0
    fi
  fi

  cd '/home/$user'
  su '$user'
" && end_session || end_session
