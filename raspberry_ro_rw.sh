#!/bin/bash env

# Common files
CMDLINE="/boot/cmdline.txt"
DHCPDC5="/etc/systemd/system/dhcpcd5.service"
DHCPRESOLV="/tmp/dhcpcd.resolv.conf"
RESOLFCFG="/etc/resolv.conf"
RANDOMSED="/lib/systemd/system/systemd-random-seed.service"
FSTAB="/etc/fstab"
BASHRC="/etc/bash.bashrc"
TMP="/tmp"

# Commands
ECHO="/usr/bin/echo"
LN="/usr/bin/ln"
RM="/usr/bin/rm"
SED="/usr/bin/sed"
CAT="/usr/bin/cat"
TOUCH="/usr/bin/touch"
CHMOD="/usr/bin/chmod"
CHOWN="/usr/bin/chown"
APT="/usr/bin/apt-get"
DPKG="/usr/bin/dpkg"
SYSTEMCTL="/usr/bin/systemctl"
UPDATERC="/usr/sbin/update-rc.d"
MOUNT="/usr/bin/mount"


# Run as ROOT
if [[ "$EUID" -ne 0 ]]; then
    "$ECHO" "Please run as root"
    exit
fi

# Remove unwanted package and services
# thd: Triggerhappy global hotkey daemon
# logrotate: Rotates, compresses, and mails system logs
# dphys-swapfile: Set up, mount/unmount, and delete an swap file
"$APT" -y remove triggerhappy logrotate dphys-swapfile
"$APT" -y autoremove --purge

# Update repository and get latest packages
# vim: Vi IMproved, a programmer's text editor
# BusyBox: The Swiss Army Knife of Embedded Linux
# resolvconf: A framework for managing multiple DNS configurations
# git: The stupid content tracker
# dnsutils:  This package delivers various client programs related to DNS
"$APT" update
"$APT" -y install vim busybox-syslogd git dnsutils
"$DPKG" --purge rsyslog

# Create new files
"$TOUCH" "$DHCPRESOLV"

# Create symlinks
"$LN" -svf "$TMP"             /var/lib/dhcp
"$LN" -svf "$TMP"             /var/lib/dhcpcd5
"$LN" -svf "$TMP"             /var/run
"$LN" -svf "$TMP"             /var/spool
"$LN" -svf "$TMP"             /var/lock
"$LN" -svf "$TMP"/random-seed /var/lib/systemd/random-seed
"$LN" -svf "$DHCPRESOLV"      "$RESOLFCFG"

# System to mount them read-only
"$CAT" <<EOT >> "$FSTAB"
tmpfs /tmp      tmpfs  defaults,noatime,mode=1777  0 0
tmpfs /var/tmp  tmpfs  defaults,noatime,mode=1777  0 0
tmpfs /var/log  tmpfs  defaults,noatime,mode=0755  0 0
EOT

# Function to switch between RO and RW
"$CAT" <<EOT >> "$BASHRC"
# Set variable identifying the filesystem you work in (used in the prompt below)
set_bash_prompt(){
    fs_mode=\$(mount | sed -n -e "s/^\/dev\/.* on \/ .*(\(r[w|o]\).*/\1/p")
    PS1='\[\033[01;32m\]\u@\h\${fs_mode:+(\$fs_mode)}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
}

alias ro='/usr/bin/sudo /usr/bin/mount -o remount,ro / ; /usr/bin/sudo /usr/bin/mount -o remount,ro /boot'
alias rw='/usr/bin/sudo /usr/bin/mount -o remount,rw / ; /usr/bin/sudo /usr/bin/mount -o remount,rw /boot'
alias ll='/usr/bin/ls -la'

# Setup fancy prompt
PROMPT_COMMAND=set_bash_prompt
EOT

# Disable swap and filesystem check and set it to read-only
"$SED" -i "s/fsck.repair=yes/fsck.repair=no/g" "$CMDLINE"
"$SED" -i "s/rootwait/rootwait fastboot noswap ro/g" "$CMDLINE"

# Change dhcpcd.pid location
#"$SED" -i "s/PIDFile=\\/run\\/dhcpcd.pid/PIDFile=\\/var\\/run\\/dhcpcd.pid/g" "$DHCPDC5"

# Modify /etc/fstab
"$SED" -i "s/\\/\s\+ext4\s\+.*/\\/ \t ext4 \t defaults,noatime,ro \t 0 1/g" "$FSTAB"

# Change random-seed
"$SED" -i "/^RemainAfterExit=yes/a ExecStartPre=\\/usr\\/bin\\/echo \"\" >\\/tmp\\/random-seed" "$RANDOMSED"

# Refresh systemd to inform new changes
"$SYSTEMCTL" daemon-reload
"$MOUNT" -a -v

# Use a temprary DNS for the upgrade
"$ECHO" "nameserver 8.8.8.8" >> "$RESOLFCFG"
"$APT" update --fix-missing
"$APT" -y upgrade

# Reboot in RO mode
"$ECHO" "Reboot the RaspberryPi to reflect the changes"