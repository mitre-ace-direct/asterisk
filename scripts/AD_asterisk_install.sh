#!/bin/bash

#This will stop the script if any of the commands fail
set -e

startPath=$(pwd)

#we need this to generate the self-signed Asterisk certs
PUBLIC_IP=''

#default STUN will be set to Google
GOOGLE='stun4.l.google.com:19302'

#Asterisk version
AST_VERSION=15.1.2

# Config file
INPUT=.config

#Hostname command suggestion
HOST_SUGG="You can use 'sudo hostnamectl set-hostname <hostname>' to set the hostname."

print_message() {
        # first argument is the type of message
        # (Error, Notify, Warning, Success)
        colorCode="sgr0"
        case $1 in
                Error)
                        colorCode=1
                        ;;
                Notify)
                        colorCode=3
                        ;;
                Success)
                        colorCode=2
                        ;;
        esac

        # second argument is the message string
        tput setaf $colorCode; printf "${1} -- "
        tput sgr0;             printf "${2}\n"
}

error_public_ip()
{
echo "ERROR: a proper public IP address was not found in .config"
echo "Please enter a valid IP address into .config and try again."
exit 1
}

# fail if the script is not run as root
# Source: http://www.cyberciti.biz/tips/shell-root-user-check-script.html
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ ! -f $INPUT ]; then
                print_message "Error" "$INPUT file not found. Please create the $INPUT and try again. Refer the the README for more info."
                exit 1
fi

# Retreive the public IP from the .config. If it wasn't loaded, fail the script.
IFS=","
TMP_FILE=/tmp/public_ip
# modify each file from the configuration file
echo "============================================================"
	while read tag files value
        do
		if [ "$tag" == "<public_ip>" ]; then
			echo "$value" > $TMP_FILE
			PUBLIC_IP=$(grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' $TMP_FILE 2>/dev/null) || :
			rm -f $TMP_FILE
			if [ "$PUBLIC_IP" == "" ]; then
        			print_message "Error" "a proper public IP address was not supplied in .config"
        			exit 1
			fi
		fi
	
        done < $INPUT

#check for IPv6 and SElinux

DISABLED="disabled"
SESTATUS=$(sestatus | head -1 | awk '{print $3}')
IPV6=$(cat /proc/net/if_inet6)

if [ $SESTATUS != $DISABLED ]
then
    echo "ERROR: SELinux must be disabled before running Asterisk. Disable SELinux, reboot the server, and try again."
    exit 1
fi

if [ -n "$IPV6" ]
then
    echo "ERROR: IPv6 must be disabled before installing Asterisk. See README.md for more information. Disable IPv6 then try again"
    exit 1
fi

#check hostname and fail if not set
HOSTNAME=$(hostname -f)
if [ -z $HOSTNAME ]
then
	echo "ERROR: no hostname set on this server. Set the hostname, then re run the script."
	echo $HOST_SUGG
	exit 1
fi

#ask user to validate hostname
echo "The hostname of this server is currently $HOSTNAME. Is this the hostname you want to use with Asterisk? (y/n)"
read response
if [ $response == "n" ]
	then
	echo "Exiting. Set the hostname, then rerun the script."
	echo $HOST_SUGG
	exit 0
fi

# prompt user to update packages
echo "It is recommended to update the packages in your system. Proceed? (y/n)"
read response2

if [ $response2 == "y" ]
then
    echo "Executing yum update"
    yum -y update
fi

# installing pre-requisite packages
echo "Installing pre-requisite packages for Asterisk and PJPROJECT"
yum -y install -y epel-release bzip2 dmidecode gcc-c++ ncurses-devel libxml2-devel make wget netstat telnet vim zip unzip openssl-devel newt-devel kernel-devel libuuid-devel gtk2-devel jansson-devel binutils-devel git libsrtp libsrtp-devel unixODBC unixODBC-devel libtool-ltdl libtool-ltdl-devel mysql-connector-odbc tcpdump patch sqlite bind-utils

#download Asterisk
cd /usr/src
wget http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/asterisk-$AST_VERSION.tar.gz
tar -zxf asterisk-$AST_VERSION.tar.gz && cd asterisk-$AST_VERSION

#remove RPM version of pjproject from pre-requisites install script
sed -i -e 's/pjproject-devel //' contrib/scripts/install_prereq
./contrib/scripts/install_prereq install

#install PJSIP and asterisk

cd $startPath
# Apply custom Asterisk patches, then apply custom PJPROJECT patch and install PJ and Asterisk
./update_asterisk.sh --patch --no-build --no-db
./build_pjproject.sh
# We need to run update_asterisk.sh again to populate the AstDB
./update_asterisk --restart

#run ldconfig so that Asterisk finds PJPROJECT packages
echo “/usr/local/lib” > /etc/ld.so.conf.d/usr_local.conf
/sbin/ldconfig

echo "Generating the Asterisk self-signed certificates. You will be prompted to enter a password or passphrase for the private key."
sleep 2

#generate TIS certificates
/usr/src/asterisk-$AST_VERSION/contrib/scripts/ast_tls_cert -C $PUBLIC_IP -O "ACE Direct" -d /etc/asterisk/keys

# pull down confi/media files and add to /etc/asterisk and /var/lib/asterisk/sounds, respectively
repo=$(dirname $startPath)
cd $repo
yes | cp -rf config/* /etc/asterisk
yes | cp -rf media/* /var/lib/asterisk/sounds/

#copy iTRS lookup script to agi-bin and make it executable
yes | cp -rf scripts/itrslookup.sh /var/lib/asterisk/agi-bin
chmod +x /var/lib/asterisk/agi-bin/itrslookup.sh

#modify configs with named params

cd $startPath
./update_asterisk.sh --config --restart

echo ""
echo "NOTE: the user passwords in pjsip.conf and the Asterisk Manager Interface"
echo "manager password in manager.conf should be updated before starting Asterisk."
echo "Otherwise, the defaults will be used. Once the passwords have been updated,"
echo "Run 'service asterisk restart' to apply the changes."
echo "View the conf files in /etc/asterisk for more info."
echo ""
echo ""
echo "     _    ____ _____   ____ ___ ____  _____ ____ _____ "
echo "    / \  / ___| ____| |  _ \_ _|  _ \| ____/ ___|_   _|"
echo "   / _ \| |   |  _|   | | | | || |_) |  _|| |     | |  "
echo "  / ___ \ |___| |___  | |_| | ||  _ <| |__| |___  | |  "
echo " /_/   \_\____|_____| |____/___|_| \_\_____\____| |_|  "
echo ""
echo "Installation is complete. When ready, run 'asterisk -rvvvvvvcg' to start the Asterisk console."
