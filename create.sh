#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

print_status() {
    echo
    echo "## $1"
    echo
}

if [ $# -ne 3 ]; then
    echo "Execution format ./install.sh stakeaddr hostname network(0/1)"
    exit
fi

# Installation variables
stakeaddr=${1}
hostname=${2}
network=${3}
docker_network=zen${network}
nodename=zen${network}

if [ "${network}" -ne 0 -a "${network}" -ne 1 ]; then
    echo "Input network invalid"
    exit
fi

# port=$(( 9033 + network ))
port=${network}9033
rpcport=${network}8231
email=kay351601@aliyun.com
region=sea
fqdn=${hostname}.zennode.bitcoinarbi.com
mntdir=/mnt/$nodename
zen_node_name=${nodename}
zen_secnodetracker_name=${nodename}-secnodetracker
acme_name=${nodename}-acme

testnet=0
rpcpassword=$(head -c 32 /dev/urandom | base64)

print_status "Installing the ZenCash node..."

echo "#########################"
echo "fqdn: $fqdn"
echo "email: $email"
echo "stakeaddr: $stakeaddr"
echo "port: $port"
echo "#########################"

print_status "Creating the docker mount directories..."
mkdir -p ${mntdir}/{config,data,zcash-params,certs}


###    print_status "Installing acme container service..."
###    cat <<EOF > /etc/systemd/system/${acme_name}.service
###    [Unit]
###    Description=acme.sh container
###    After=docker.service
###    Requires=docker.service
###    
###    [Service]
###    TimeoutStartSec=10m
###    Restart=always
###    ExecStartPre=-/usr/bin/docker stop ${acme_name}
###    ExecStartPre=-/usr/bin/docker rm  ${acme_name}
###    # Always pull the latest docker image
###    ExecStartPre=/usr/bin/docker pull neilpang/acme.sh
###    ExecStart=/usr/bin/docker run --rm --network ${docker_network} -p 80:80 -v ${mntdir}/certs:/acme.sh --name ${acme_name} neilpang/acme.sh daemon
###    ExecStop=/usr/bin/docker stop ${acme_name}
###    ExecStop=/usr/bin/docker rm ${acme_name}
###    [Install]
###    WantedBy=multi-user.target
###    EOF
###    
###    systemctl daemon-reload
###    ### systemctl enable ${acme_name}
###    systemctl restart ${acme_name}
###    
###    print_status "Waiting for acme-sh to come up..."
###    until docker exec -it ${acme_name} --list
###    do
###      echo ".."
###      sleep 15
###    done


if [ ! -f /usr/zen/certs/$fqdn/$fqdn.cer ]; then
  print_status "Issusing cert for $fqdn..."
  docker exec acme-sh --issue -d $fqdn --standalone
  # Note: error code 2 means cert already isssued
  if [ $? -eq 1 ]; then
      print_status "Error provisioning certificate for domain.. exiting"
      exit 1
  fi
else
  print_status "Cert already exists, skip..."
fi

cp -a /mnt/zen/certs/$fqdn ${mntdir}/certs

print_status "Creating the zen configuration."
cat <<EOF > ${mntdir}/config/zen.conf
#rpcallowip=127.0.0.0/24
rpcallowip=0.0.0.0/0
rpcbind=0.0.0.0
server=1
# Docker doesn't run as daemon
daemon=0
listen=1
txindex=1
logtimestamps=1
### testnet config
testnet=$testnet
rpcuser=user
rpcpassword=$rpcpassword
tlscertpath=/mnt/zen/certs/$fqdn/$fqdn.cer
tlskeypath=/mnt/zen/certs/$fqdn/$fqdn.key
EOF

print_status "Creating the secnode config..."
mkdir -p ${mntdir}/secnode/
echo -n $email > ${mntdir}/secnode/email
echo -n $fqdn > ${mntdir}/secnode/fqdn
echo -n ${zen_node_name} > ${mntdir}/secnode/rpchost
#echo -n '127.0.0.1' > ${mntdir}/secnode/rpcallowip
#echo -n '127.0.0.1' > ${mntdir}/secnode/rpcbind
echo -n '0.0.0.0' > ${mntdir}/secnode/rpcallowip
echo -n '0.0.0.0' > ${mntdir}/secnode/rpcbind
echo -n "8231" > ${mntdir}/secnode/rpcport
echo -n 'user' > ${mntdir}/secnode/rpcuser
echo -n $rpcpassword > ${mntdir}/secnode/rpcpassword
echo -n 'ts1.eu,ts1.na,ts1.sea' > ${mntdir}/secnode/servers
echo -n "ts1.$region" > ${mntdir}/secnode/home
echo -n $region > ${mntdir}/secnode/region
echo -n 'http://devtracksys.secnodes.com' > ${mntdir}/secnode/serverurl
echo -n $stakeaddr > ${mntdir}/secnode/stakeaddr
echo -n '4' > ${mntdir}/secnode/ipv

print_status "Installing zend service..."
cat <<EOF > /etc/systemd/system/${zen_node_name}.service
[Unit]
Description=Zen Daemon Container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=10m
Restart=always
ExecStartPre=-/usr/bin/docker stop ${zen_node_name}
ExecStartPre=-/usr/bin/docker rm   ${zen_node_name}
# Always pull the latest docker image
ExecStartPre=/usr/bin/docker pull whenlambomoon/zend:latest
# Auto bind to the specific network adapter
ExecStart=/bin/bash -c "/usr/bin/docker run --rm --network ${docker_network} -p \$\$(ip addr show eth${network} | grep -Po 'inet \K[\d.]+'):9033:9033 -v ${mntdir}:/mnt/zen --name ${zen_node_name} whenlambomoon/zend:latest"
ExecStop=/usr/bin/docker stop ${zen_node_name}
ExecStop=/usr/bin/docker rm ${zen_node_name}
[Install]
WantedBy=multi-user.target
EOF

print_status "Installing secnodetracker service..."
cat <<EOF > /etc/systemd/system/${zen_secnodetracker_name}.service
[Unit]
Description=Zen Secnodetracker Container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=10m
Restart=always
ExecStartPre=-/usr/bin/docker stop ${zen_secnodetracker_name}
ExecStartPre=-/usr/bin/docker rm   ${zen_secnodetracker_name}
# Always pull the latest docker image
ExecStartPre=/usr/bin/docker pull whenlambomoon/secnodetracker:latest
#ExecStart=/usr/bin/docker run --init --rm --net=host -v ${mntdir}:/mnt/zen --name ${zen_secnodetracker_name} whenlambomoon/secnodetracker:latest
ExecStart=/usr/bin/docker run --rm --network ${docker_network} --link ${zen_node_name} -v ${mntdir}:/mnt/zen --name ${zen_secnodetracker_name} whenlambomoon/secnodetracker:latest
ExecStop=/usr/bin/docker stop ${zen_secnodetracker_name}
ExecStop=/usr/bin/docker rm ${zen_secnodetracker_name}
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

print_status "Done..."

