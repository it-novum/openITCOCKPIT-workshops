#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

PWD=$(pwd)

if ! [ $(id -u) = 0 ]; then
    echo "You need to run this script as root user or via sudo!"
    exit 1
fi

apt-get update
apt-get dist-upgrade -y

apt-get install -y htop vim nano mc screen tmux sysstat make python3 build-essential wget curl git net-tools lsb-release pwgen openssh-server


########## GLOBAL SETTINGS ##########
EMAIL="community@openitcockpit.io"
PASSWORD=$(pwgen -s -1 16)
FIRSTNAME="Work"
LASTNAME="Shop"
LICENSE="e5aef99e-817b-0ff5-3f0e-140c1f342792"

USE_MANAGEMENT_SERVER="0"
MANAGEMENT_SERVER=""

if [ -n "$1" ]; then
    USE_MANAGEMENT_SERVER="1"
    MANAGEMENT_SERVER="$1"
fi

#MySQL Configs
INIFILE=/opt/openitc/etc/mysql/mysql.cnf
DUMPINIFILE=/opt/openitc/etc/mysql/dump.cnf
BASHCONF=/opt/openitc/etc/mysql/bash.conf
DEBIANCNF=/etc/mysql/debian.cnf
#####################################


if [ "$USE_MANAGEMENT_SERVER" -eq "1" ]; then
    
    echo "##############################"
    echo "#                            #"
    echo "#   Query license from MGMT  #"
    echo "#                            #"
    echo "##############################"
    
    LICENSE=$(curl http://$MANAGEMENT_SERVER/index.php\?action=license)
fi

echo "##############################"
echo "#                            #"
echo "#     Set root password      #"
echo "#                            #"
echo "##############################"

echo -e "$PASSWORD\n$PASSWORD" |passwd

cat /etc/ssh/sshd_config | grep -v PermitRootLogin > /tmp/sshd_config
cat /tmp/sshd_config | grep -v PasswordAuthentication > /tmp/sshd_config2

echo "PermitRootLogin yes" >> /tmp/sshd_config2
echo "PasswordAuthentication yes" >> /tmp/sshd_config2

cp /tmp/sshd_config2 /etc/ssh/sshd_config
rm -rf /tmp/sshd_config /tmp/sshd_config2

systemctl restart sshd

echo "##############################"
echo "#                            #"
echo "#       Setup NodeJS 14      #"
echo "#                            #"
echo "##############################"

cd /root/

wget https://deb.nodesource.com/setup_14.x
cat setup_14.x | bash
apt-get install -y nodejs

echo "##############################"
echo "#                            #"
echo "#         Setup WeTTY        #"
echo "#                            #"
echo "##############################"

cd /root/

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

apt-get update
apt-get -y install yarn

yarn global add wetty

cat <<EOT > /lib/systemd/system/wetty.service
[Unit]
Description=Terminal access in browser over http/https
After=syslog.target network.target
 
[Service]
User=root
Type=simple
ExecStart=/usr/local/bin/wetty --host 127.0.0.1 --base /terminal
 
[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable wetty.service
systemctl start wetty.service


echo "##############################"
echo "#                            #"
echo "#     Setup openITCOCKPIT    #"
echo "#                            #"
echo "##############################"

add-apt-repository universe
apt-get install -y apt-transport-https curl gnupg2 ca-certificates
curl https://packages.openitcockpit.io/repokey.txt | apt-key add -

echo "deb https://packages.openitcockpit.io/openitcockpit/$(lsb_release -sc)/stable $(lsb_release -sc) main" > /etc/apt/sources.list.d/openitcockpit.list

# Add license to apt so we can install CE/EE packages at this point
mkdir -p /etc/apt/auth.conf.d
echo "machine packages.openitcockpit.io login secret password ${LICENSE}" > /etc/apt/auth.conf.d/openitcockpit.conf

apt-get update
apt-get install -y openitcockpit

mkdir -p /opt/openitc/ansible/
cat <<EOT > /opt/openitc/ansible/ansible_settings.yml
# openITCOCKPIT SETUP.sh
# Uncomment this block to automate SETUP.sh
setup:
  firstname: ${FIRSTNAME}
  lastname: ${LASTNAME}
  email: ${EMAIL}
  password: ${PASSWORD}
  timezone: Europe/Berlin
  hostname: null
  mail:
    host: 127.0.0.1
    port: 25
    sender: openitcockpit@example.org
    username: null
    password: null
EOT

/opt/openitc/frontend/SETUP.sh

# Insert license into database
mysql --defaults-extra-file=${INIFILE} -e "TRUNCATE TABLE \`registers\`;"
mysql --defaults-extra-file=${INIFILE} -e "INSERT INTO \`registers\` (\`license\`, \`accepted\`, \`apt\`)VALUES('${LICENSE}', 1, 1);"

echo "##############################"
echo "#                            #"
echo "#      Setup phpMyAdmin      #"
echo "#                            #"
echo "##############################"

PMA_PASSWORD=$(pwgen -s -1 16)

echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect" | debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password password $PMA_PASSWORD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $PMA_PASSWORD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/internal/skip-preseed boolean true" | debconf-set-selections

apt-get install -y phpmyadmin

echo "##############################"
echo "#                            #"
echo "#   Enable MySQL root user   #"
echo "#                            #"
echo "##############################"

mysql --defaults-extra-file=${DEBIANCNF} -e "UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root';"
mysql --defaults-extra-file=${DEBIANCNF} -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${PASSWORD}';"
mysql --defaults-extra-file=${DEBIANCNF} -e "FLUSH PRIVILEGES;"

echo "##############################"
echo "#                            #"
echo "#  Setup reverse proxy WeTTY #"
echo "#                            #"
echo "##############################"

cat <<EOT >> /etc/nginx/openitc/custom.conf

location ^~/terminal {
    proxy_pass http://127.0.0.1:3000/terminal;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 43200000;

    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;
    proxy_set_header X-NginX-Proxy true;
}
EOT

systemctl restart nginx

echo "##############################"
echo "#                            #"
echo "#       Setup info page      #"
echo "#                            #"
echo "##############################"

cd /tmp/
git clone https://github.com/it-novum/openITCOCKPIT-workshops.git info

cp -r /tmp/info/info /opt/openitc/frontend/webroot/
chown www-data:www-data -R /opt/openitc/frontend/webroot/info

cat <<EOT > /opt/openitc/frontend/webroot/info/info.xml
<?xml version="1.0" encoding="UTF-8"?>
<info>
    <service>
      <name>openITCOCKPIT Web Interface</name>
      <description></description>
      <username><![CDATA[${EMAIL}]]></username>
      <password><![CDATA[${PASSWORD}]]></password>
      <url>
          <name>openITCOCKPIT</name>
          <href>/</href>
      </url>
    </service>
    <service>
      <name>SSH</name>
      <description></description>
      <username><![CDATA[root]]></username>
      <password><![CDATA[${PASSWORD}]]></password>
      <url>
          <name>Web terminal</name>
          <href>/terminal</href>
      </url>
    </service>
    <service>
      <name>MySQL database</name>
      <username><![CDATA[root]]></username>
      <description></description>
      <password><![CDATA[${PASSWORD}]]></password>
      <url>
          <name>phpMyAdmin</name>
          <href>/phpmyadmin</href>
      </url>
    </service>
</info>
EOT

echo "##############################"
echo "#                            #"
echo "#         Setup motd         #"
echo "#                            #"
echo "##############################"



cat <<EOT > /etc/update-motd.d/99-oitc
#!/bin/bash

IP=\$(curl https://statusengine.io/getip.php)

echo ""
echo "######### openITCOCKPIT Workshop #########"
echo "#  Monitoring Server"
echo "#"
echo "# Please navigate to https://\${IP}/info for more information"
echo "##########################################"
echo ""
EOT

chmod +x /etc/update-motd.d/99-oitc

# Print messages
echo ""
echo ""
echo ""
/etc/update-motd.d/99-oitc

if [ "$USE_MANAGEMENT_SERVER" -eq "1" ]; then
    
    IP=$(curl https://statusengine.io/getip.php)
    
    echo "##############################"
    echo "#                            #"
    echo "#   Register at mgmt server  #"
    echo "#                            #"
    echo "##############################"

    hostname=$(hostname)

    curl -d "hostname=${hostname}&ipaddress=${IP}&password=${PASSWORD}" -H "Content-Type: application/x-www-form-urlencoded" -X POST http://$MANAGEMENT_SERVER/index.php\?action=new_system
fi

echo "##############################"
echo "#                            #"
echo "#       Load bash.rc         #"
echo "#                            #"
echo "##############################"
echo 'export PS1="\[\033[38;5;7m\][\A]\[$(tput sgr0)\]\[\033[38;5;196m\]\u\[$(tput sgr0)\]\[\033[38;5;33m\]@\h:\[$(tput sgr0)\]\[\033[38;5;39m\]\w\\$\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput sgr0)\]"' >> /root/.bashrc



cd $PWD


