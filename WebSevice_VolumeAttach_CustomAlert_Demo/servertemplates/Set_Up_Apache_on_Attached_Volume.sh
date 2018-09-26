#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: Set Up Apache on Attached Volume
# Description: Mounts an attached volume and sets up Apache to use that attached volume
#   for the web files
# Inputs:
#   DISK_DEVICE:
#     Category: Uncategorized
#     Input Type: single
#     Required: true
#     Advanced: false
# Attachments: []
# ...

# format the volume
mkfs -t ext4 $DISK_DEVICE

# create mount point directory
mount_point="/data"
mkdir $mount_point

# mount volume to filesystem
mount $DISK_DEVICE $mount_point

# sync the existing files over to the mounted folder
rsync -av /var/www/html /data

# Update apache settings to use mounted folder
apache_dir="/etc/apache2"
sites_dir="${apache_dir}/sites-available"
conf_file="${sites_dir}/000-default.conf"
sed 's/DocumentRoot.*/DocumentRoot \/data\/html/g' ${conf_file} > "${conf_file}.mod"
mv "${conf_file}.mod" ${conf_file}

apache_conf="${apache_dir}/apache2.conf"
cat <<EOT >> ${apache_conf}
<Directory /data/html/>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
</Directory>
EOT

# Restart apache
service apache2 restart
