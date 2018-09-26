# The definitions below have access to:
# - @@instance which contains the instance that triggered the alert
# - @@alert which contains the alert that triggered this escalation

# DEPRECATED
#define alert() do
#
#    $channel = "#cat-demo-bot"
#    $slack_channel_hook = cred("SLACK_CAT-DEMO-BOT_Channel-hook")
#
#   $message = "Web page found with purple background at http://"+@@instance.public_ip_addresses[0]+"\nInstance name: "+ @@instance.name +",\nInstance HREF: "+@@instance.href
#      
#    # Send the message to slack
#    $response = http_post(
#      url: $slack_channel_hook,
#      body: { channel: $channel, text: $message} )
# 
#end

define alert() do

  # Inform Slack Channel
  $channel = "#cat-demo-bot"
  $slack_channel_hook = cred("SLACK_CAT-DEMO-BOT_Channel-hook")
  
  $message = "Web page found with purple background at http://"+@@instance.public_ip_addresses[0]+"\nInstance name: "+ @@instance.name +",\nInstance HREF: "+@@instance.href
  
  # Send the message to slack
  $response = http_post(
    url: $slack_channel_hook,
    body: { channel: $channel, text: $message} )

  # Open SNOW ticket
  $sn_instance_id = cred("SERVICENOW_INSTANCE_ID")
  $USER = cred("SERVICENOW_USER")
  $PASSWORD = cred("SERVICENOW_PASSWORD")
  
  $sn_api_url = "https://"+$sn_instance_id+"/api/now/table/incident"
  
  $summary = $message
  
  $response = http_post(
    url: $sn_api_url,
    body: {
      short_description: $summary
    },
    headers: { "Content-Type": "application/json"},
    basic_auth: {
      "username": $USER,
      "password": $PASSWORD
      }
    )

  $issue_link = $response["headers"]["Location"]
  $issue_id = last(split($issue_link, "/"))
  $issue_url = "https://"+$sn_instance_id+"/nav_to.do?uri=incident.do?sys_id="+$issue_id
  $message = "Ticket opened: "+$issue_url
    
  # Send message to slack with ticket info
  $response = http_post(
    url: $slack_channel_hook,
    body: { channel: $channel, text: $message} )
      
  # Tag instance with ticket info (used for later resolution)
  rs_cm.tags.multi_add(resource_hrefs: @@instance.href[], tags:["rs:alert_incident="+$issue_link])


end
