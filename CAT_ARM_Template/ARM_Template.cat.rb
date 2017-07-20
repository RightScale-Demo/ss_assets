# CAT that launches an ARM template and RightLink Enables the VM(s).
# ARM Template Details:
#   Simple single VM proof of concept.
#
# RightScale Account Prerequisites:
#   ARM account: An ARM account needs to be connected to the RightScale account.
#   Service Principal: A service principal needs to exist for the given ARM subscription and the password for that service principal must be available.
#   The following CREDENTIALS need to be defined in the RightScale account. (Cloud Management: Design -> Credentials)
#     ARM_DOMAIN_NAME: The domain name for the ARM account connected to the RightScale account. This will be the first part of the onmicrosoft.com AD domain name.
#     ARM_PFT_APPLICATION_ID: The "APP ID" for the Service Principal being used.
#     ARM_PFT_APPLICATION_PASSWORD: The password created for the Service Principal being used.
#     ARM_PFT_SUBSCRIPTION_ID: The subscription ID for the ARM account connected to the given RightScale account. Can be found in Settings -> Clouds -> select an ARM cloud
#     RL_ENABLEMENT_TOKEN: The Refresh Token to use when doing RightLink enablement.
#   ServerTemplate to use for RightLink enablement. (Update the mapping below to point at this ST's HREF.)
#
# Caveats:
#   It is a bit fragile in that the RL enablement that is run as part of the ARM template occasionally hits a race condition related
#     to networking. The right answer is to actually have the CAT orchestrate the RL enablement instead of leaving it to the 
#     the ARM custom script extension logic.

name 'Launch ARM Template'
rs_ca_ver 20160622
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/azure.png)

Launch ARM Template and RightLink enable the VM(s)."
long_description "Uses an ARM template to launch a stack and then RightLink enables the VMs."


import "arm/api_common"
import "arm/api_template"
import "arm/extensions"
import "arm/support"
import "arm/template", as: "template"
import "pft/err_utilities", as: "err"
import "pft/server_templates_utilities"


# User launch time inputs
parameter "param_arm_template" do
  category "User Inputs"
  label "ARM Template Name" 
  type "string" 
  description "Name of ARM Template to launch." 
  default "Base Ubuntu VM"
  allowed_values "Base Ubuntu VM"
end

parameter "param_ubuntu_version" do
  category "User Inputs"
  label "Ubuntu Version" 
  type "string" 
  description "Version of Unbuntu to use for scale set VMs." 
  default "16.04.0-LTS"
  allowed_values "12.04.5-LTS", "14.04.5-LTS", "15.10", "16.04.0-LTS"
end

parameter "param_server_username" do
  category "User Inputs"
  label "Server Username" 
  type "string" 
  description "Username to configure server(s)." 
  default "ubuntu"
  allowed_pattern '^[a-zA-Z]+[a-zA-Z0-9\_]*$'
  constraint_description "Must start with a letter and then can be any combination of letters, numerals or \"_\""
end

parameter "param_server_password" do
  category "User Inputs"
  label "Server Password" 
  type "string" 
  description "Password to configure on the server(s)." 
  allowed_pattern '^(?:(?=.*[a-z])(?:(?=.*[A-Z])(?=.*[\d\W])|(?=.*\W)(?=.*\d))|(?=.*\W)(?=.*[A-Z])(?=.*\d)).{6,72}$'
  constraint_description "Must be 6-72 characters and have at least 3 of: uppercase, lowercase, numeral, special character."
  no_echo true
end

#  Mappings
mapping "map_param_arm_template_name" do {
  "Base Ubuntu VM" => {
    "arm_template_uri" => "https://raw.githubusercontent.com/rs-services/rs-premium_free_trial/master/artifacts/ARM_templates/vm-simple-linux-rlenablement.arm.json",
    "servertemplate_name" => "RightLink 10.6.0 Linux Base"
  },
} end

# Outputs
output "output_server_dns_name" do
  label "Server DNS Name"
  category "ARM Server Info"
  description "Server DNS Name"
end

output "output_server_ip_address" do
  label "Server IP Address"
  category "ARM Server Info"
  description "Server IP Address"
end

output "output_arm_template_link" do
  label "ARM Template Being Used"
  category "ARM Template Info"
  description "Link to the ARM Template."
end

# Operations
operation "launch" do 
  description "Launch the deployment based on ARM template."
  definition "arm_deployment_launch"
  output_mappings do {
    $output_arm_template_link => $arm_template_uri,
    $output_server_dns_name => $vm_dns_name, 
    $output_server_ip_address => $vm_ip_address
  } end
end

operation "terminate" do 
  description "Terminate the deployment"
  definition "arm_deployment_terminate"
end

define arm_deployment_launch($param_arm_template, $param_ubuntu_version, $param_server_username, $param_server_password, $map_param_arm_template_name) return $arm_template_uri, $vm_dns_name, $vm_ip_address do
  $param_resource_group = "default"
  # Get the properly formatted or specified info needed for the launch
  call get_launch_info($param_resource_group) retrieve $arm_deployment_name, $resource_group
  
  # Get an access token
  call api_common.get_access_token() retrieve $access_token
  
  # Create the resource group in which to place the deployment
  # if it already exists, no harm no foul
  $param_location = "North Central US"
  call api_common.create_resource_group($param_location, $resource_group, $tags_hash, $access_token)
  
  $refresh_token = cred("RL_ENABLEMENT_TOKEN") 
  $arm_template_uri = map($map_param_arm_template_name, $param_arm_template, "arm_template_uri")  
  $deployment_id = last(split(@@deployment.href, "/"))
  $vm_name = "MyVM"+$deployment_id
  
  # Get server template HREF
  call server_templates_utilities.find_st(map($map_param_arm_template_name, $param_arm_template, "servertemplate_name")) retrieve @desired_st
  $servertemplate_href = @desired_st.href  
  
  # Get the ARM subnet UUID to pass to the ARM template
  call support.get_arm_subnet_uuid($param_location) retrieve $arm_subnet_uuid
  
  # Build/get the ARM template to launch
  call template.build_arm_template_launch_body($vm_name, $arm_template_uri, $arm_subnet_uuid, $refresh_token, $servertemplate_href, $deployment_id, $param_ubuntu_version, $param_server_username, $param_server_password, $arm_deployment_name) retrieve $arm_template_launch_body

  # launch the ARM template
  call api_template.launch_arm_template($arm_template_launch_body, $resource_group, $arm_deployment_name, $access_token)
  
  call err.log("ARM template launch successful", "")
  
  # Get the launch status for some information
  call api_template.get_arm_template_status($resource_group, $arm_deployment_name, $access_token) retrieve $status_response
  # The ARM template being used returns some outputs one of which is the DNS name of the VM. So let's show that to the user.
  $vm_dns_name = $status_response["body"]["properties"]["outputs"]["hostname"]["value"]
  
  # Wait for the VM to be seen in RS. Once seen, then run the custom script extension to RL enable the VM.
  @vm = rs_cm.instances.get(filter: ["name=="+$vm_name])
  while size(@vm) == 0 do
    sleep(15)
    @vm = rs_cm.instances.get(filter: ["name=="+$vm_name])
  end
  
  call err.log("Found ARM VM", to_s(@vm))
  
  # Now wait for it to progress from the pending state
  sleep_until(@vm.state != "pending")
  
  call err.log("ARM VM has progressed to state, "+@vm.state, "")

  # Now run the RL enablement custom script ....
  $vm_extension_name = "MyScript"+$deployment_id
  $settings = {
    "fileUris": ["https://rightlink.rightscale.com/rll/10/rightlink.enable.sh"],
    "commandToExecute": "./rightlink.enable.sh -l -k \""+$refresh_token+"\" -r \""+$servertemplate_href+"\" -c \"azure_v2\" -e \""+@@deployment.href+"\" -n `hostname`"
  }
  call extensions.run_arm_extension($vm_extension_name, $settings, $param_location, $resource_group, $vm_name, $access_token)

  # Wait until the extension runs successfully or fails
  call extensions.get_arm_extension_status($vm_extension_name, $resource_group, $vm_name, $access_token) retrieve $extension_status
  while $extension_status == "Creating" do
    sleep(15)
    call extensions.get_arm_extension_status($vm_extension_name, $resource_group, $vm_name, $access_token) retrieve $extension_status
  end
  
  call err.log("Final extension status received: "+$extension_status, "")
  
  if $extension_status == "Failed"
    call err.log("Failed to run RightLink Enablement script.", "")
  else
    sleep_until(@vm.state != "booting")
  end
  
  $vm_ip_address = @vm.public_ip_addresses[0]
end


define arm_deployment_terminate() do
  
  $param_resource_group = "default"
  call get_launch_info($param_resource_group) retrieve $arm_deployment_name, $resource_group
    
  # Get an access token
  call api_common.get_access_token() retrieve $access_token

  # At this time, since the template is launched in its own resource group, we'll just delete the resource group on termination
  call api_common.delete_resource_group($resource_group, $access_token)
  
  # Wait for the servers to shutdown due to the vm termination and then clean them up
  @servers_to_remove = @@deployment.servers()
  sleep_until(all?(@servers_to_remove.state[], "inactive"))
  @servers_to_remove.destroy()

end


define get_launch_info($param_resource_group) return $arm_deployment_name, $resource_group do
  # Use the created deployment name with out spaces and must be lowercase
  $arm_deployment_name = downcase(gsub(@@deployment.name, " ", ""))
  
  if equals?($param_resource_group, "default")
    $resource_group = $arm_deployment_name
  else
    $resource_group = $param_resource_group
  end
end


# Remove any extra servers that may have come into existence due to ARM launching more instances than needed.
define cleanup_servers($target_instance_count) do
   
  # Might have to wait a bit for the servers to reach a "keeper" state.
  # So loop through looking until enough keepers are found.
  $expected_instance_count = to_n($target_instance_count)
  @servers_to_remove = rs_cm.servers.empty()  # initialize
  $num_keepers_found = 0
  while $num_keepers_found < $expected_instance_count do
    @all_servers = @@deployment.servers()
    @servers_to_remove = @all_servers  # start by assuming we'll remove all
    $num_keepers_found = 0
    foreach @server in @all_servers do
      if @server.state == "operational" || @server.state == "stranded"
        if contains?(@servers_to_remove, @server) # get it out of there
          @servers_to_remove = @servers_to_remove - @server
          $num_keepers_found = $num_keepers_found + 1
        end
      end
    end
    
    if $num_keepers_found < $expected_instance_count
      sleep(30) # sleep a bit to give the server a chance to show up
    end
  end
  
  # Terminate and delete the unwanted servers
  @operational_servers = select(@servers_to_remove, {state: "operational"})
  @stranded_servers = select(@servers_to_remove, {state: "stranded"})
  @provisioned_servers = select(@servers_to_remove, {state: "provisioned"})
  @booting_servers = select(@servers_to_remove, {state: "booting"})
  @terminatable_servers = @operational_servers + @stranded_servers + @provisioned_servers + @booting_servers
  sub on_error: skip do  # skip on_error since sometimes it gets mad about stuff that will not matter in a minute when the server is destroyed.
    @terminatable_servers.current_instance().terminate()
  end
  
  sleep_until(all?(@servers_to_remove.state[], "inactive"))

  @servers_to_remove.destroy()

end

