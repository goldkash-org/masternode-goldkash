#!/bin/bash

################################################
# Script by François YoYae GINESTE - 03/04/2018
# Recode by GoldKash Dev for GoldKash Core - 20/10/2018
# https://www.goldkash.org/
################################################

LOG_FILE=/tmp/install.log

decho () {
  echo `date +"%H:%M:%S"` $1
  echo `date +"%H:%M:%S"` $1 >> $LOG_FILE
}

error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  echo "Error on or near line ${parent_lineno}; exiting with status ${code}"
  exit "${code}"
}
trap 'error ${LINENO}' ERR

clear

cat <<'FIG'
  _____       _     _ _  __         _      __   _______ _  __
 / ____|     | |   | | |/ /        | |     \ \ / / ____| |/ /
| |  __  ___ | | __| | ' / __ _ ___| |__    \ V / |  __| ' / 
| | |_ |/ _ \| |/ _` |  < / _` / __| '_ \    > <| | |_ |  <  
| |__| | (_) | | (_| | . \ (_| \__ \ | | |  / . \ |__| | . \ 
 \_____|\___/|_|\__,_|_|\_\__,_|___/_| |_| /_/ \_\_____|_|\_\ 
 
FIG

# Check for systemd
systemctl --version >/dev/null 2>&1 || { decho "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# Check if executed as root user
if [[ $EUID -ne 0 ]]; then
	echo -e "This script has to be run as \033[1mroot\033[0m user"
	exit 1
fi

#print variable on a screen
decho "Make sure you double check before hitting enter !"

read -e -p "User that will run GoldKash core /!\ case sensitive /!\ : " whoami
if [[ "$whoami" == "" ]]; then
	decho "WARNING: No user entered, exiting !!!"
	exit 3
fi
if [[ "$whoami" == "root" ]]; then
	decho "WARNING: user root entered? It is recommended to use a non-root user, exiting !!!"
	exit 3
fi
read -e -p "Server IP Address : " ip
if [[ "$ip" == "" ]]; then
	decho "WARNING: No IP entered, exiting !!!"
	exit 3
fi
read -e -p "Masternode Private Key (e.g. 7sESCNERGDWdsuBBpW7G3seze  # THE KEY YOU GENERATED EARLIER) : " key
if [[ "$key" == "" ]]; then
	decho "WARNING: No masternode private key entered, exiting !!!"
	exit 3
fi
read -e -p "(Optional) Install Fail2ban? (Recommended) [Y/n] : " install_fail2ban
read -e -p "(Optional) Install UFW and configure ports? (Recommended) [Y/n] : " UFW

decho "Updating system and installing required packages."

# update package and upgrade Ubuntu
apt-get -o Acquire::ForceIPv4=true -y update >> $LOG_FILE 2>&1
# Add Berkely PPA
decho "Installing Bitcoin & GoldKash PPA ( it would take 5-10 Minutes )"
#apt-get -o Acquire::ForceIPv4=true -y install unzip >> $LOG_FILE 2>&1
apt-get -o Acquire::ForceIPv4=true -y install build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils >> $LOG_FILE 2>&1
apt-get -o Acquire::ForceIPv4=true -y install libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev >> $LOG_FILE 2>&1
apt-get -o Acquire::ForceIPv4=true -y install libboost-all-dev git >> $LOG_FILE 2>&1
add-apt-repository -y ppa:bitcoin/bitcoin
apt-get -o Acquire::ForceIPv4=true -y update >> $LOG_FILE 2>&1
apt-get -o Acquire::ForceIPv4=true -y  install libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libgmp3-dev >> $LOG_FILE 2>&1
decho "Downloading GoldKash v1.1.0.1 Core ( it would take 3-10 Minutes )"
wget https://github.com/goldkash-org/GoldKash/releases/download/v1.1.0.1/GoldKash-v1.1.0.1_Linux64.tar.gz  >> $LOG_FILE 2>&1
decho "Extract GoldKash v1.1.0.1 Core"
tar -xzvf GoldKash-v1.1.0.1_Linux64.tar.gz

chmod 755 goldkashd
chmod 755 goldkash-cli
chmod 755 goldkash-tx

cp goldkashd /usr/local/bin/
cp goldkash-cli /usr/local/bin/
cp goldkash-tx /usr/local/bin/

rm goldkashd
rm goldkash-cli
rm goldkash-tx

# Install required packages
decho "Installing base packages and dependencies..."

apt-get -o Acquire::ForceIPv4=true -y install sudo >> $LOG_FILE 2>&1
apt-get -o Acquire::ForceIPv4=true -y install wget >> $LOG_FILE 2>&1
apt-get -o Acquire::ForceIPv4=true -y install git >> $LOG_FILE 2>&1
apt-get -o Acquire::ForceIPv4=true -y install virtualenv >> $LOG_FILE 2>&1
apt-get -o Acquire::ForceIPv4=true -y install python-virtualenv >> $LOG_FILE 2>&1
apt-get -o Acquire::ForceIPv4=true -y install pwgen >> $LOG_FILE 2>&1

#Install GoldKash Daemon
decho "Installing GoldKash Core..."
#apt-get -y install GoldKash >> $LOG_FILE 2>&1

if [[ ("$install_fail2ban" == "y" || "$install_fail2ban" == "Y" || "$install_fail2ban" == "") ]]; then
	decho "Optional installs : fail2ban"
	cd ~
	apt-get -o Acquire::ForceIPv4=true -y install fail2ban >> $LOG_FILE 2>&1
	systemctl enable fail2ban >> $LOG_FILE 2>&1
	systemctl start fail2ban >> $LOG_FILE 2>&1
fi

if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
	decho "Optional installs : ufw"
	apt-get -o Acquire::ForceIPv4=true -y install ufw >> $LOG_FILE 2>&1
	ufw allow ssh/tcp >> $LOG_FILE 2>&1
	ufw allow sftp/tcp >> $LOG_FILE 2>&1
	ufw allow 14451/tcp >> $LOG_FILE 2>&1
	ufw allow 14452/tcp >> $LOG_FILE 2>&1
	ufw default deny incoming >> $LOG_FILE 2>&1
	ufw default allow outgoing >> $LOG_FILE 2>&1
	ufw logging on >> $LOG_FILE 2>&1
	ufw --force enable >> $LOG_FILE 2>&1
fi

decho "Create user $whoami (if necessary)"
#desactivate trap only for this command
trap '' ERR
getent passwd $whoami > /dev/null 2&>1

if [ $? -ne 0 ]; then
	trap 'error ${LINENO}' ERR
	adduser --disabled-password --gecos "" $whoami >> $LOG_FILE 2>&1
else
	trap 'error ${LINENO}' ERR
fi

#Create goldkash.conf
decho "Setting up GoldKash Core"
#Generating Random Passwords
user=`pwgen -s 16 1`
password=`pwgen -s 64 1`

echo 'Creating goldkash.conf...'
mkdir -p /home/$whoami/.goldkashcore/
cat << EOF > /home/$whoami/.goldkashcore/goldkash.conf
rpcuser=$user
rpcpassword=$password
rpcallowip=127.0.0.1
rpcport=14452
listen=1
server=1
daemon=1
maxconnections=24
masternode=1
masternodeprivkey=$key
externalip=$ip
addnode=37.48.64.80
addnonde=82.192.82.140
addnode=37.48.64.90
addnode=37.48.64.85
addnode=119.81.29.50

EOF
chown -R $whoami:$whoami /home/$whoami

#Run goldkashd as selected user
sudo -H -u $whoami bash -c 'goldkashd' >> $LOG_FILE 2>&1

echo 'GoldKash Core prepared and lunched'

sleep 10

#Setting up coin

decho "Setting up sentinel"

echo 'Downloading sentinel...'
#Install Sentinel
git clone https://github.com/goldkash-org/sentinel.git /home/$whoami/sentinel >> $LOG_FILE 2>&1
chown -R $whoami:$whoami /home/$whoami/sentinel >> $LOG_FILE 2>&1

cd /home/$whoami/sentinel
echo 'Setting up dependencies...'
export LC_ALL="en_US.UTF-8" >> $LOG_FILE 2>&1
export LC_CTYPE="en_US.UTF-8" >> $LOG_FILE 2>&1
sudo -H -u $whoami bash -c 'virtualenv ./venv' >> $LOG_FILE 2>&1
sudo -H -u $whoami bash -c './venv/bin/pip install -r requirements.txt' >> $LOG_FILE 2>&1

#Setup crontab
echo "@reboot sleep 30 && goldkashd" >> newCrontab
echo "* * * * * cd /home/$whoami/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >> newCrontab
crontab -u $whoami newCrontab >> $LOG_FILE 2>&1
rm newCrontab >> $LOG_FILE 2>&1

decho "Starting your masternode"
echo ""
echo "Now, you need to finally start your masternode in the following order: "
echo "1- Go to your windows/mac wallet and modify masternode.conf as required, then restart and from the Masternode tab"
echo "2- Select the newly created masternode and then click on start-alias."
echo "3- Once completed, please return to VPS and wait for the wallet to be synced."
echo "4- Then you can try the command 'goldkash-cli masternode status' to get the masternode status."

su $whoami
