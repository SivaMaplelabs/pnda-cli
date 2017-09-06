#!/bin/bash -v

# This script runs on all instances
# It installs a salt minion and mounts the disks

# The pnda_env-<cluster_name>.sh script generated by the CLI should
# be run prior to running this script to define various environment
# variables

set -e

DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)

if [ "x$DISTRO" == "xubuntu" ]; then
export DEBIAN_FRONTEND=noninteractive
apt-get -y install xfsprogs salt-minion=2015.8.11+ds-1
elif [ "x$DISTRO" == "xrhel" ]; then
yum -y install xfsprogs wget salt-minion-2015.8.11-1.el7
#enable boot time startup
systemctl enable salt-minion.service
fi

# Mount the log volume, this is always xvdc
if [ -b /dev/xvdc ];
then
   echo "Mounting xvdc for logs"
   umount /dev/xvdc || echo 'not mounted'
   mkfs.xfs -f /dev/xvdc
   mkdir -p /var/log/pnda
   sed -i "/xvdc/d" /etc/fstab
   echo "/dev/xvdc /var/log/pnda auto defaults 0 2" >> /etc/fstab
fi
# Mount the other volumes if they exist, up to 3 more may be mounted but this list could be extended if required
DISKS="xvdd xvde xvdf"
DISK_IDX=0
for DISK in $DISKS; do
   echo $DISK
   if [ -b /dev/$DISK ];
   then
      echo "Mounting $DISK"
      umount /dev/$DISK || echo 'not mounted'
      mkfs.xfs -f /dev/$DISK
      mkdir -p /data$DISK_IDX
      sed -i "/$DISK/d" /etc/fstab
      echo "/dev/$DISK /data$DISK_IDX auto defaults 0 2" >> /etc/fstab
      DISK_IDX=$((DISK_IDX+1))
   fi
done
cat /etc/fstab
mount -a

# Set the master address the minion will register itself with
cat > /etc/salt/minion <<EOF
master: $PNDA_SALTMASTER_IP
beacons:
  kernel_reboot_required:
    interval: $PLATFORM_SALT_BEACON_TIMEOUT
EOF

# Set the grains common to all minions
cat >> /etc/salt/grains <<EOF
pnda:
  flavor: $PNDA_FLAVOR
  is_new_node: True

pnda_cluster: $PNDA_CLUSTER 
EOF

PIP_INDEX_URL="$PNDA_MIRROR/mirror_python/simple"
TRUSTED_HOST=$(echo $PIP_INDEX_URL | awk -F'[/:]' '/http:\/\//{print $4}')
cat << EOF > /etc/pip.conf
[global]
index-url=$PIP_INDEX_URL
trusted-host=$TRUSTED_HOST
extra-index-url=https://pypi.python.org/simple/
EOF
cat << EOF > /root/.pydistutils.cfg
[easy_install]
index_url=$PIP_INDEX_URL
find_links=https://pypi.python.org/simple/
EOF

if [ "x$DISTRO" == "xrhel" ]; then
cat >> /etc/cloud/cloud.cfg <<EOF
preserve_hostname: true
EOF
fi
