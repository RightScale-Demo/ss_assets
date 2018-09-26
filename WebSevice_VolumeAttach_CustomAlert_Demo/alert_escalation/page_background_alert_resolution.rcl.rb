# The definitions below have access to:
# - @@instance which contains the instance that triggered the alert
# - @@alert which contains the alert that triggered this escalation

#DEPRECATED
# define alert() do
#
#    $channel = "#cat-demo-bot"
#    $slack_channel_hook = cred("SLACK_CAT-DEMO-BOT_Channel-hook")
#
#   $message = "Web page at http://"+@@instance.public_ip_addresses[0]+" no longer has purple background."
#      
#    # Send the message to slack
#    $response = http_post(
#      url: $slack_channel_hook,
#      body: { channel: $channel, text: $message} )
# 
#end

define alert() do
   # Close ticket
   # Get ticket infro from tag
  $tags = rs_cm.tags.by_resource(resource_hrefs: [@@instance.href])
  $tag_array = $tags[0][0]['tags']
  $found_tag = ""
  foreach $tag_item in $tag_array do
    if $tag_item['name'] =~ /rs:alert_incident/
  $found_tag = $tag_item["name"]
    end
  end
  $issue_link = split($found_tag, "=")[1]
   
   # SNOW API to close ticket
  $USER = cred("SERVICENOW_USER")
  $PASSWORD = cred("SERVICENOW_PASSWORD")
  $sn_instance_id = cred("SERVICENOW_INSTANCE_ID")
  $response = http_put(
    url: $issue_link,
    body: {
      state: "7"
    },
    headers: { "Content-Type": "application/json"},
    basic_auth: {
      "username": $USER,
      "password": $PASSWORD
    })
    
    $issue_id = last(split($issue_link, "/"))
    $issue_url = "https://"+$sn_instance_id+"/nav_to.do?uri=incident.do?sys_id="+$issue_id
    $ticket_message = "Ticket closed: "+$issue_url
      
    # Send the message to slack
    $channel = "#cat-demo-bot"
    $slack_channel_hook = cred("SLACK_CAT-DEMO-BOT_Channel-hook")
    $message = "Web page at http://"+@@instance.public_ip_addresses[0]+" no longer has purple background.\n"+$ticket_message
      
    $response = http_post(
      url: $slack_channel_hook,
      body: { channel: $channel, text: $message} )
 
end
