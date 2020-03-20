#!/usr/bin/env bash

#sudo apt update #&& sudo apt upgrade -y
sudo apt install -y  $(cat requirements.txt)

sudo mkdir -p /etc/admin-authz
echo -n "setting "
echo 'port=6000' | sudo tee -a /etc/admin-authz/authz.conf
sudo cp admin-authz.spec /etc/docker/plugins/admin-authz.spec
sudo mkdir -p /usr/local/bin
sudo cp admin-authz.py /usr/local/bin/
sudo cp admin-authz.service /lib/systemd/system/
echo "stopping docker service temporarily"
sudo service docker stop
sudo sed -Ei 's/^ExecStart=.+/& --authorization-plugin=admin-authz/1' /lib/systemd/system/docker.service

for i in /usr/local/bin/admin-authz.py /lib/systemd/system/admin-authz.service /etc/docker/plugins/admin-authz.spec /etc/admin-authz/authz.conf /etc/admin-authz; do
    sudo chown -R root:root $i
    sudo chmod 700 $i
done

echo "starting admin-authz and docker"
sudo systemctl daemon-reload
sudo systemctl enable --now admin-authz
sudo service docker start

cat authz-set-port >> $HOME/.bashrc

echo "restart the virtual terminal ... "

