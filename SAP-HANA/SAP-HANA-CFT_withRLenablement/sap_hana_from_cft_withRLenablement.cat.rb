name "SAP-HANA - Launched by CFT and RightLink Enabled"
rs_ca_ver 20161221
short_description  "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/SAP-Hana-Logo.png)

SAP-HANA Stack launched by CFT and then RightLink enabled."

import "cft/sap_hana_newvpc"
import "pft/err_utilities", as: "debug"
import "rl_enable/aws", as: "rl_enable"

import "plugins/rs_aws_cft"

output "output_bastion_ip" do
  label "Bastion Server IP Address"
end

output "output_hana_master_ip" do
  label "SAP HANA Master Server IP Address"
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

operation "enable" do
  definition "post_launch"
  output_mappings do {
    $output_bastion_ip => $bastion_ip,
    $output_hana_master_ip => $hana_master_ip
  } end
end

operation "terminate" do
  definition "terminator"
end

operation "stop" do
  definition "stopper"
end

operation "start" do
  definition "starter"
end

# Now RightLink enable each of the instances that make up the SAP-HANA stack - including the Bastion node.
# The SAP-HANA nodes can be found based on the placement group
define post_launch(@placement_group) return $bastion_ip, $hana_master_ip do
  call gather_cluster_instances(@placement_group) retrieve @cluster_instances
  # Now that we have the collection of instances, let's get them RightLink Enabled 
  call rl_enable.rightlink_enable(@cluster_instances, "SAP-HANA Wrapper", "PFT_RS_REFRESH_TOKEN")
  
  @bastion_server = rs_cm.servers.get(filter: ["deployment_href=="+@@deployment.href, "name==Bastion"])
  $bastion_ip = @bastion_server.current_instance().public_ip_addresses[0]
  @hana_master_server = rs_cm.servers.get(filter: ["deployment_href=="+@@deployment.href, "name==Master"])
  $hana_master_ip = @hana_master_server.current_instance().private_ip_addresses[0]

  # This is an expensive CAT to run - these SAP-HANA nodes are not cheap.
  # So in the interest of being cost conscious in our demo environment, 
  # I automatically stop the CAT after 2 hours after initial launch.
  $time = now() + 7200 # seconds
  rs_ss.scheduled_actions.create(
    execution_id: @@execution.id,
    action: "stop",
    first_occurrence: $time
  )
end

# Coordinate termination of the now existent servers
# The stack, placement group, etc will be terminated automatically once this returns.
define terminator() do
  # Concurrently terminate all the servers
  concurrent foreach @server in @@deployment.servers() do
    delete(@server)
  end
end

define stopper() do
  @instances = @@deployment.servers().current_instance()
  call rl_enable.stop_instances(@instances) retrieve @stopped_instances
end

define starter() do
  @instances = @@deployment.servers().current_instance()
  call rl_enable.start_instances(@instances) 
  
  # This is an expensive CAT to run - these SAP-HANA nodes are not cheap.
  # So in the interest of demoing, once started, the CAT automatically stops after 2 hours.
  $time = now() + 7200 # seconds
  rs_ss.scheduled_actions.create(
    execution_id: @@execution.id,
    action: "stop",
    first_occurrence: $time
  )
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

parameter "installrdpinstance" do
  like $sap_hana_newvpc.installrdpinstance
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