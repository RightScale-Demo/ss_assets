    name 'Two-Tier VPC with IGW and NAT-GW with MultiRegion'
rs_ca_ver 20161221
short_description "![Network](https://s3.amazonaws.com/rs-pft/cat-logos/private_network.png)\n
Creates a network with a public and private subnet with a single server in the public subnet and user-specified number of servers in the private subnet."
long_description "Creates a network with a public and private subnet with a single server in the public subnet and user-specified number of servers in the private subnet.\n
Creates the Internet Gateway for the public subnet and a NAT Gateway for the private subnet.\n
Creates the necessary routes for the public and private subnets and gateways.\n

Based on the use-case described here:\n
![NAT-GW](https://s3.amazonaws.com/rs-pft/cat-logos/nat-gateway-diagram.png)"

import "pft/err_utilities", as: "debug"
import "pft/mci"
import "pft/linux_server_declarations"
import "pft/mci/linux_mappings", as: "linux_mappings"
import "pft/resources", as: "common_resources"
import "pft/permissions"

import "sys_log"
import "plugin/rs_aws_vpc_ohio"
import "plugin/rs_aws_vpc_virginia"
import "plugin/rs_aws_vpc_oregon"
import "plugin/rs_aws_vpc_frankfurt"
import "plugin/rs_aws_vpc_ireland"
import "plugin/rs_aws_vpc_london"
import "plugin/rs_aws_vpc_paris"

### Mappings ###
mapping "map_cloud" do {
  "US East (Ohio) us-east-2" => {
    "cloud" => "us-east-2",
    "datacenter" => "us-east-2b", #"us-east-2a","us-east-2b"
    "ssh_key" => "@ssh_key",
    "subnet" => "@vpc_subnet.name",  # using .name since we need to use name for google
    "priv_subnet" => "@vpc_priv_subnet.name",  
    "gw" => "@vpc_igw",
    "tag_prefix" => "ec2",
    "aws_region" => "ohio",
  },
  "US East (N. Virginia) us-east-1" => {
      "cloud" => "us-east-1",
      "datacenter" => "us-east-1f", #, "us-east-1d", "us-east-1e"
      "ssh_key" => "@ssh_key",
      "subnet" => "@vpc_subnet.name",  # using .name since we need to use name for google
      "priv_subnet" => "@vpc_priv_subnet.name",
      "gw" => "@vpc_igw",
      "tag_prefix" => "ec2",
      "aws_region" => "virginia",
  },
  "US West (Oregon) us-west-2" => {
      "cloud" => "us-west-2",
      "datacenter" => "us-west-2c", #, "us-west-2b","us-west-2c"
      "ssh_key" => "@ssh_key",
      "subnet" => "@vpc_subnet.name",  # using .name since we need to use name for google
      "priv_subnet" => "@vpc_priv_subnet.name",
      "gw" => "@vpc_igw",
      "tag_prefix" => "ec2",
      "aws_region" => "oregon",
  },
  "EU (Frankfurt) eu-central-1" => {
      "cloud" => "eu-central-1",
      "datacenter" => "eu-central-1c", #, "eu-central-1b","eu-central-1a"
      "ssh_key" => "@ssh_key",
      "subnet" => "@vpc_subnet.name",  # using .name since we need to use name for google
      "priv_subnet" => "@vpc_priv_subnet.name",
      "gw" => "@vpc_igw",
      "tag_prefix" => "ec2",
      "aws_region" => "frankfurt",
  },
  "EU (Ireland) eu-west-1" => {
      "cloud" => "eu-west-1",
      "datacenter" => "eu-west-1c",  # "eu-west-1b","eu-west-1a"
      "ssh_key" => "@ssh_key",
      "subnet" => "@vpc_subnet.name",  # using .name since we need to use name for google
      "priv_subnet" => "@vpc_priv_subnet.name",
      "gw" => "@vpc_igw",
      "tag_prefix" => "ec2",
      "aws_region" => "ireland",
  },
  "EU (London) eu-west-2" => {
      "cloud" => "eu-west-2",
      "datacenter" => "eu-west-2c", # "eu-west-2b","eu-west-2a"
      "ssh_key" => "@ssh_key",
      "subnet" => "@vpc_subnet.name",  # using .name since we need to use name for google
      "priv_subnet" => "@vpc_priv_subnet.name",
      "gw" => "@vpc_igw",
      "tag_prefix" => "ec2",
      "aws_region" => "london",
  },
  "EU (Paris) eu-west-3" => {
      "cloud" => "eu-west-3",
      "datacenter" => "eu-west-3c", #"eu-west-3b","eu-west-3a"
      "ssh_key" => "@ssh_key",
      "subnet" => "@vpc_subnet.name",  # using .name since we need to use name for google
      "priv_subnet" => "@vpc_priv_subnet.name",
      "gw" => "@vpc_igw",
      "tag_prefix" => "ec2",
      "aws_region" => "paris",
  }
} end

mapping "map_instancetype" do {
  "Standard Performance" => {
    "AWS" => "m3.medium",
    "AzureRM" => "D1",
    "Google" => "n1-standard-1",
    "VMware" => "small",
  },
  "High Performance" => {
    "AWS" => "m3.large",
    "AzureRM" => "D1",
    "Google" => "n1-standard-2",
    "VMware" => "large",
  }
} end

mapping "map_config" do 
  like $linux_server_declarations.map_config
end
mapping "map_image_name_root" do 
 like $linux_mappings.map_image_name_root
end

### Permissions ###
permission "pft_general_permissions" do
  like $permissions.pft_general_permissions
end

permission "pft_sensitive_views" do
  resources "rs_cm.credentials" 
  actions "rs_cm.index", "rs_cm.show", "rs_cm.index_sensitive", "rs_cm.show_sensitive"
end

### User Inputs ###
#parameter "param_location" do
#  type "string"
#  label "Cloud"
#  category "Deployment Options"
#  description "Target cloud for this cluster."
#  allowed_values "AWS"  #, "AzureRM", "Google"
#  default "AWS"
#end

parameter "param_location" do
    type "string"
    label "AWS Region"
    category "Deployment Options"
    description "Target AWS Region for this cluster."
    allowed_values "US East (Ohio) us-east-2", "US East (N. Virginia) us-east-1", "US West (Oregon) us-west-2", "EU (Frankfurt) eu-central-1","EU (Ireland) eu-west-1", "EU (London) eu-west-2", "EU (Paris) eu-west-3"
    default "US West (Oregon) us-west-2"
end

parameter "param_instancetype" do
  category "Deployment Options"
  label "Server Performance Level"
  type "list"
  allowed_values "Standard Performance",
    "High Performance"
  default "Standard Performance"
end

parameter "param_numservers" do 
  category "Deployment Options"
  label "Number of Servers to Launch in Private Subnet" 
  type "number" 
  min_value 1
  max_value 5
  constraint_description "Maximum of 5 servers allowed by this application."
  default 1
end

parameter "param_costcenter" do 
  category "Deployment Options"
  label "Cost Center" 
  type "string" 
  allowed_values "Development", "QA", "Production"
  default "Development"
end

### Outputs ###
output "out_pub_server_ip" do
  category "Public Network Resources"
  label "Public Server IP"
end

output "igw" do
  category "Public Network Resources"
  label "Internet Gateway ID"
  default_value @vpc_igw.resource_uid
end

output_set "out_priv_servers_ips" do
  category "Private Network Resources"
  label @priv_servers.name
end

#output "nat_gateway_id" do
#  category "Private Network Resources"
#  label "NAT Gateway ID"
#  default_value @vpc_nat_gw.natGatewayId
#end

output "nat_gateway_ip" do
  category "Private Network Resources"
  label "NAT Gateway IP"
  default_value @vpc_nat_ip.address
end

output "aws_region" do
    category "AWS Cloud Region"
    label "AWS Region Selected"
    default_value $param_l
end

### VPC ###
resource "vpc_network", type: "network" do
  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  cidr_block "10.1.0.0/16"
end
### /VPC ###

### Public Subnet Set Up ###
# public facing subnet
resource "vpc_subnet", type: "subnet" do
  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "datacenter")
  network @vpc_network
  cidr_block "10.1.1.0/24"
end

# Internet gateway
resource "vpc_igw", type: "network_gateway" do
  name join(["cat_igw_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  type "internet"
  network @vpc_network
end

# Route table for the public subnet
resource "vpc_route_table", type: "route_table" do
  name join(["cat_route_table_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  network @vpc_network
end

# Route to the Internet gateway for the public subnet
resource "vpc_route", type: "route" do
  name join(["cat_internet_route_", last(split(@@deployment.href,"/"))])
  destination_cidr_block "0.0.0.0/0" 
  next_hop_network_gateway @vpc_igw
  route_table @vpc_route_table
end

# non-public facing subnet
resource "vpc_priv_subnet", type: "subnet" do
  name join(["cat_priv_subnet_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "datacenter")
  network @vpc_network
  cidr_block "10.1.2.0/24"
end

# NAT gateway and Elastic IP
resource "vpc_nat_ip", type: "ip_address" do
  name join(["cat_nat_ip_", last(split(@@deployment.href,"/"))])
  domain "vpc"
  cloud map($map_cloud, $param_location, "cloud")
end

resource "vpc_nat_gw_ohio", type: "rs_aws_vpc_ohio.nat_gateway" do
    allocation_id "TBD"  # RCL below sets the allocation_id for the elastic IP
    subnet_id @vpc_subnet.resource_uid  # Sits in the public subnet but is a GW for private subnet
end

resource "vpc_nat_gw_oregon", type: "rs_aws_vpc_oregon.nat_gateway" do
    allocation_id "TBD"  # RCL below sets the allocation_id for the elastic IP
    subnet_id @vpc_subnet.resource_uid  # Sits in the public subnet but is a GW for private subnet
end

resource "vpc_nat_gw_virginia", type: "rs_aws_vpc_virginia.nat_gateway" do
    allocation_id "TBD"  # RCL below sets the allocation_id for the elastic IP
    subnet_id @vpc_subnet.resource_uid  # Sits in the public subnet but is a GW for private subnet
end

resource "vpc_nat_gw_frankfurt", type: "rs_aws_vpc_frankfurt.nat_gateway" do
    allocation_id "TBD"  # RCL below sets the allocation_id for the elastic IP
    subnet_id @vpc_subnet.resource_uid  # Sits in the public subnet but is a GW for private subnet
end
resource "vpc_nat_gw_ireland", type: "rs_aws_vpc_ireland.nat_gateway" do
    allocation_id "TBD"  # RCL below sets the allocation_id for the elastic IP
    subnet_id @vpc_subnet.resource_uid  # Sits in the public subnet but is a GW for private subnet
end

resource "vpc_nat_gw_london", type: "rs_aws_vpc_london.nat_gateway" do
    allocation_id "TBD"  # RCL below sets the allocation_id for the elastic IP
    subnet_id @vpc_subnet.resource_uid  # Sits in the public subnet but is a GW for private subnet
end

resource "vpc_nat_gw_paris", type: "rs_aws_vpc_paris.nat_gateway" do
    allocation_id "TBD"  # RCL below sets the allocation_id for the elastic IP
    subnet_id @vpc_subnet.resource_uid  # Sits in the public subnet but is a GW for private subnet
end

# Route table for the private subnet
resource "vpc_priv_route_table", type: "route_table" do
  name join(["cat_priv_route_table_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  network @vpc_network
end

# Route to NAT Gateway for the private subnet is created below in RCL

### Security Groups ###
resource 'cluster_sg', type: 'security_group' do
  name join(['ClusterSG-', last(split(@@deployment.href, '/'))])
  description "Cluster security group."
  cloud map($map_cloud, $param_location, "cloud")
  network @vpc_network
end

resource 'cluster_sg_rule_int_tcp', type: 'security_group_rule' do
  name "ClusterSG TCP Rule"
  description "TCP rule for Cluster SG"
  source_type "cidr_ips"
  security_group @cluster_sg
  protocol 'tcp'
  direction 'ingress'
  cidr_ips "10.1.0.0/16"
  protocol_details do {
    'start_port' => '1',
    'end_port' => '65535'
  } end
end

resource 'cluster_sg_rule_int_udp', type: 'security_group_rule' do
  name "ClusterSG UDP Rule"
  description "UDP rule for Cluster SG"
  source_type "cidr_ips"
  security_group @cluster_sg
  protocol 'udp'
  direction 'ingress'
  cidr_ips "10.1.0.0/16"
  protocol_details do {
    'start_port' => '1',
    'end_port' => '65535'
  } end
end

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  like @common_resources.ssh_key
  name join(['cat_vpc_ssh_key_', last(split(@@deployment.href, '/'))])
end

### Server Declarations ###
resource "pub_server", type: "server" do
  name join(['pub_server-',last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "datacenter")
  network @vpc_network
  subnets map($map_cloud, $param_location, "subnet")  # Find the named subnet in the referenced network above.
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  security_groups @cluster_sg  
  server_template_href find(map($map_config, "st", "name"), revision: map($map_config, "st", "rev"))
  multi_cloud_image_href find(map($map_config, "mci", "name"), revision: map($map_config, "mci", "rev"))
end

resource "priv_servers", type: "server", copies: $param_numservers do
  name join(['priv_server-',last(split(@@deployment.href,"/")), "-", copy_index()])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "datacenter")
  network @vpc_network
  subnets map($map_cloud, $param_location, "priv_subnet")  # Find the named subnet in the referenced network above.
  instance_type map($map_instancetype, $param_instancetype, $param_location)
  ssh_key_href map($map_cloud, $param_location, "ssh_key")
  security_groups @cluster_sg  
  server_template_href find(map($map_config, "st", "name"), revision: map($map_config, "st", "rev"))
  multi_cloud_image_href find(map($map_config, "mci", "name"), revision: map($map_config, "mci", "rev"))
  associate_public_ip_address false # no need to give these things public IPs
end

operation 'launch' do
  description 'Create the network.'
  definition 'launch'
end

operation "enable" do
  description "Post launch activities"
  definition "enable"
  resource_mappings do {
    @priv_servers => @priv_servers_collection
  } end
  output_mappings do {
    $out_pub_server_ip => $pub_server_ip,
    $out_priv_servers_ips => $priv_servers_ips
  } end
end

operation 'terminate' do
  description 'Clean up the system.'
  definition 'terminate'
end

# Default stop/start behavior in CAT is to terminate/(re)launch the resources.
# By defining custom stop/start operations, this default behavior can be overridden.
operation "stop" do
  description "Server stop"
  definition "stop_server"
end

operation "start" do
  description "Server start"
  definition "start_server"
  
  resource_mappings do {
    @priv_servers => @priv_servers_collection
  } end
  output_mappings do {
    $out_pub_server_ip => $pub_server_ip,
    $out_priv_servers_ips => $priv_servers_ips
  } end
end

# Create the network and related components and NAT gateway and servers and this and that.
define launch(@pub_server, @priv_servers, @vpc_network, @vpc_subnet, @vpc_priv_subnet, @vpc_igw, @vpc_nat_gw_ohio, @vpc_nat_gw_oregon, @vpc_nat_gw_virginia, @vpc_nat_gw_frankfurt, @vpc_nat_gw_ireland, @vpc_nat_gw_london, @vpc_nat_gw_paris, @vpc_nat_ip, @vpc_route_table, @vpc_route, @vpc_priv_route_table, @cluster_sg, @cluster_sg_rule_int_tcp, @cluster_sg_rule_int_udp, @ssh_key, $param_location, $map_cloud, $map_config, $map_image_name_root) return @pub_server, @priv_servers, @vpc_network, @vpc_subnet, @vpc_priv_subnet, @vpc_igw, @vpc_nat_gw, @vpc_nat_ip, @vpc_route_table, @vpc_route, @vpc_priv_route_table, @cluster_sg, @cluster_sg_rule_int_tcp, @cluster_sg_rule_int_udp, @ssh_key do


   # Gettng the cloud location for the correct region plugin to call
   $$cloud_location = map($map_cloud, $param_location, "aws_region")
   # i.e. $cloud_location = "oregon"
   $$myplugin_region = "rs_aws_vpc_" + $$cloud_location
   # i.e. makes:  $$myplugin_region = "rs_aws_vpc_oregon"

   # My region gateway
    $$myplugin_region_gateway = $$myplugin_region + ".nat_gateway"
    # i.e. makes $$myplugin_region_gateway =  "rs_aws_vpc_oregon.nat_gateway"
    

   if $$cloud_location == "ohio"
    @vpc_nat_gw = @vpc_nat_gw_ohio
   end
   if $$cloud_location == "oregon"
    @vpc_nat_gw = @vpc_nat_gw_oregon
   end
   if $$cloud_location == "virginia"
    @vpc_nat_gw = @vpc_nat_gw_virginia
   end
   if $$cloud_location == "frankfurt"
    @vpc_nat_gw = @vpc_nat_gw_frankfurt
   end
   if $$cloud_location == "ireland"
    @vpc_nat_gw = @vpc_nat_gw_ireland
   end
   if $$cloud_location == "london"
    @vpc_nat_gw = @vpc_nat_gw_london
   end
   if $$cloud_location == "paris"
    @vpc_nat_gw = @vpc_nat_gw_paris
   end
   
  provision(@vpc_network)

  concurrent return @vpc_subnet, @vpc_priv_subnet, @vpc_igw, @vpc_route_table, @vpc_priv_route_table  do
    provision(@vpc_subnet)
    provision(@vpc_priv_subnet)
    provision(@vpc_igw)
    provision(@vpc_route_table)   
    provision(@vpc_priv_route_table)  
  end
  
  provision(@vpc_route)

  # Provision NAT GW bits and baubles
  provision(@vpc_nat_ip)
  sleep_until(@vpc_nat_ip.address)
  call debug.log("ip address after sleep", to_s(@vpc_nat_ip.address))
  call provision_nat_gw(@vpc_nat_gw, @vpc_nat_ip) retrieve @vpc_nat_gw
  call provision_route_to_nat_gw(map($map_cloud, $param_location, "cloud"), @vpc_nat_gw, @vpc_priv_route_table)

  # configure the subnets to use their route tables
  concurrent do
    @vpc_subnet.update(subnet: {route_table_href: to_s(@vpc_route_table.href)})
    @vpc_priv_subnet.update(subnet: {route_table_href: to_s(@vpc_priv_route_table.href)})
  end
    
  provision(@cluster_sg_rule_int_tcp)
  provision(@cluster_sg_rule_int_udp)
  
  provision(@ssh_key)

  concurrent return @pub_server, @priv_servers do
    provision(@pub_server)
    provision(@priv_servers)
  end

end

# Use VPC plugin to orchestrate provisioning the NAT gateway.
# The main task at hand is inserting the Elastic IP's allocation which is required.
define provision_nat_gw(@nat_gw, @nat_ip) return @nat_gw do
  @aws_ip = $$myplugin_region.addresses.show(public_ip_1: @nat_ip.address)
  $nat_gateway = to_object(@nat_gw)
  $nat_gateway["fields"]["allocation_id"] = @aws_ip.allocationId
  @nat_gw = $nat_gateway
  provision(@nat_gw)
  @nat_gw = @nat_gw.get()
end

# Currently using API calls instead of plugin.
# AWS VPC plugin does not currently support creating routes as such and so decided to
# just handle it via API.
# And part of me thinks this makes most sense anyway since I don't really need to create a route object,
# but rather just add a route to my existing route_table object.
define provision_route_to_nat_gw($region, @nat_gw, @route_table) do
  call debug.log("@nat_gw", to_s(to_object(@nat_gw)))
    
  $nat_gw_id = @nat_gw.natGatewayId
  $route_table_id = @route_table.resource_uid
  $destination_cidr = "0.0.0.0/0"
  
  $create_route_url = "https://ec2."+$region+".amazonaws.com/?Action=CreateRoute&Version=2016-11-15&DestinationCidrBlock="+$destination_cidr+"&NatGatewayId="+$nat_gw_id+"&RouteTableId="+$route_table_id
  call debug.log("create route url", to_s($create_route_url))
  $response = http_post(
    url: $create_route_url,
    signature: {"type": "aws"}
  )
  
  call debug.log("create route response", to_s($response))

end

# Runs after launch and used to do tagging
define enable(@pub_server, @priv_servers, $param_costcenter, $map_cloud, $param_location) return $pub_server_ip, @priv_servers_collection, $priv_servers_ips do
  
    # Tag the servers with the selected project cost center ID.
    $tags=[join([map($map_cloud, $param_location, "tag_prefix"), ":costcenter=",$param_costcenter])]
    rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
      
    # Wait until the public server has its IP address and return it for display
    sleep_until(@pub_server.public_ip_addresses[0])
    $pub_server_ip = @pub_server.public_ip_addresses[0]
    
    # Wait until all the private servers have IP addresses and return those addresses for display
    $priv_servers_ips = map @server in @priv_servers return $ip do
      sleep_until(@server.private_ip_addresses[0])
      $ip = @server.private_ip_addresses[0]
    end
    @priv_servers_collection = @priv_servers
    
end 

# Update some of the networking components to remove dependencies that would prevent cleaning up
# the network.
# Terminate the servers. We'll let auto-terminate handle the networking resources.
define terminate(@pub_server, @priv_servers, @vpc_network, @vpc_subnet, @vpc_priv_subnet, @vpc_igw, @vpc_nat_gw_ohio, @vpc_nat_gw_oregon, @vpc_nat_gw_virginia, @vpc_nat_gw_frankfurt, @vpc_nat_gw_ireland, @vpc_nat_gw_london, @vpc_nat_gw_paris, @vpc_nat_ip, $param_location) return @pub_server, @priv_servers, @vpc_igw, @vpc_nat_gw, @vpc_nat_ip do
  
  if $$cloud_location == "ohio"
   @vpc_nat_gw = @vpc_nat_gw_ohio
  end
  if $$cloud_location == "oregon"
   @vpc_nat_gw = @vpc_nat_gw_oregon
  end
  if $$cloud_location == "virginia"
   @vpc_nat_gw = @vpc_nat_gw_virginia
  end
  if $$cloud_location == "frankfurt"
   @vpc_nat_gw = @vpc_nat_gw_frankfurt
  end
  if $$cloud_location == "ireland"
   @vpc_nat_gw = @vpc_nat_gw_ireland
  end
  if $$cloud_location == "london"
   @vpc_nat_gw = @vpc_nat_gw_london
  end
  if $$cloud_location == "paris"
   @vpc_nat_gw = @vpc_nat_gw_paris
  end
  
  # Terminate the servers in the network.
  concurrent return @pub_server, @priv_servers do
    delete(@pub_server)
    delete(@priv_servers)
  end
  
  # Update subnets to remove the route tables we created so the subnets will be able to be deleted
  # The trick being used here is the fact that the VPC itself still points to the default route table.
  # So we can use that fact to easily find the default route table and then apply it to the subnets.
  # This will then let things delete as expected.
  # We'll let auto-terminate handle deleting the subnets.
  @default_route_table = @vpc_network.default_route_table()
  $default_route_table_href = @default_route_table.href
  @vpc_subnet.update(subnet: {route_table_href: $default_route_table_href})
  @vpc_priv_subnet.update(subnet: {route_table_href: $default_route_table_href})
  
  # Delete NAT GW and Elastic IP
  delete(@vpc_nat_gw)
  sleep_until(@vpc_nat_gw.state == "deleted")
  delete(@vpc_nat_ip)
  
  # Remove IGW reference to the VPC and delete the IGW
  @vpc_igw.update(network_gateway: {network_href: ""})
  delete(@vpc_igw)
  
  # The rest of the resources are left to auto-terminate to be taken care of.
  
end

#
# Stop and Start operations
# 
define stop_server() do
  @@deployment.servers().current_instance().stop()
  $wake_condition = "/^(provisioned)$/"
  sleep_until all?(@@deployment.servers().current_instance().state[], $wake_condition)
end

define start_server(@pub_server, @priv_servers) return $pub_server_ip, @priv_servers_collection, $priv_servers_ips do
  @@deployment.servers().current_instance().start()
  $wake_condition = "/^(operational|stranded|stranded in booting)$/"
  sleep_until all?(@@deployment.servers().current_instance().state[], $wake_condition)
    
  # Wait until the public server has its IP address and return it for display
  # It might take a minute or so before the new public IP address is reported back from AWS.
  sleep(60)  # so site tight for a few 
  sleep_until(@pub_server.public_ip_addresses[0]) # and may as well make sure there is one assigned before returning it.
  $pub_server_ip = @pub_server.public_ip_addresses[0]
  
  # Wait until all the private servers have IP addresses and return those addresses for display
  $priv_servers_ips = map @server in @priv_servers return $ip do
    sleep_until(@server.private_ip_addresses[0])
    $ip = @server.private_ip_addresses[0]
  end
  @priv_servers_collection = @priv_servers
end

