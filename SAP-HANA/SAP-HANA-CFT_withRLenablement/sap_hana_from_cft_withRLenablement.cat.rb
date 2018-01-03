name "SAP-HANA - Launched by CFT and RightLink Enabled"
rs_ca_ver 20161221
short_description  "SAP-HANA launched by CFT and then RightLink enabled."

import "cft/sap_hana_newvpc"
import "pft/err_utilities", as: "debug"
import "rl_enable/aws", as: "rl_enable"

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
  call rl_enable.rightlink_enable(@cluster_instances, "SAP-HANA Wrapper")
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