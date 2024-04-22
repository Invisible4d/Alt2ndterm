#!/bin/bash

echo "Starting system update..."
sudo apt-get update -y

#Install Apache
sudo apt install -y apache2


# Variables
DB_ROOT_PASSWORD="tomnomnom"
DB_NAME="Altschool"
DB_TABLE="tomnomnom"

# Set MySQL root password in debconf
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $DB_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $DB_ROOT_PASSWORD"


# Install MySQL (non-interactive mode)
sudo apt install mysql-server -y

# Wait for MySQL server to start
sleep 10


# Run mysql_secure_installation script using expect for automation
sudo apt install -y expect

SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation

expect \"Enter password for user root:\"
send \"$DB_ROOT_PASSWORD\r\"

expect \"Press y|Y for Yes, any other key for No:\"
send \"n\r\"

expect \"Change the password for root ? ((Press y|Y for Yes, any other key for No) :\"
send \"n\r\"

expect \"Remove anonymous users? (Press y|Y for Yes, any other key for No) :\"
send \"y\r\"

expect \"Disallow root login remotely? (Press y|Y for Yes, any other key for No) :\"
send \"y\r\"

expect \"Remove test database and access to it? (Press y|Y for Yes, any other key for No) :\"
send \"y\r\"

expect \"Reload privilege tables now? (Press y|Y for Yes, any other key for No) :\"
send \"y\r\"

expect eof
")

echo "$SECURE_MYSQL"



# Commands to create database and table
mysql -u root -p"$DB_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql -u root -p"$DB_ROOT_PASSWORD" -D "$DB_NAME" -e "
CREATE TABLE IF NOT EXISTS $DB_TABLE (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

echo "Database and table have been created successfully."


# Start and enable Apache and MySQL
sudo systemctl start apache2
sudo systemctl enable apache2
sudo systemctl start mysql
sudo systemctl enable mysql


# Install PHP and necessary modules
sudo apt install -y php libapache2-mod-php php-mysql php8.2 php8.2-curl php8.2-dom php8.2-xml php8.2-mysql php8.2-sqlite3

# Set Default php8.2
sudo update-alternatives --set php /usr/bin/php8.2
sudo a2enmod php8.2

# Restart Apache to apply PHP changes
sudo systemctl restart apache2

# LAMP stack deployment complete
echo "==> LAMP stack deployment complete."

# Install Git
sudo apt install -y git

# Remove existing Laravel directory if it exists
sudo rm -rf /var/www/html/laravel

# Clone the Laravel repository from GitHub
sudo git clone https://github.com/laravel/laravel /var/www/html/laravel

# Navigate to the Laravel directory
cd /var/www/html/laravel

# Install Composer (Dependency Manager for PHP)
sudo apt install -y composer

# Upgrade Composer to version 2
sudo php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
sudo php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php composer-setup.php --install-dir /usr/bin --filename composer

# Use Composer to install dependencies
export COMPOSER_ALLOW_SUPERUSER=1
sudo -S <<< "yes" composer install

# Set permissions for Laravel directories
sudo chown -R www-data:www-data /var/www/html/laravel/storage
sudo chown -R www-data:www-data /var/www/html/laravel/bootstrap/cache
sudo chmod -R 775 /var/www/html/laravel/storage/logs

# Set up Apache Virtual Host configuration for Laravel
sudo cp /var/www/html/laravel/.env.example /var/www/html/laravel/.env

# Set correct permissions for .env file
sudo chown www-data:www-data .env
sudo chmod 640 .env

# Variables
server_ip=$(hostname -I)

# Create Apache Virtual Host configuration file
sudo tee /etc/apache2/sites-available/laravel.conf >/dev/null <<EOF
<VirtualHost *:80>
    ServerName server_ip
    ServerAlias *
    DocumentRoot /var/www/html/laravel/public

    <Directory /var/www/html/laravel>
        AllowOverride All
    </Directory>
</VirtualHost>
EOF

# Generate application key 
sudo php artisan key:generate

# Run Laravel migration to create MySQL database tables
sudo php artisan migrate --force

# Set permissions for Laravel database
sudo chown -R www-data:www-data /var/www/html/laravel/database/
sudo chmod -R 775 /var/www/html/laravel/database/

echo "==> Laravel setup complete."

# Check if the default Apache site is enabled
if sudo a2query -s 000-default.conf; then
    
else
    # Disable the default Apache site
    sudo a2dissite 000-default.conf
fi

# Check if the Laravel site is enabled
if sudo a2query -s laravel.conf; then

else
    # Enable the Laravel site
    sudo a2ensite laravel.conf
fi

# Reload Apache to apply changes
sudo systemctl reload apache2

echo " DEPLOYMENT COMPLETED!"