#!/bin/bash env

# exit when any command fails
set -e

# Common files
FSTAB="/etc/fstab"
LIGHTTPD="/etc/lighttpd/lighttpd.conf"
PREPAREDIRS="/etc/init.d/prepare-dirs"
BASHOUT="/etc/bash.bash_logout"
TMP="/tmp"

# Commands
SED="/usr/bin/sed"
CAT="/usr/bin/cat"
TOUCH="/usr/bin/touch"
CHMOD="/usr/bin/chmod"
SYSTEMCTL="/usr/bin/systemctl"
UPDATERC="/usr/sbin/update-rc.d"


# Run as ROOT
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root"
    exit
fi

# Modify /etc/fstab
"$SED" -i "s/\\/boot\s\+vfat\s\+.*/\\/boot \t vfat \t defaults,ro \t 0 2/g" "$FSTAB"

# Modify lighttpd.conf
"$SED" -i "s/\"\\/var\\/cache\\/lighttpd\\/uploads\"/\"\\/var\\/log\\/lighttpd\\/uploads\"/g" "$LIGHTTPD"
"$SED" -i "s/\"\\/var\\/cache\\/lighttpd\\/compress\"/\"\\/var\\/log\\/lighttpd\\/compress\"/g" "$LIGHTTPD"

# Create new files
"$TOUCH" "$PREPAREDIRS" "$BASHOUT"

# Change $PREPAREDIRS permissions
"$CHMOD" +x "$PREPAREDIRS"

"$CAT" <<EOT >> "$BASHOUT"
/usr/bin/mount -o remount,ro /
/usr/bin/mount -o remount,ro /boot
EOT

# WA: Boot rapberry on ram: 37&t=63996
"$CAT" <<EOT >> "$PREPAREDIRS"
#!/bin/bash

### BEGIN INIT INFO
# Provides:          prepare-dirs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Required-Start:
# Required-Stop:
# Short-Description: Create /var/log/lighttpd directory on tmpfs at startup
# Description:       Create /var/log/lighttpd directory on tmpfs at startup
### END INIT INFO

# Commands
CHMOD="/usr/bin/chmod"
CHOWN="/usr/bin/chown"
MKDIR="/usr/bin/mkdir"

# Common files
LIGHTDIR="/var/log/lighttpd"
VTMP="/var/tmp"
TMP="/tmp"

case "\${1:-''}" in
  start)
    # Create the /var/log/lighttpd needed by webserver
    \$MKDIR -p \${LIGHTDIR}/{compress,uploads}
    \$CHMOD -R 755 \${LIGHTDIR}
    \$CHMOD 1777 \${TMP} \${VTMP}
    ;;
  stop)
    ;;
  restart)
   ;;
  reload|force-reload)
   ;;
  status)
   ;;
  *)
   echo "Usage: \$SELF start"
   exit 1
   ;;
esac
EOT

# Run Level for repare-dirs
"$UPDATERC" prepare-dirs defaults 01 99

# Reboot in RO mode
echo "Reboot the RaspberryPi to reflect the changes"