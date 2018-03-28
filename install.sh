#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

print_status() {
    echo
    echo "## $1"
    echo
}


print_status "Create swap..."

# Create swapfile if less then 4GB memory
if [ ! -f /swapfile ]; then
  totalmem=$(free -m | awk '/^Mem:/{print $2}')
  totalswp=$(free -m | awk '/^Swap:/{print $2}')
  totalm=$(($totalmem + $totalswp))
  if [ $totalm -lt 4000 ]; then
    print_status "Server memory is less then 4GB..."
    if ! grep -q '/swapfile' /etc/fstab ; then
      print_status "Creating a 4GB swapfile..."
      fallocate -l 4G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
  fi
fi

# Populating Cache
print_status "Populating apt-get cache..."
apt-get update

print_status "Installing packages required for setup..."
apt-get install -y docker.io apt-transport-https lsb-release curl fail2ban unattended-upgrades ufw > /dev/null 2>&1

systemctl enable docker
systemctl start docker

print_status "Creating the docker mount directories..."
mkdir -p /mnt/zen/{config,data,zcash-params,certs}

print_status "Installing acme container service..."

cat <<EOF > /etc/systemd/system/acme-sh.service
[Unit]
Description=acme.sh container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=10m
Restart=always
ExecStartPre=-/usr/bin/docker stop acme-sh
ExecStartPre=-/usr/bin/docker rm  acme-sh
# Always pull the latest docker image
ExecStartPre=/usr/bin/docker pull neilpang/acme.sh
ExecStart=/usr/bin/docker run --rm --net=host -v /mnt/zen/certs:/acme.sh --name acme-sh neilpang/acme.sh daemon
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable acme-sh
systemctl restart acme-sh

print_status "Waiting for acme-sh to come up..."
until docker exec -it acme-sh --list
do
  echo ".."
  sleep 15
done

#print_status "Enabling basic firewall services..."
#ufw default allow outgoing
#ufw default deny incoming
#ufw allow ssh/tcp
#ufw limit ssh/tcp
#ufw allow http/tcp
#ufw allow https/tcp
#ufw allow 9033/tcp
##ufw allow 19033/tcp
#ufw --force enable

print_status "Enabling fail2ban services..."
systemctl enable fail2ban
systemctl start fail2ban


print_status "Create docker network..."
docker network create -d bridge --subnet 10.0.0.0/24 --gateway 10.0.0.1 -o com.docker.network.bridge.name=zen0 zen0
docker network create -d bridge --subnet 10.1.1.0/24 --gateway 10.1.1.1 -o com.docker.network.bridge.name=zen1 zen1


print_status "Install Finished"
echo "Please wait until the blocks are up to date..."

