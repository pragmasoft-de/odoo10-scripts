#!/bin/bash

# Script to install odoo 10 on Ubuntu Server 16.04 LTS.
# (c) Josef Kaser 2016
# http://www.pragmasoft.de
#
# odoo will be listening on port 8069 on the external IP

# variables

# username and password for the OS user odoo
ODOO_USER_NAME=odoo
ODOO_USER_PWD='odoo'

# username and password the the OS user postgres
PG_USER_NAME=postgres
PG_USER_PWD='postgres'

# username and password for the DB user odoo
PG_ROLE_ODOO_NAME=odoo
PG_ROLE_ODOO_PWD='odoo'

# master password for odoo (for managing the databases)
ODOO_ADMIN_PASSWD='$ecr3t'

# needed later in the script to go back to the script directory
START_DIR=$PWD

# IP address the odoo service listens to
INTERFACE_IP=`hostname -I | awk '{print $1}'`

# here we go ;-)

# script must be run as root
if [ $USER != "root" ]; then
	echo "Script must be run as root"
	exit
fi

# set timezone
echo "Etc/UTC" > /etc/timezone

# upgrade OS
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y

# install required Ubuntu packages
apt-get install gcc unzip python2.7 python-dev python-pychart python-gnupg python-pil python-zsi python-ldap python-lxml python-dateutil libxslt1.1 libxslt1-dev libldap2-dev libsasl2-dev python-pip poppler-utils xfonts-base xfonts-75dpi xfonts-utils libxfont1 xfonts-encodings xzip xz-utils python-openpyxl python-xlrd python-decorator python-requests python-pypdf python-gevent npm nodejs node-less node-clean-css git mcrypt keychain software-properties-common python-passlib libjpeg-dev libfreetype6-dev zlib1g-dev libpng12-dev -y

# install PostgreSQL
apt-get install postgresql-9.5 postgresql-client postgresql-client-common postgresql-contrib-9.5 postgresql-server-dev-9.5 -y

# create database user "odoo"
/usr/bin/sudo -u $PG_USER_NAME ./create_pg_role.sh $PG_ROLE_ODOO_NAME $PG_ROLE_ODOO_PWD

# install required python modules
easy_install --upgrade pip
pip install BeautifulSoup BeautifulSoup4 passlib pillow dateutils polib unidecode flanker simplejson enum py4j

# install Node.js
npm install -g npm
npm install -g less-plugin-clean-css
npm install -g less

ln -s /usr/bin/nodejs /usr/bin/node
rm /usr/bin/lessc
ln -s /usr/local/bin/lessc /usr/bin/lessc

# cerate odoo10.conf from template and set some parameters
if [ -f odoo10.conf ]
	then rm odoo10.conf
fi

cp odoo10.conf.template odoo10.conf
sed -i s/{{admin_passwd}}/$ODOO_ADMIN_PASSWD/ odoo10.conf
sed -i s/{{db_password}}/$PG_ROLE_ODOO_PWD/ odoo10.conf
sed -i s/{{db_user}}/$PG_ROLE_ODOO_NAME/ odoo10.conf
sed -i s/{{interface_ip}}/$INTERFACE_IP/ odoo10.conf

# copy odoo10.conf to /etc/odoo
cd /etc
mkdir odoo
cd odoo
cp $START_DIR/odoo10.conf .

# install wkhtmltopdf
cd /tmp
mkdir wkhtmltopdf
cd wkhtmltopdf
wget http://download.gna.org/wkhtmltopdf/0.12/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz
unxz wkhtmltox-0.12.4_linux-generic-amd64.tar.xz
tar xvf wkhtmltox-0.12.4_linux-generic-amd64.tar
cd wkhtmltox/bin
cp * /usr/local/bin/
cd /usr/bin
ln -s /usr/local/bin/wkhtmltopdf ./wkhtmltopdf
cd /tmp
rm -rf wkhtmltopdf

# create OS user "odoo" and set password
useradd -m -U $ODOO_USER_NAME
echo "$ODOO_USER_NAME:$ODOO_USER_PWD" | chpasswd

# set password for OS user "postgres"
echo "$PG_USER_NAME:$PG_USER_PWD" | chpasswd

# create folder for odoo logfile and set permissions
cd /var/log
mkdir odoo
chown odoo.odoo odoo

# create folder for odoo
cd /opt
mkdir odoo

# get odoo10 from the official Github repository
cd odoo
git clone https://github.com/odoo/odoo --depth 1 -b 10.0
ln -s odoo ./odoo10

# install the required python modules
cd odoo10
pip install -r requirements.txt

# register odoo10 service
cd /etc/systemd/system
cp $START_DIR/odoo10.service .
chmod 644 odoo10.service
systemctl preset odoo10.service

# set shell for the users "odoo" and "postgres" to /bin/false to prevent login
usermod -s /bin/false $ODOO_USER_NAME
usermod -s /bin/false $PG_USER_NAME

# launch odoo10
service odoo10 start

