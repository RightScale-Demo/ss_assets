name "SAP-HANA - Launched by CFT and RightLink Enabled"
rs_ca_ver 20161221
short_description  "SAP-HANA launched by CFT and then RightLink enabled."

import "cft/sap_hana_newvpc"
import "pft/err_utilities"

import "plugins/rs_aws_cft"


output "output_ip_address" do
  label "IP Address"
end

output "ssh_key" do
  label "SSH Key"
  default_value @ssh_key.name
end

### resource declarations ###
resource "ssh_key", type: "ssh_key" do
  like @sap_hana_newvpc.ssh_key
end

### placement declarations ###
resource "placement_group", type: "placement_group" do 
  like @sap_hana_newvpc.placement_group
end

#### CFT Stack Section ####
# Currently using the CFT that creates the VPCs, etc.
# TO-DO: Use the CFT that prompts for the VPCs, etc and/or create the VPCs, etc using CAT resource decalarations.
resource "stack", type: "rs_aws_cft.stack" do
  like @sap_hana_newvpc.stack
end

## Parameters being passed to CFT
parameter "vpccidr" do
  like $sap_hana_newvpc.vpccidr
end

parameter "hanainstallmedia" do
  like $sap_hana_newvpc.hanainstallmedia
end

parameter "availabilityzone" do
  like $sap_hana_newvpc.availabilityzone
end

parameter "autorecovery" do
  like $sap_hana_newvpc.autorecovery
end

parameter "encryption" do
  like $sap_hana_newvpc.encryption
end

parameter "dmzcidr" do
  like $sap_hana_newvpc.dmzcidr
end

parameter "privsubcidr" do
  like $sap_hana_newvpc.privsubcidr
end

parameter "remoteaccesscidr"  do
  like $sap_hana_newvpc.remoteaccesscidr
end

parameter "domainname"  do
  like $sap_hana_newvpc.domainname
end

parameter "hanamasterhostname" do
  like $sap_hana_newvpc.hanamasterhostname
end

parameter "hanaworkerhostname"  do
  like $sap_hana_newvpc.hanaworkerhostname
end

parameter "privatebucket" do
  like $sap_hana_newvpc.privatebucket
end

parameter "proxy" do
  like $sap_hana_newvpc.proxy
end

parameter "myos" do
  like $sap_hana_newvpc.myos
  allowed_values "RedHatLinux72"
end

parameter "myinstancetype"  do
  like $sap_hana_newvpc.myinstancetype
end

parameter "installhana"  do
  like $sap_hana_newvpc.installhana
end

parameter "hostcount"  do
  like $sap_hana_newvpc.hostcount
end

parameter "sid"  do
  like $sap_hana_newvpc.sid
end

parameter "sapinstancenum"  do
  like $sap_hana_newvpc.sapinstancenum
end

parameter "hanamasterpass"  do
  like $sap_hana_newvpc.hanamasterpass
end

parameter "volumetype"  do
  like $sap_hana_newvpc.volumetype
end

operation "enable" do
  definition "post_launch"
end

operation "terminate" do
  definition "terminator"
end

# Now RightLink enable each of the instances that make up the SAP-HANA stack - including the Bastion node.
# The SAP-HANA nodes can be found based on the placement group
define post_launch(@placement_group)  do
  
  call gather_cluster_instances(@placement_group) retrieve @cluster_instances
  
  # Now that we have the collection of instances, let's get them RightLink Enabled 
  call rightlink_enable(@cluster_instances)
end

# coordinate termination
define terminator(@stack, @placement_group) return @stack, @placement_group do
  
  call gather_cluster_instances(@placement_group) retrieve @instances
  
  delete(@stack)
  
  sleep_until all?(@instances.state[], "terminated")
    
  delete(@placement_group)
end

# Find the instances that are part of the SAP stack
define gather_cluster_instances(@placement_group) return @cluster_instances do

  # Get the cloud resource
  @cloud = @placement_group.cloud()
  
  # Find the SAP-HANA instances
  # They are all part of the same placement group.
  @sap_hana_instances = @cloud.instances(filter: ["placement_group_href=="+@placement_group.href], view: "extended")
  
  # Gather up networking data that will be used to identify the correct Bastion Server that is part of this system.
  @subnet = rs_cm.get(href: @sap_hana_instances.subnets[0]["href"])
  $network_href = @subnet.network().href
    
  # The Bastion server name is fixed by the off-the-shelf CFT. 
  # So this may return multiple instances - including terminated ones
  # So we need to find the one on the correct network.
  @bastion_instance = rs_cm.instances.empty()
  @instances = @cloud.instances(filter: ["name==Bastion Instance (Public Subnet)"], view: "extended")
  foreach @instance in @instances do
    if (@instance.state == "operational") 
      @instance_subnet = rs_cm.get(href: @instance.subnets[0]["href"])
      if (@instance_subnet.network().href == $network_href)
        @bastion_instance = @instance
      end
    end
  end
    
  @cluster_instances = @sap_hana_instances + @bastion_instance

end

# Orchestrate RightLink enablement of the instance.
define rightlink_enable(@instances) do
  
  # Record instance related data used to find the stopped instances later.
  $num_instances = size(@instances)
  $instance_uids = @instances.resource_uid[]
  @cloud = first(@instances.cloud())
 
  # Stop the instances
  @instances.stop()
  
  # Once the instances are stopped they get new HREFs ("next instance"), 
  # So, we need to so look for the instance check the state until stopped (i.e. provisioned)
  @stopped_instances = rs_cm.instances.empty()
  while size(@stopped_instances) != $num_instances do 
    # sleep a bit
    sleep(15)
  
    @stopped_instances = rs_cm.instances.empty()
    foreach $uid in $instance_uids do
      @instance = @cloud.instances(filter: ["resource_uid=="+$uid])
      if @instance.state == "provisioned"
        @stopped_instances = @stopped_instances + @instance
      end
    end
  end
      
  # Now install userdata that runs RL enablement code
  foreach @instance in @stopped_instances do
    call install_rl_installscript(@instance, "SAP-HANA Wrapper", @instance.name)
  end
  
  # Once the user-data is set, start the instance so RL enablement will be run
  call err_utilities.log("starting instances", to_s(to_object(@stopped_instances)))
  @stopped_instances.start()
    
  $wake_condition = "/^(operational|stranded|stranded in booting)$/"
  sleep_until all?(@stopped_instances.state[], $wake_condition)

end

# Uses EC2 ModifyInstanceAttribute API to install user data that runs RL enablement script
define install_rl_installscript(@instance, $server_template, $servername) do
  
  $instance_id = @instance.resource_uid # needed for the API URL
  call err_utilities.log("instance_id: "+$instance_id, "")

  # generate the user-data that runs the RL enablement script.
  call build_rl_enablement_userdata($server_template, $servername) retrieve $user_data
    
  # base64 encode the user-data since AWS requires that 
  $user_data_base64 = to_base64($user_data)  
  # Remove the newlines that to_base64() puts in the result
  $user_data_base64 = gsub($user_data_base64, "
","")
  # Replace any = with html code %3D so the URL is valid.
  $user_data_base64 = gsub($user_data_base64, /=/, "%3D")
  
  call err_utilities.log("encoded userdata", $user_data_base64)

  # Go tell AWS to update the user-data for the instance
  $url = "https://ec2.amazonaws.com/?Action=ModifyInstanceAttribute&InstanceId="+$instance_id+"&UserData.Value="+$user_data_base64+"&Version=2014-02-01"
  
  call err_utilities.log("url", $url)
  
  $signature = {
    "type":"aws",
    "access_key": cred("AWS_ACCESS_KEY_ID"),
    "secret_key": cred("AWS_SECRET_ACCESS_KEY")
    }
  $response = http_post(
    url: $url,
    signature: $signature
    )
    
   call err_utilities.log("AWS API response", to_s($response))
end

define build_rl_enablement_userdata($server_template_name, $server_name) return $user_data do
  
  # If you look at the RightScale docs, you'll see this line has a sudo before bash, but it's not used here.
  # Since cloud-init runs as root and since the sudo in there may throw the "tty" error, it's really not needed.
  $rl_enablement_cmd = 'curl -s https://rightlink.rightscale.com/rll/10/rightlink.enable.sh | bash -s -- -k "'+cred("RS_REFRESH_TOKEN")+'" -t "'+$server_template_name+'" -n "'+$server_name+'" -d "'+@@deployment.name+'" -c "amazon"'

  # This sets things up so the script runs on start.
  # Note that the RL enablement script is given a name that should ensure it runs first.
  # This is important if there are other scripts already on the server.
  $user_data = 'Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0
  
--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="aaa_rlenable.sh"

#!/bin/bash
'+$rl_enablement_cmd+'
--//'
  

end