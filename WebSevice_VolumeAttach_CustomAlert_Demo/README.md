# Account/Demo Set Up Notes
## Cloud Management Set Up
* Create following CREDENTIALS in Cloud Management
** SLACK_CAT-DEMO-BOT_Channel-hook: Slack channel hook used to send things to a slack channel via API.
** SERVICENOW_INSTANCE_ID: URI for SNOW instance being used. E.g. dev17048.service-now.com
** SERVICENOW_USER: User ID for accessing SNOW instance.
** SERVICENOW_PASSWORD: Password for accessing SNOW instance.
* Use right_st to push servertemplate(s) and related elements into the account.
* In Cloud Management UI, create an alert escalation with the name, "backgound_color_alert"
** Add new action: run cloud workflow
*** Copy the RCL found in the page_background_alert_escalation.rcl.rb file found in the alert_escalation folder.
** Add RESOLUTION action: run cloud workflow
*** Copy the RCL found in the page_background_alert_resolution.rcl.rb file found under the alert_escalation folder.

## Self Service Set Up
* Update the CAT file as follows:
** Near line 469 find the "map_cloud" structure.
** Change the zone_href and vol_type_href for AWS and Google to the use the applicable hrefs from the account you are setting up.
** Change the pg_href for AzureRM to use a placement group (aka storage account) you want to use.
* Push the CAT file into the account 

## Demo Notes
* Open up a browser tab and point it at the "#cat-demo-bot" slack channel: https://rightscale.slack.com/messages/C0A0RS895/
* Make sure the demo ServiceNow instance is up and running.
* Launch the Web Service CAT.
** As part of the launch or as a post-launch action, set the background color to purple to trigger the alert.
* Note the Slack channel updates and if alert triggered, the SNOW ticket that is created.
* Change the background to something other than purple.
* Note the Slack channel updates and the SNOW ticket being closed.



