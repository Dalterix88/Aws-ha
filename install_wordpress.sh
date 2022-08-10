#!/bin/bash

DB_NAME="${DB_NAME}"
DB_HOSTNAME="${DB_HOSTNAME}"
DB_USERNAME="${DB_USERNAME}"
DB_PASSWORD="${DB_PASSWORD}"

WP_ADMIN="wordpressadmin"
WP_PASSWORD="wordpressadminn"

LB_HOSTNAME="${LB_HOSTNAME}"


yum update -y
yum install httpd -y
systemctl start httpd
systemctl enable httpd
echo "<html><body><h1>Hi there</h1></body></html>" > /var/www/html/index.html
sudo yum install -y amazon-linux-extras
sudo amazon-linux-extras enable php7.4
sudo yum clean metadata
sudo yum install -y  php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap}
sudo service httpd restart
sudo chmod go+rw /var/www/htm
sudo yum install -y mariadb-server
sudo systemctl start mariadb
sudo amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
sudo cp -r wordpress/* /var/www/html/
sudo curl -o /bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
sudo chmod +x /bin/wp
# Insert DB info to wordpress config file and install theme
sudo usermod -a -G apache ec2-user
sudo chown -R ec2-user:apache /var/www
sudo find /var/www -type d -exec chmod 2775 {} \;
sudo find /var/www -type f -exec chmod 0664 {} \;
cd /var/www/html
sudo rm -rf index.html
sudo wp core download --version='4.9' --locale='en_GB' --allow-root

# Loop until config wordpress file is created
while [ ! -f /var/www/html/wp-config.php ]
do
cd /var/www/html
sudo wp core config --dbname="$DB_NAME" --dbuser="$DB_USERNAME" --dbpass="$DB_PASSWORD" --dbhost="$DB_HOSTNAME" --dbprefix=wp_ --allow-root
sleep 2
done

sudo wp core install --url="http://$LB_HOSTNAME" --title='Dalterix88 HA Wordpress' --admin_user="admin" --admin_password="test123" --admin_email='admin@example.com' --allow-root

chown -R ec2-user:apache /var/www/html
chmod -R 774 /var/www/html
sudo sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/httpd/conf/httpd.conf
# Restart httpd
sudo chkconfig httpd on
sudo service httpd start
sudo service httpd restart
#Restart httpd after a while
setsid nohup "sleep 480; sudo service httpd restart" &
