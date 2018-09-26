#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: Detect Purple Page Monitor Installer
# Description: Installs a monitor that returns a 1 if it detects a purple page background
# Inputs:
#   SERVER_UUID:
#     Category: Monitoring
#     Input Type: single
#     Required: true
#     Advanced: true
#     Default: env:RS_INSTANCE_UUID
#   HTML_FILE:
#     Category: Monitoring
#     Input Type: single
#     Required: true
#     Advanced: true
#     Default: text:/var/www/html/index.html
# Attachments:
# - check_webpage_background_color
# ...
#
# RightScript that installs a monitor script that returns a 1 if it detects page at 
# /var/www/html/index.html is set with a background color of purple.

# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.
#

# Setup platform specific configuration

if [[ -d /etc/apt ]]; then
    collectd_conf_dir=/etc/collectd
    collectd_conf_plugins_dir="$collectd_conf_dir/plugins"
    collectd_plugin_dir=/usr/lib/collectd
elif [[ -d /etc/yum.repos.d ]]; then
    collectd_conf_dir=/etc
    collectd_conf_plugins_dir="$collectd_conf_dir/collectd.d"
    collectd_plugin_dir=/usr/lib64/collectd
else
    echo "unsupported distribution!"
    exit 1
fi

plugin_script_name="check_webpage_background_color"


# Install the script
echo -n "Installing collectd plugin ..."
mkdir -p $collectd_plugin_dir/plugins
cp $RS_ATTACH_DIR/$plugin_script_name $collectd_plugin_dir/plugins/$plugin_script_name
chmod 775 $collectd_plugin_dir/plugins/$plugin_script_name
echo "Done"
echo

# Create the collectd configuration
echo "Configuring collectd..."
cat << EOF > $collectd_conf_plugins_dir/$plugin_script_name.conf
LoadPlugin exec
<Plugin exec>
  Exec "rightlink" "$collectd_plugin_dir/plugins/$plugin_script_name" "$SERVER_UUID" "$HTML_FILE"
</Plugin>
EOF

echo "Done"
echo
  
# Restart the service
service collectd restart
