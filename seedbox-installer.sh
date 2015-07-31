###################################################################
## seedbox-installer.sh
## A simple script created by Jason McEachen to create a fully
## functional seedbox for getting and sharing torrented files
## from a base Ubuntu install.
## Installs transmission, csf, and flexget
## Does configuration so that transmission/flexget can communicate
## and keeps csf from getting in the way.
##
## You can preset values from the command line by typing
## $ export TRANSMISSION_USERNAME=bettername
## and the script will use those values instead of the defaults.
###################################################################
#!/bin/bash

# Takes a name and default value.  If $name is unset then gives it the value.
set_default() {
  if [ -z ${!1} ]; then
    eval "$1=${2}"
  fi
}

## Please personalize the following three values!
set_default TRANSMISSION_USERNAME swarm_user
set_default TRANSMISSION_PASSWORD swarm_pass
set_default TRANSMISSION_PORT 9091

## If you appreciate a low-fi monitoring setup change these values.
set_default ADD_SNMPD false
set_default SNMPD_COMMUNITY public
set_default SNMPD_REMOTE_IP localhost

## In case you like to run SSH on an alternate port
set_default SSH_PORT 22

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

# Create the default download directory and set ownership.
mkdir -p /home/debian-transmission/Downloads
chown -R debian-transmission:debian-transmission /home/debian-transmission

# restart transmission with the new settings this way, or settings
# will be reverted to their previous state
pkill -HUP transmission-da

# Install and configure flexget.
cd ~/
python -V
apt-get install python-pip -y
pip install flexget
pip install --upgrade six # make sure the latest version of this python tool is available
mkdir .flexget/
touch .flexget/config.yml # Where the config will go
# you can test with "flexget execute"

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
# If they specified an SNMPD server, allow it through the firewall
if [ $ADD_SNMPD -eq true ]; then
  echo "$SNMPD_REMOTE_IP # SNMPD server" >> /etc/csf/csf.allow
fi

## Minimize our firewall holes to the bare minimum.
sed -i 's/^TCP_IN =.*/TCP_IN = "$SSH_PORT,$TRANSMISSION_PORT,49152:65535"/' csf.conf
sed -i 's/^TCP_OUT =.*/TCP_OUT = "49152:65535"/' csf.conf
## Include SNMP ports if that service has been added.
if [ $ADD_SNMPD -eq true ]; then
  sed -i 's/^UDP_IN =.*/UDP_IN = "161,162,49152:65535"/' csf.conf
else
  sed -i 's/^UDP_IN =.*/UDP_IN = "49152:65535"/' csf.conf
fi
sed -i 's/^UDP_OUT =.*/UDP_OUT = "49152:65535"/' csf.conf

echo "Change CSF config TESTING=1 and start the service for 5 minutes."
echo "Once your config makes you happy, set TESTING=0 and restart to keep it running."


# Install snmpd if ADD_SNMPD was changed to true.
if [ $ADD_SNMPD -eq true ]; then
  apt-get install snmpd
  echo "rocommunity $SNMPD_COMMUNITY $SNMPD_REMOTE_IP" >> /etc/snmp/snmpd.conf
  service snmpd restart
fi

## Change SSH port if requested
sed -i "s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
