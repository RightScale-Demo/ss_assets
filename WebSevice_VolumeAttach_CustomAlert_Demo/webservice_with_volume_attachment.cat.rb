name "Web Service"
rs_ca_ver 20161221
short_description "![Linux](https://s3.amazonaws.com/rs-pft/cat-logos/linux_logo.png)\n
Launch a web server with configurable background color and text and title and snapshot management."
long_description "Used to demonstrate orchestration and automation around alarm notifications and actions.\n
Setting the background color to \"purple\" will trigger an alert and escalation."

import "pft/mappings"
import "pft/parameters"
import "pft/conditions"
import "pft/resources", as: "common_resources"
import "pft/err_utilities", as: "debug"
import "pft/linux_server_declarations"

#############
# INPUTS    #
#############
parameter "param_location" do
  like $parameters.param_location
  allowed_values "AWS", "AzureRM", "Google"
end

parameter "param_instancetype" do
  like $parameters.param_instancetype
end

parameter "param_costcenter" do
  like $parameters.param_costcenter
end

parameter "param_page_text" do
  category "Web Page Settings"
  label "Page Text"
  type "string"
  description "Text to display on web page"
  default "Hello World!"  
end

parameter "param_page_title" do
  category "Web Page Settings"
  label "Page Title"
  type "string"
  description "Web page title"
  default "Hi"
end

parameter "param_page_color" do
  category "Web Page Settings"
  label "Page Color"
  type "string"
  description "Web page color. Purple will trigger alert"
  allowed_values "red", "white", "blue", "purple"
  default "white"
end

parameter "param_snapshot_schedule" do
  category "Volume Management"
  label "Snapshot Schedule (optional)"
  description "Automatic snapshot frequency."
  type "string"
  allowed_values "NONE", "DAILY", "WEEKLY", "MONTHLY"
  default "NONE"
end

parameter "param_snapshot_name" do
  label "Snapshot Name"
  description "Enter a snapshot name."
  type "string"
  operations "delete_snapshot","restore_from_snapshot"
end

##############
# OUTPUTS    #
##############
output "server_url" do
  label "Server URL" 
  category "Connect"
  description "Access the web server page."
end

output "output_snapshots" do
  label "Current List of Snapshots"
  category "Volume Information"
  description "List of snapshots for attached volume."
  default_value "No snapshots created yet."
end

output "output_spend_limit" do
  label "Application Spend Limit"
  category "Spending Limit"
  description "Spend limt for this running cloud application."
  default_value "$50"
end


##################
# RESOURCES      #
##################

resource "web_server", type: "server" do
  name join(['web-',map($map_costcenter2namepart, $param_costcenter, "name_part"), "-",last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  network find(map($map_cloud, $param_location, "network"))
  subnets find(map($map_cloud, $param_location, "subnet"))
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  server_template "Basic Web Server"
  inputs do {
    "PAGE_TEXT" => join(["text:", $param_page_text]),
    "PAGE_TITLE" => join(["text:", $param_page_title]),
    "PAGE_COLOR" => join(["text:", $param_page_color])
  } end
end

resource "server_volume", type: "volume" do
  name join([@web_server.name, "-vol"])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "zone")
  placement_group_href map($map_cloud, $param_location, "pg_href")
  volume_type_href map($map_cloud, $param_location, "vol_type_href")
  size "1"
end

resource "server_vol_attachment", type: "volume_attachment" do
  name join([@server_volume.name, "-attachment"])
  cloud map($map_cloud, $param_location, "cloud")
  server @web_server
  volume @server_volume
  device map($map_cloud, $param_location, "vol_device")
end


### Security Group Definitions ###
# Note: Even though not all environments need or use security groups, the launch operation/definition will decide whether or not
# to provision the security group and rules.
resource "sec_group", type: "security_group" do
  like @common_resources.sec_group
end

resource "sec_group_rule_http", type: "security_group_rule" do
  like @common_resources.sec_group_rule_ssh
  protocol_details do {
    "start_port" => "80",
    "end_port" => "80"
  } end
end

################
# OPERATIONS   #
################
### LAUNCH ###
operation "launch" do
  description "Launch orchestration"
  definition "launch"
end

define launch(@web_server, @sec_group, @sec_group_rule_http, @server_volume, @server_vol_attachment) return @web_server, @sec_group, @sec_group_rule_http, @server_volume, @server_vol_attachment do
  provision(@sec_group_rule_http)
  concurrent return  @web_server, @server_volume, @server_vol_attachment do
    sub task_name:"Launch Web Server" do
      task_label("Launching Web Server")
      provision(@web_server)
    end
  end
  
  task_label("Creating and attaching volume")
  provision(@server_volume)
  provision(@server_vol_attachment)
end

### ENABLE ###
operation "enable" do
  description "Post launch actions"
  definition "post_launch"
  # This is a way to drive output values from RCL.
  output_mappings do {
    $server_url => $web_server_link,
    $output_snapshots => $current_snapshots
  } end
end

define post_launch(@web_server, @server_volume, $param_snapshot_schedule, $map_cloud, $param_location, $param_costcenter) return $web_server_link, $current_snapshots do
    
  # Set up Apache to use the attached volume for the web server and related monitor
  task_label("Configuring Apache to use attached volume.")
  $inp = {
      DISK_DEVICE: "text:"+map($map_cloud, $param_location, "disk_device"),
      HTML_FILE: "text:/data/html/index.html",  # Mounted location of the file
      SERVER_UUID: "env:RS_INSTANCE_UUID"
  }
  call update_servers_inputs(@web_server, $inp)
  call run_script(@web_server, "Set Up Apache on Attached Volume",  $inp)
  
  # Check if user specified a snapshot schedule
  if $param_snapshot_schedule != "NONE"
    call schedule_volume_snapshots(@server_volume, $param_snapshot_schedule) retrieve $current_snapshots 
  end
  
  # Set up the web page background monitor
  task_label("Configuring Apache to use attached volume.")
  call run_script(@web_server, "Detect Purple Page Monitor Installer",  $inp)
  
  # tag the server
  task_label("Tagging the resources.")
  $tags=[join([map($map_cloud, $param_location, "tag_prefix"),":costcenter=",$param_costcenter])]
  rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)

  # Get the link to the web server
  call get_server_link(@web_server) retrieve $web_server_link
  
  # Send notification to Slack channel
  $created_by = @@execution.created_by
  $launch_user = $created_by["name"]
  call notify_slack("#cat-demo-bot", "Cloud application, "+@@execution.name+", launched by "+$launch_user+".")
end

operation "terminate" do
  label "Clean up" 
  definition "clean_up"
end

# Do some clean up before letting auto-terminate do it's thing
define clean_up(@web_server, @server_volume) do
  
  # Unmount the web drive. This is needed so that AWS will allow the volume to be detached and deleted.
  # It doesn't hurt to do it on the other clouds as well.
  call run_script_noinputs(@web_server, "Unumount Web Data Drive") # no inputs used by this rightscript

  # Clean up any snapshots
  $wake_condition = "/^(available)$/"
  if logic_not(empty?(@server_volume.volume_snapshots()))
    sleep_until all?(@server_volume.volume_snapshots().state[], $wake_condition)  
    @server_volume.volume_snapshots().destroy()
  end
end

# update web page post launch action
operation "update_web_page" do
  label "Update Web Page"
  #description "Modify the web page settings."
  definition "update_web_page"
end

# Snapshot post launch actions
operation "create_snapshot" do
  label "Create volume snapshot (on demand)"
  definition "create_volume_snapshot"
  output_mappings do {
    $output_snapshots => $current_snapshots
  } end
end
operation "schedule_snapshot" do
  label "Schedule volume snapshots."
  definition "schedule_volume_snapshots"
  output_mappings do {
    $output_snapshots => $current_snapshots
  } end
end
operation "delete_snapshot" do
  label "Delete volume snapshot"
  definition "delete_volume_snapshot"
  output_mappings do {
    $output_snapshots => $current_snapshots
  } end
end
operation "restore_from_snapshot" do
  label "Restore web page from volume snapshot"
  definition "restore_from_snapshot"
end

#
# Volume operations
#
define create_volume_snapshot(@server_volume) return $current_snapshots do
  $snapshot_name_root = @server_volume.name + "-snapshot-"
  $time_stamp = strftime(now(), "%Y-%m-%d_%H:%M")
  $new_snapshot_name = $snapshot_name_root + $time_stamp
  
  sub on_error: retry do  # sometimes volumes or snapshots are not ready so retry
    sleep(5)
    @vol_snapshot = @server_volume.volume_snapshots().create(name: $new_snapshot_name)
  end
  
  call get_current_snapshots_list(@server_volume) retrieve $current_snapshots
end

define schedule_volume_snapshots(@server_volume, $param_snapshot_schedule) return $current_snapshots do
  # Take a snapshot
  call create_volume_snapshot(@server_volume) retrieve $current_snapshots
  
  # Schedule the snapshots based on the user-specified frequency
  rs_ss.scheduled_actions.create(
    execution_id:       @@execution.id,
    name:               "Recurring Snapshot",
    action:             "run",
    operation:          { "name": "create_snapshot" },
    first_occurrence:   now(),
    recurrence:         "FREQ="+$param_snapshot_schedule
  )
end

define delete_volume_snapshot(@server_volume, $param_snapshot_name) return $current_snapshots do
  sub on_error: retry do  # sometime volumes or snapshots are not ready so retry
    sleep(5)
    @vol_snapshot = @server_volume.volume_snapshots(filter: ["name=="+$param_snapshot_name])
    @vol_snapshot.destroy()
  end
  
  call get_current_snapshots_list(@server_volume) retrieve $current_snapshots
end

define get_current_snapshots_list(@vol) return $current_snapshots do
  @current_snapshots = @vol.volume_snapshots()
  $current_snapshots = ""
  foreach $snapshot_name in @current_snapshots.name[] do
    if $current_snapshots == ""
      $current_snapshots = $snapshot_name
    else
      $current_snapshots = $current_snapshots + "   " + $snapshot_name
    end
  end

  if $current_snapshots == ""
    $current_snapshots = "No snapshots exist at this time."
  end
end

define restore_from_snapshot(@web_server, $param_snapshot_name, $map_cloud) do
  # create/attach snapshot as volume on restore_disk map value
  @instance = @web_server.current_instance()
  @cloud = @instance.cloud()
  @vol_snapshot = @cloud.volume_snapshots(filter: ["name=="+$param_snapshot_name])
  $snapshot_href = @vol_snapshot.href
  
  call figure_out_location(@cloud, $map_cloud) retrieve $param_location
  
  $vol_create_hash = {
    name: @web_server.name+"-restore-vol",
    parent_volume_snapshot_href: $snapshot_href,
    size: 1
  }
  if $param_location == "AzureRM"
    $vol_create_hash["placement_group_href"] = map($map_cloud, $param_location, "pg_href")
  else
    $vol_create_hash["datacenter_href"] = map($map_cloud, $param_location, "zone_href")
  end
  
  @vol = @cloud.volumes().create(volume: $vol_create_hash)
  
  @vol_attach = @instance.volume_attachments().create(volume_attachment: {
    device: map($map_cloud, $param_location, "restore_vol_device"),
    instance_href: @instance.href,
    settings: {delete_on_termination: true},
    volume_href: @vol.href
    })
  
  # run rightscript that
  #  mounts drive /restore/www
  #  rsyncs to existing /data/www
  #  unmounts drive
  $inp = {
      DISK_DEVICE: "text:"+map($map_cloud, $param_location, "restore_disk_device")
  }
  call run_script(@web_server, "Restore HTML From Volume",  $inp)
    
  # detach and delete the volume
  sub on_error: retry do
    sleep(5)
    @vol_attach.destroy(force: true)
  end

  sleep_until(@vol.status == "available")
  
  sub on_error: retry do
    sleep(5)
    @vol.destroy()
  end
end


# Use this bit of logic to avoid presenting location option to use when restoring
define figure_out_location(@cloud, $map_cloud) return $location do
  $location = "AWS"
  $cloud_name = @cloud.name
  if $cloud_name == map($map_cloud, "AzureRM", "cloud")
    $location = "AzureRM"
  elsif $cloud_name == map($map_cloud, "Google", "cloud")
    $location = "Google"
  end
end
  
#
# Helper function to get the server link
# 
define get_server_link(@server) return $server_link do
  # Make sure the IP address is seen before trying to get it
  sleep_until(@server.current_instance().public_ip_addresses[0])
  $server_link = "http://"+@server.current_instance().public_ip_addresses[0]
end

### UPDATE WEB PAGE ###
define update_web_page(@web_server, $param_page_text, $param_page_title, $param_page_color) do
  task_label("Update Web Page")
  
  # Prepare the input hash
  $inp = {PAGE_TEXT: "text:"+$param_page_text, 
    PAGE_TITLE: "text:"+$param_page_title,
    PAGE_COLOR: "text:"+$param_page_color
  }
    
  # Update the server level inputs with the updated webtext.
  call update_servers_inputs(@web_server, $inp)
  
  # Call a function to run the rightscript that updates the webtext.
  # See the cat_training_lib_helper_functions.cat.rb for this function
  call run_script(@web_server, "Modify Web Page",  $inp)
end

# Helper function to run rightscript
define run_script(@servers, $script_name, $inputs_hash) do
  task_label("In run_script")
  @script = rs_cm.right_scripts.get(filter: [ join(["name==",$script_name]) ])
  $right_script_href=@script.href
  foreach @server in @servers do
    @task = @server.current_instance().run_executable(right_script_href: $right_script_href, inputs: $inputs_hash)
    if equals?(@task.summary, "/^failed/")
      raise "Failed to run " + $right_script_href + "."
    end
  end
end

define run_script_noinputs(@servers, $script_name) do
  task_label("In run_script")
  @script = rs_cm.right_scripts.get(filter: [ join(["name==",$script_name]) ])
  $right_script_href=@script.href
  foreach @server in @servers do
    @task = @server.current_instance().run_executable(right_script_href: $right_script_href)
    if equals?(@task.summary, "/^failed/")
      raise "Failed to run " + $right_script_href + "."
    end
  end
end

#
# Helper function to update the server inputs
# 
define update_servers_inputs(@servers, $input_hash) do
  @servers.current_instance().multi_update_inputs(inputs: $inp)
end


### SLACK CHANNEL INTEGRATION
define notify_slack($channel, $message) do
  task_label("Notifying Slack.")
  $slack_channel_hook = cred("SLACK_CAT-DEMO-BOT_Channel-hook")
  # Send the message to slack
  $response = http_post(
    url: $slack_channel_hook,
    body: { channel: $channel, text: $message} )
end


################
# MAPPINGS     #
################

mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-west-2",
    "zone" => "us-west-2c", 
    "zone_href" => "/api/clouds/6/datacenters/8O7VCSP1D5D2E",
    "instance_type" => "m3.medium",
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "network" => null,
    "subnet" => null,
    "mci_mapping" => "Public",
    "tag_prefix" => "ec2",
    "vol_type_href" => "/api/clouds/6/volume_types/A09NIP4AOK9S7", # standard
    "vol_device" => "/dev/sdf",
    "restore_vol_device" => "/dev/sdg",
    "disk_device" => "/dev/xvdf",
    "restore_disk_device" => "/dev/xvdg",
    "pg_href" => null
  },
  "AzureRM" => {   
    "cloud" => "AzureRM East US",
    "zone" => null,
    "zone_href" => null,
    "instance_type" => "D1",
    "sg" =>  "@sec_group", 
    "ssh_key" => null,
    "network" => "pft_arm_network",
    "subnet" => "default",
    "mci_mapping" => "Public",
    "tag_prefix" => "azure",
    "vol_type_href" => null,
    "vol_device" => "01",
    "restore_vol_device" => "02",
    "disk_device" => "/dev/sdc",
    "restore_disk_device" => "/dev/sdd",
    "pg_href" => "/api/placement_groups/7MD8QAPR818CE"
  },
  "Google" => {
    "cloud" => "Google",
    "zone" => "us-central1-c", # launches in Google require a zone
    "zone_href" => "/api/clouds/2175/datacenters/DPA1NPABU1JFU",
    "instance_type" => "n1-standard-2",
    "sg" => '@sec_group',  
    "ssh_key" => null,
    "network" => null,
    "subnet" => null,
    "mci_mapping" => "Public",
    "tag_prefix" => "google",
    "vol_type_href" => "/api/clouds/2175/volume_types/A77J97T91D9KU", # pd-standard
    "vol_device" => "persistent-disk-1",
    "restore_vol_device" => "persistent-disk-2",
    "disk_device" => "/dev/sdb",
    "restore_disk_device" => "/dev/sdc",
    "pg_href" => null
  }
}
end

mapping "map_costcenter2namepart" do {
  "Development" => {
    "name_part" => "dev"
  },
  "QA" => {
    "name_part" => "qa"
  },
  "Production" => {
    "name_part" => "prod"
  }
} end

mapping "map_config" do
  like $linux_server_declarations.map_config
end

mapping "map_instancetype" do 
  like $mappings.map_instancetype
end

##################
# CONDITIONS     #
##################

# Used to decide whether or not to pass an SSH key or security group when creating the servers.
condition "needsSshKey" do
  like $conditions.needsSshKey
end

condition "needsSecurityGroup" do
  like $conditions.needsSecurityGroup
end

condition "needsPlacementGroup" do
  like $conditions.needsPlacementGroup
end

condition "invSphere" do
  like $conditions.invSphere
end

condition "notInVsphere" do
  logic_not($invSphere)
end

condition "inAzure" do
  like $conditions.inAzure
end 

condition "inAzureRM" do
  like $conditions.inAzureRM
end 