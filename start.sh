#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

print_status() {
    echo
    echo "## $1"
    echo
}

if [ $# -ne 1 ]; then
    echo "Execution format ./start.sh nodename "
    exit
fi
nodename=$1
zen_node_name=${nodename}
zen_secnodetracker_name=${nodename}-secnodetracker

print_status "Enabling and starting container services..."
systemctl enable ${zen_node_name}
systemctl restart ${zen_node_name}

systemctl enable ${zen_secnodetracker_name}
systemctl restart ${zen_secnodetracker_name}

print_status "Waiting for node to fetch params ..."
until docker exec -it ${zen_node_name} /usr/local/bin/gosu user zen-cli getinfo
do
  echo ".."
  sleep 30
done

if [[ $(docker exec -it ${zen_node_name} /usr/local/bin/gosu user zen-cli z_listaddresses | wc -l) -eq 2 ]]; then
  print_status "Generating shield address for node... you will need to send 1 ZEN to this address:"
  docker exec -it ${zen_node_name} /usr/local/bin/gosu user zen-cli z_getnewaddress

  print_status "Restarting secnodetracker"
  systemctl restart ${zen_secnodetracker_name}
else
  print_status "Node already has shield address... you will need to send 1 ZEN to this address:"
  docker exec -it ${zen_node_name} /usr/local/bin/gosu user zen-cli z_listaddresses
fi

print_status "Install Finished"
echo "Please wait until the blocks are up to date..."

