#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

print_status() {
    echo
    echo "## $1"
    echo
}

if [ $# -ne 1 ]; then
    echo "Execution format ./stop.sh nodename "
    exit
fi
nodename=$1
zen_node_name=${nodename}
zen_secnodetracker_name=${nodename}-secnodetracker

print_status "Disabling and stopping container services..."
systemctl disable ${zen_secnodetracker_name}
systemctl stop ${zen_secnodetracker_name}

systemctl disable ${zen_node_name}
systemctl stop ${zen_node_name}


