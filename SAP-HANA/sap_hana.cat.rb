#
# REFERENCES:
#   CFT this CAT was intended to be based on: http://docs.aws.amazon.com/quickstart/latest/sap-hana/welcome.html
#     
# PREREQUISITES
# Login to AWS Console to accept Terms and Conditions for using the AMI.
#   https://aws.amazon.com/marketplace/fulfillment?pricing=hourly&productId=2f28c0e5-af3e-4d22-95f1-6c1af645c209&ref_=dtl_psb_continue&region=us-east-1&versionTitle=v20170121
# Setup ServerTemplates As Follows
#     Clone RL10 Base Linux ST
#       Name it: SAP-Hana Master Node
#     Modify Boot Sequence as follows:
#       Remove NTP - not SUSE compatible code and not really needed)
#       Remove RedHat Subscription Register - just because you're tinkering with the ST anyway
#       Remove Setup Automatic Upgrade - again just because
#     Clone the SAP-Hana Master Node
#       Name it: SAP-Hana Worker Node
#      
# TO-DOs:
#   Add applicable configuration scripts to the Master and Worker node ServerTemplates to configure them accordingly. 

name "SAP-HANA CAT"
rs_ca_ver 20161221
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/SAP-Hana-Logo.png) 

Launch a SAP-HANA system."
long_description "Launches SAP-Hana master and worker nodes based on off-the-shelf SAP-Hana AMI."

import "sap_hana/security_groups"
import "sap_hana/mappings"
import "sap_hana/tagging"
import "pft/parameters"

parameter "param_location" do 
  like $parameters.param_location
  allowed_values "AWS" #, "AzureRM"  # ARM SAP image is RHEL based image and in ARM RHEL doesn't have cloud-init so install-at-boot doesn't work
  default "AWS"
end

parameter "param_instancetype" do
  like $parameters.param_instancetype
end

parameter "param_numservers" do
  like $parameters.param_numservers
  label "Number of Worker Nodes"
end

parameter "param_bc" do 
  like $tagging.param_bc
end

parameter "param_env" do 
  like $tagging.param_env
end

parameter "param_proj" do 
  like $tagging.param_proj
end

output_set "master_public_ips" do
  label "Master Server IP"
  category "Output"
  description "IP address for the master server."
  default_value @saphana_master.public_ip_address
end

output_set "workers_public_ips" do
  label "Worker Server IP"
  category "Output"
  description "IP address for the worker server."
  default_value @saphana_workers.public_ip_address
end

resource 'saphana_master', type: 'server' do
  name join(["hanamaster-", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  network map($map_cloud, $param_location, "network")
  subnets [ map($map_cloud, $param_location, "subnet") ]
  security_group_hrefs map($map_cloud, $param_location, "sg")  
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  server_template find('SAP-Hana Master Node', revision: 0) 
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  
  # FORCE the image to use the applicable image. This is somewhat unorthodox and a warning will be seen in Cloud Management 
  # for the server. But it saves the bother of creating an MultiCloud Image that points to the right image.
  # So maintenance is easier. To use a different image simply change the mapping package file.
  image find(resource_uid: map($map_image, $param_location, "resource_uid")) 
    
  inputs do {
    'MONITORING_METHOD' => 'text:rightlink',
  } end
end

resource "saphana_workers", type: "server", copies: $param_numservers do
  like @saphana_master
  name join(['hanaworker-',last(split(@@deployment.href,"/")), "-", copy_index()])
  server_template find('SAP-Hana Worker Node', revision: 0)
  inputs do {
    'MONITORING_METHOD' => 'text:rightlink',
  } end
end

operation "enable" do
  description "Post launch orchestration"
  definition "enable"
end

define enable($param_bc, $param_env, $param_proj) do
  call tagging.deployment_resources_tagger($param_bc, $param_env, $param_proj)
end 

### SSH key declarations ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, "AWS", "cloud")
end

mapping "map_cloud" do 
  like $mappings.map_cloud
end

mapping "map_image" do 
  like $mappings.map_image
end

mapping "map_instancetype" do 
  like $mappings.map_instancetype
end

resource "sec_group", type: "security_group" do
  like @security_groups.sec_group
end

resource "sec_group_rule_all_inbound_tcp", type: "security_group_rule" do
  like @security_groups.sec_group_rule_all_inbound_tcp
end

resource "sec_group_rule_udp111", type: "security_group_rule" do
  like @security_groups.sec_group_rule_udp111
end

resource "sec_group_rule_udp2049", type: "security_group_rule" do
  like @security_groups.sec_group_rule_udp2049
end

resource "sec_group_rule_udp400x", type: "security_group_rule" do
  like @security_groups.sec_group_rule_udp400x
end


