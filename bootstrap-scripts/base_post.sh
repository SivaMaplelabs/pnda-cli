#!/bin/bash -v

# This script runs on all instances
# - sets the minion ID
# - sets the hostname
# - installs the minion keys and restarts the minion

# The pnda_env-<cluster_name>.sh script generated by the CLI should
# be run prior to running this script to define various environment
# variables

set -e

# The minion_id file is placed onto the minion by saltmaster-gen-keys.sh
# along with the minion.pem and minion.pub keys that it can use
# to register as a minion with that specific ID.
MINION_ID=$(cat minion_id)
cat >> /etc/salt/minion <<EOF
id: $MINION_ID
EOF

echo $MINION_ID > /etc/hostname
hostname $MINION_ID

mkdir -p /etc/salt/pki/minion/

if [ -f minion.pem ]; then
  mv minion.pem /etc/salt/pki/minion/
fi

if [ -f minion.pub ]; then
  mv minion.pub /etc/salt/pki/minion/
fi

service salt-minion restart