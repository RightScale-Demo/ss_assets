#!/bin/sh
# ---
# RightScript Name: Modify Web Page
# Inputs:
#   PAGE_COLOR:
#     Category: WEB PAGE SETTINGS
#     Description: Background color for the web page
#     Input Type: single
#     Required: true
#     Advanced: false
#     Default: text:#FFFFFF
#   PAGE_TEXT:
#     Category: WEB PAGE SETTINGS
#     Description: Web page text
#     Input Type: single
#     Required: true
#     Advanced: false
#     Default: text:Hello World!
#   PAGE_TITLE:
#     Category: WEB PAGE SETTINGS
#     Description: Web page title
#     Input Type: single
#     Required: true
#     Advanced: false
#     Default: text:Demo Page
#   HTML_FILE:
#     Category: WEB PAGE SETTINGS
#     Description: HTML file
#     Input Type: single
#     Required: true
#     Advanced: true
#     Default: text:/var/www/html/index.html
# Attachments:
# - skeleton_page.html
# ...

# location of the index html file
index_html=$HTML_FILE

# location of the staged skeleton page
skeleton_page="/var/www/html/skeleton_page.html"

# temp file
temp_page="/tmp/index.html"

# modify the staged skeleton page with the user-provided inputs and overwrite the index.html with this version of the page
sed "s/PAGE_TITLE/$PAGE_TITLE/" ${skeleton_page} |
sed "s/PAGE_TEXT/$PAGE_TEXT/" |
sed "s/PAGE_COLOR/$PAGE_COLOR/" > ${temp_page}

sudo mv ${temp_page} ${index_html}
