#Copyright 2016 RightScale
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

#RightScale Cloud Application Template (CAT)
#x
# DESCRIPTION
# Deploys a basic 3-Tier LAMP Stack.
#
# FEATURES
# User can select cloud at launch.
# User can use a post-launch action to install a different version of the application software from a Git repo.


name 'FW LAMP Stack'
rs_ca_ver 20160622
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/lamp_icon.png)

Launches a 3-tier LAMP stack. Cool!"
long_description "Launches a 3-tier LAMP stack.\n
Clouds Supported: <B>AWS, AzureRM, Google, VMware</B>"

import "pft/parameters"
import "pft/rl10/lamp_parameters", as: "lamp_parameters"
import "pft/rl10/lamp_outputs", as: "lamp_outputs"
import "pft/mappings"
import "pft/rl10/lamp_mappings", as: "lamp_mappings"
import "pft/conditions"
import "pft/resources"
import "pft/rl10/lamp_resources", as: "lamp_resources"
import "pft/server_templates_utilities"
import "pft/server_array_utilities"
import "pft/rl10/fw_lamp_utilities", as: "lamp_utilities"
import "pft/err_utilities", as: "functions"
import "pft/permissions"
 
##################
# Permissions    #
##################
permission "pft_general_permissions" do
  like $permissions.pft_general_permissions
end

permission "pft_sensitive_views" do
  like $permissions.pft_sensitive_views
end

##################
# User inputs    #
##################
parameter "param_location" do
  like $parameters.param_location
end

parameter "param_ha" do
  category "Deployment Options"
  label "Application SLA"
  type "list"
  allowed_values "HA (Duplex)",
    "Simplex"
  default "Simplex"
end

condition "isHA" do
  equals?($param_ha, "HA (Duplex)")
end

parameter "param_instancetype" do
  category "Deployment Options"
  label "Server Performance Level"
  type "list"
  allowed_values "Standard Performance",
    "High Performance"
  default "Standard Performance"
end

parameter "param_access_cidr" do
  category "Deployment Options"
  label "Source Access Network"
  type "string"
  default "0.0.0.0/0"
  allowed_pattern '^([0-9]{1,3}\.){3}[0-9]{1,3}\/([0-9]|[1-2][0-9]|3[0-2])$'
  constraint_description "Must be CIDR notation: a.b.c.d/e"
end

parameter "param_num_scaleout" do 
  category "Scaling Settings"
  label "Number of Servers to Scale Out" 
  type "number" 
  min_value 1
  max_value 4
  constraint_description "Maximum of 4 servers allowed to be scaled at a time."
  default 1
end

parameter "param_num_scalein" do 
  category "Scaling Settings"
  label "Number of Servers to Scale In" 
  type "number" 
  default 1
end


parameter "param_costcenter" do
  like $parameters.param_costcenter
end

# Commented out until the install_appcode definition is updated
parameter "param_appcode_repo" do 
  category "Application Code"
  label "Repository" 
  description "Github repo where code resides."
  type "string" 
  allowed_values "github.com/rightscale/examples", "github.com/rs-services/rs-premium_free_trial"
  default "github.com/rs-services/rs-premium_free_trial"
  operations "update_app_code"
end

parameter "param_appcode_branch" do 
  category "Application Code"
  label "Branch" 
  description "Repo branch to use. Example unified_php, unified_php_modified"
  type "string" 
  default "unified_php_modified"
  operations "update_app_code"
end

parameter "param_chef_password" do
  like $lamp_parameters.param_chef_password
  operations "launch"
end

parameter "param_snapshot_name" do
  label "Delete Backup"
  description "Enter a snapshot name to delete."
  type "string"
  operations "delete_snapshot"
end



################################
# Outputs returned to the user #
################################
output "site_url" do
  like $lamp_outputs.site_url
end

output "lb_status" do
  like $lamp_outputs.lb_status
end

#output "app1_github_link" do
#  like $lamp_outputs.app1_github_link
#end

#output "app2_github_link" do
#  like $lamp_outputs.app2_github_link
#end

output "output_snapshots" do
  label "Current List of DB backups"
  category "Backups Information"
  description "List of DB backups."
  default_value "No backups created yet."
end


##############
# MAPPINGS   #
##############

# Mapping and abstraction of cloud-related items.
mapping "map_cloud" do
  like $mappings.map_cloud
end

# Mapping of which ServerTemplates and Revisions to use for each tier.
mapping "map_st" do
  like $lamp_mappings.map_st
end

mapping "map_mci" do
  like $lamp_mappings.map_mci
end

# Mapping of names of the creds to use for the DB-related credential items.
# Allows for easier maintenance down the road if needed.
mapping "map_db_creds" do
  like $lamp_mappings.map_db_creds
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

condition "inAzure" do
  like $conditions.inAzure
end


############################
# RESOURCE DEFINITIONS     #
############################

### Server Declarations ###
resource 'chef_server', type: 'server' do
  like @lamp_resources.chef_server
end

resource 'lb_server', type: 'server' do
  like @lamp_resources.lb_server
  instance_type map($map_instancetype, $param_instancetype, $param_location)
end

resource 'db_server', type: 'server' do
  like @lamp_resources.db_server
  name join(['DB-1-',last(split(@@deployment.href,"/"))])
  instance_type map($map_instancetype, $param_instancetype, $param_location)
end

resource 'db_server_2', type: 'server' do
  like @lamp_resources.db_server
  name join(['DB-2-',last(split(@@deployment.href,"/"))])
  instance_type map($map_instancetype, $param_instancetype, $param_location)
end

resource 'app_server', type: 'server_array' do
  like @lamp_resources.app_server
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  inputs do {
    'APPLICATION_NAME' => join(['text:pft_',last(split(@@deployment.href,"/"))]),
    'APPLICATION_ROOT_PATH' => 'text:pft',
    'BIND_NETWORK_INTERFACE' => 'text:private',
    'CHEF_ENVIRONMENT' => 'text:_default',
    'CHEF_SERVER_SSL_CERT' => 'cred:PFT_LAMP_ChefCert',
    'CHEF_SERVER_URL' => 'cred:PFT_LAMP_ChefUrl',
    'CHEF_VALIDATION_KEY' => 'cred:PFT_LAMP_ChefValidator',
    'CHEF_VALIDATION_NAME' => 'text:pft-validator',
    'CHEF_SSL_VERIFY_MODE' => 'text::verify_none',
    'DATABASE_HOST' => join(['env:DB-1-',last(split(@@deployment.href,"/")),':PRIVATE_IP']),
    'DATABASE_PASSWORD' => 'cred:CAT_MYSQL_APP_PASSWORD',
    'DATABASE_SCHEMA' => 'text:app_test',
    'DATABASE_USER' => 'cred:CAT_MYSQL_APP_USERNAME',
    'DELETE_NODE_ON_TERMINATE' => 'text:true',
    'ENABLE_AUTO_UPGRADE' => 'text:true',
    'LISTEN_PORT' => 'text:8080',
    'LOG_LEVEL' => 'text::info',
    'MANAGED_LOGIN' => 'text:auto',
    'MONITORING_METHOD' => 'text:auto',
    'REFRESH_TOKEN' => 'cred:PFT_RS_REFRESH_TOKEN',
    'SCM_REPOSITORY' => 'text:git://github.com/rightscale/examples.git',
    'SCM_REVISION' => 'text:unified_php',
    'UPGRADES_FILE_LOCATION' => 'text:https://rightlink.rightscale.com/rightlink/upgrades',
    'VHOST_PATH' => 'text:/'
  } end
  elasticity_params do {
    "bounds" => {
      "min_count"            => switch($isHA, 2, 1),
      "max_count"            => 10 
    },
    "pacing" => {
      "resize_calm_time"     => 10,
      "resize_down_by"       => 1,
      "resize_up_by"         => 1
    },
    "alert_specific_params" => {
      "decision_threshold"   => 51,
      "voters_tag_predicate" => join(['App-',last(split(@@deployment.href,"/"))])
    }
  } end

end

## TO-DO: Set up separate security groups for each tier with rules that allow the applicable port(s) only from the IP of the given tier server(s)
resource "sec_group", type: "security_group" do
  like @lamp_resources.sec_group
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_ssh
  cidr_ips $param_access_cidr
end

resource "sec_group_rule_https", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_https
end

resource "sec_group_rule_http", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_http
  cidr_ips $param_access_cidr
end

resource "sec_group_rule_http8080", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_http8080
end

resource "sec_group_rule_mysql", type: "security_group_rule" do
  like @lamp_resources.sec_group_rule_mysql
end

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  like @resources.ssh_key
end

### Placement Group ###
resource "placement_group", type: "placement_group" do
  like @resources.placement_group
end

##################
# Permissions    #
##################
permission "import_servertemplates" do
  like $server_templates_utilities.import_servertemplates
end

####################
# OPERATIONS       #
####################
operation "launch" do
  description "Concurrently launch the servers"
  definition "lamp_utilities.launcher"
  output_mappings do {
    $site_url => $site_link,
    $lb_status => $lb_status_link,
  } end
end

operation "enable" do
  condition $isHA
  definition "post_launch"
end

operation "terminate" do
  description "Clean up a few unique items"
  definition "lamp_utilities.delete_resources"
end

# Commented out until the install_appcode definition is updated
operation "update_app_code" do
  label "Update Application Code"
  description "Select and install a different repo and branch of code."
  definition "lamp_utilities.install_appcode"
end

operation "scale_out" do
  label "Scale Out"
  description "Adds (scales out) an application tier server."
  definition "scale_out_array"
end

operation "scale_in" do
  label "Scale In"
  description "Scales in an application tier server."
  definition "scale_in_array"
end

operation "create_snapshot" do
#  condition $hasVolume
  label "Create DB snapshot"
  definition "create_volume_snapshot"
  output_mappings do {
    $output_snapshots => $current_snapshots
  } end
end

operation "delete_snapshot" do
#  condition $hasVolume
  label "Delete DB snapshot"
  definition "delete_volume_snapshot"
  output_mappings do {
    $output_snapshots => $current_snapshots
  } end
end

#
# Volume operations
#
define create_volume_snapshot(@db_server) return $current_snapshots do
  $snapshot_name_root = @db_server.name + "-snapshot-"
  $time_stamp = strftime(now(), "%Y-%m-%d_%H:%M")
  $new_snapshot_name = $snapshot_name_root + $time_stamp
  
  @vol = rs_cm.volumes.empty()
  sub on_error: retry do  # sometimes volumes or snapshots are not ready so retry
    sleep(5)
    @vol = @db_server.current_instance().volume_attachments().volume()
    @vol_snapshot = @vol.volume_snapshots().create(name: $new_snapshot_name)
  end
  
  call get_current_snapshots_list(@vol) retrieve $current_snapshots
end

define delete_volume_snapshot(@db_server, $param_snapshot_name) return $current_snapshots do
  @vol = rs_cm.volumes.empty()
  sub on_error: retry do  # sometime volumes or snapshots are not ready so retry
    sleep(5)
    @vol = @db_server.current_instance().volume_attachments().volume()
    @vol_snapshot = @vol.volume_snapshots(filter: ["name=="+$param_snapshot_name])
    @vol_snapshot.destroy()
  end
  
  call get_current_snapshots_list(@vol) retrieve $current_snapshots
end

define get_current_snapshots_list(@vol) return $current_snapshots do
  @current_snapshots = @vol.volume_snapshots()
  $current_snapshots = ""
  foreach $snapshot_name in @current_snapshots.name[] do
    if $current_snapshots == ""
      $current_snapshots = $snapshot_name
    else
      $current_snapshots = $current_snapshots + "; " + $snapshot_name
    end
  end

  if $current_snapshots == ""
    $current_snapshots = "No snapshots exist at this time."
  end
end



define post_launch(@db_server, @db_server_2) do
  # make one master and the other slave
  call server_templates_utilities.run_script_no_inputs(@db_server, "Mysql Server Master - chef")
  call server_templates_utilities.run_script_no_inputs(@db_server_2, "Mysql Server Slave - chef")
  
  # Get a starting DB set up in the master (and automatically replicated to the slave)
  call server_templates_utilities.run_script_no_inputs(@db_server, "PFT RL10 Dump Import")
end

  


# Scale out (add) server
define scale_out_array(@app_server, $param_num_scaleout) do
  task_label("Scale out application server.")
  $index = 0
  while $index < $param_num_scaleout do
    @task = @app_server.launch()
    sleep(30)
    $index = $index + 1
  end

  $wake_condition = "/^(operational|stranded|stranded in booting|stopped|terminated|inactive|error)$/"
  sleep_until all?(@app_server.current_instances().state[], $wake_condition)
  if !all?(@app_server.current_instances().state[], "operational")
    raise "Some instances failed to start"    
  end
     
  call apply_costcenter_tag(@app_server)

end

# Scale in (remove) server
define scale_in_array(@app_server, $isHA, $param_num_scalein) do
  task_label("Scale in web server array.")
  
  $minimum_num_to_keep = switch($isHA, 2, 1)
  
  @terminable_servers = select(@app_server.current_instances(), {"state":"/^(operational|stranded)/"})
  $num_terminatable_servers = size(@terminable_servers)
  
  $num_to_terminate = $param_num_scalein
  $max_num_to_terminate = $num_terminatable_servers - $minimum_num_to_keep
  if $num_to_terminate > $max_num_to_terminate
    $num_to_terminate = $max_num_to_terminate
  end
  
  $num_to_keep = $num_terminatable_servers - $num_to_terminate
  
  while $num_terminatable_servers > $num_to_keep do
    # Terminate the oldest instance in the array.
    @server_to_terminate = first(@terminable_servers)
    @server_to_terminate.terminate()
    # Wait for the server to be no longer of this mortal coil
    sleep_until((@server_to_terminate.state != "operational" ) || (@server_to_terminate.state != "stranded"))
    
    @terminable_servers = select(@app_server.current_instances(), {"state":"/^(operational|stranded)/"})
    $num_terminatable_servers = size(@terminable_servers)
  end
  
end

# Apply the cost center tag to the server array instance(s)
define apply_costcenter_tag(@server_array) do
  # Get the tags for the first instance in the array
  $tags = rs_cm.tags.by_resource(resource_hrefs: [@server_array.current_instances().href[][0]])
  # Pull out only the tags bit from the response
  $tags_array = $tags[0][0]['tags']
    
  call functions.log("Tags found:", to_s($tags_array))

  # Loop through the tags from the existing instance and look for the costcenter tag
  $costcenter_tag = ""
  foreach $tag_item in $tags_array do
    $tag = $tag_item['name']
    if $tag =~ /costcenter/
      $costcenter_tag = $tag
    end
  end  

  # Now apply the costcenter tag to all the servers in the array - including the one that was just added as part of the scaling operation
  rs_cm.tags.multi_add(resource_hrefs: @server_array.current_instances().href[], tags: [$costcenter_tag])
end
