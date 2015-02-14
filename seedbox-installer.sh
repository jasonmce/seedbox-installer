###################################################################
## seedbox-installer.sh
## A simple script created by Jason McEachen to create a fully
## functional seedbox for getting and sharing torrented files
## from a base Ubuntu install.
## Installs transmission, csf, and flexget
## Does configuration so that transmission/flexget can communicate
## and keeps csf from getting in the way.
###################################################################
#!/bin/bash

## Please personalize the following three values!
TRANSMISSION_USERNAME=swarm_user
TRANSMISSION_PASSWORD=swarm_pass
TRANSMISSION_PORT=9091

## If you appreciate a low-fi monitoring setup change these values.
ADD_SNMPD=false
SNMPD_COMMUNITY=public
SNMPD_REMOTE_IP=localhost

# Update to current.
apt-get update -y
apt-get upgrade -y

# Start install for transmission.
aptitude install python-software-properties -y
apt-get install software-properties-common -y
add-apt-repository ppa:transmissionbt -y

aptitude update
aptitude install transmission-daemon -y
perl -pi -e 's/"rpc-whitelist-enabled": true,/"rpc-whitelist-enabled": false,/' /etc/transmission-daemon/settings.json
perl -pi -e "s/\"rpc-port\": 9091,/\"rpc-port\": $TRANSMISSION_PORT,/" /etc/transmission-daemon/settings.json
perl -pi -e "s/\"rpc-username(.)+/\"rpc-username\": \"$TRANSMISSION_USERNAME\",/g" /etc/transmission-daemon/settings.json
perl -pi -e "s/\"rpc-password(.)+/\"rpc-password\": \"$TRANSMISSION_PASSWORD\",/g" /etc/transmission-daemon/settings.json
perl -pi -e 's/"trash-original-torrent-files": false, /"trash-original-torrent-files": true,/' /etc/transmission-daemon/settings.json
# Add lines to keep and eye on the watch directory.
perl -pi -e 's/"utp-enabled": true/"utp-enabled": true,/' /etc/transmission-daemon/settings.json
sed -i "s#}# \"watch-dir\": \"/var/lib/transmission-daemon/watch/\",\n}#" settings.json
sed -i "s#}# \"watch-dir-enabled\": true\n}#" settings.json

# restart transmission with the new settings this way, or settings
# will be reverted to their previous state
pkill -HUP transmission-da

# Install and configure flexget.
cd ~/
python -V
apt-get install python-pip -y
pip install flexget
which flexget
pwd
mkdir .flexget/909
cd .flexget
vi config.yml
which flexget

# Create a directory to hold our flexgotten torrent files.
mkdir /var/lib/transmission-daemon/watch
chmod 777 /var/lib/transmission-daemon/watch

crontab -l | { cat; echo "* * * * * /usr/local/bin/flexget execute --cron"; } | crontab -

# Install csf firewall, from http://www.configserver.com/free/csf/install.txt file.
mkdir ~/csf-install
cd ~/csf-install
wget http://www.configserver.com/free/csf.tgz
tar -xzf csf.tgz
cd csf
sh install.sh

if [ $ADD_SNMPD -eq true ]; then
  echo "$SNMPD_REMOTE_IP # SNMPD server" >> /etc/csf/csf.allow
fi

echo "Change CSF config TESTING=1 and start the service for 5 minutes."
echo "Once your config makes you happy, set TESTING=0 and restart to keep it running."



# Install snmpd if ADD_SNMPD was changed to true.
if [ $ADD_SNMPD -eq true ]; then
  apt-get install snmpd
  echo "rocommunity $SNMPD_COMMUNITY $SNMPD_REMOTE_IP" >> /etc/snmp/snmpd.conf
  service snmpd restart
fi
