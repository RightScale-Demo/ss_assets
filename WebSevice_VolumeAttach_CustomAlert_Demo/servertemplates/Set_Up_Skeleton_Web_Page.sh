#!/bin/sh
# ---
# RightScript Name: Set Up Skeleton Web Page
# Inputs: {}
# Attachments:
# - skeleton_page.html
# ...

# The name of the attached skeleton page
skeleton_page=skeleton_page.html

# copy the skeleton page to the html folder for future use.
sudo cp $RS_ATTACH_DIR/$skeleton_page /var/www/html

# overwrite the default index.html with the skeleton page as the initial set up
sudo cp $RS_ATTACH_DIR/$skeleton_page /var/www/html/index.html
