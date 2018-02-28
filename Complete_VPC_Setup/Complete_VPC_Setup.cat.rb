name 'Complete Network Creation and Server Launch CAT'
rs_ca_ver 20161221
short_description "![Network](https://s3.amazonaws.com/rs-pft/cat-logos/private_network.png)\n
Creates a network and related items (e.g. subnet, security groups, etc) and launches server in the private network."
long_description "Creates isolated private network environment and launches server in the network.\n
Clouds Supported:  AWS, AzureRM, and Google."

import "pft/err_utilities", as: "debug"
import "pft/mci"
import "pft/linux_server_declarations"
import "pft/mci/linux_mappings", as: "linux_mappings"
import "pft/resources", as: "common_resources"

### Mappings ###
mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-west-2",
    "datacenter" => "us-west-2b",
    "ssh_key" => "@ssh_key",
    "subnet" => "@vpc_subnet.name",  # using .name since we need to use name for google
    "gw" => "@vpc_igw",
    "tag_prefix" => "ec2"
  },
  "Google" => {
    "cloud" => "Google",
    "datacenter" => "us-central1-b",
    "ssh_key" => null,
    "subnet" => "default",  # Google creates a subnet named "default" and so we want to reference it in the context of the network we created
    "gw" => null,
    "tag_prefix" => "gce"
  },
  "AzureRM" => {   
    "cloud" => "AzureRM East US",
    "datacenter" => null,
    "ssh_key" => null,
    "subnet" => "@vpc_subnet.name",  # using .name since we need to use name for google
    "gw" => null,
    "tag_prefix" => "azure"
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

### User Inputs ###
parameter "param_location" do
  type "string"
  label "Cloud"
  category "Deployment Options"
  description "Target cloud for this cluster."
  allowed_values "AWS", "AzureRM", "Google"
  default "AWS"
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
  label "Number of Servers to Launch" 
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
output_set "output_server_ips" do
  label @linux_servers.name
  category "IP Addresses"
end


### Network Declarations ###
resource "vpc_network", type: "network" do
  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  cidr_block "10.1.0.0/16"
end

resource "vpc_subnet", type: "subnet" do
  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  datacenter map($map_cloud, $param_location, "datacenter")
  network @vpc_network
  cidr_block "10.1.1.0/24"
end

resource "vpc_igw", type: "network_gateway" do
  name join(["cat_igw_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  type "internet"
  network @vpc_network
end

resource "vpc_route_table", type: "route_table" do
  name join(["cat_route_table_", last(split(@@deployment.href,"/"))])
  cloud map($map_cloud, $param_location, "cloud")
  network @vpc_network
end

# Outbound traffic
resource "vpc_route", type: "route" do
  name join(["cat_internet_route_", last(split(@@deployment.href,"/"))])
  destination_cidr_block "0.0.0.0/0" 
  next_hop_network_gateway @vpc_igw
  route_table @vpc_route_table
end

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
  cidr_ips "10.1.1.0/24"
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
  cidr_ips "10.1.1.0/24"
  protocol_details do {
    'start_port' => '1',
    'end_port' => '65535'
  } end
end

### SSH Key
resource "ssh_key", type: "ssh_key" do
  like @common_resources.ssh_key
end

### Server Declaration ###
resource "linux_servers", type: "server", copies: $param_numservers do
  name join(['linux-',last(split(@@deployment.href,"/")), "-", copy_index()])
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

operation 'launch' do
  description 'Create the network.'
  definition 'launch'
end

operation "enable" do
  description "Get information once the app has been launched"
  definition "enable"
  resource_mappings do {
    @linux_servers => @servers
  } end
  output_mappings do {
    $output_server_ips => $server_ips
  } end
end

operation 'terminate' do
  description 'Clean up the system.'
  definition 'terminate'
end

# Create the network and related components.
# Let auto-launch take care of standing up the server(s) in the network.
define launch(@linux_servers, @vpc_network, @vpc_subnet, @vpc_igw, @vpc_route_table, @vpc_route, @cluster_sg, @cluster_sg_rule_int_tcp, @cluster_sg_rule_int_udp, @ssh_key, $param_location, $map_cloud, $map_config, $map_image_name_root) return @linux_servers, @vpc_network, @vpc_subnet, @vpc_igw, @vpc_route_table, @vpc_route, @cluster_sg, @cluster_sg_rule_int_tcp, @cluster_sg_rule_int_udp do
    
  # provision networking
  provision(@vpc_network)
  
  if map($map_cloud, $param_location, "subnet") == "default"  # then we need to wait for the default subnet to appear
    @cloud = @vpc_network.cloud()
    $network_href = @vpc_network.href
    @default_subnet = rs_cm.subnets.empty()
    while size(@default_subnet) == 0 do
      sleep(10)
      @default_subnet = @cloud.subnets(filter: ["network_href=="+$network_href])
      call debug.log("Waiting for default subnet", to_s(to_object(@default_subnet)))
    end
  else # then we need to provision the subnet
    provision(@vpc_subnet)
  end
  
  if map($map_cloud, $param_location, "gw")
    concurrent return @vpc_igw, @vpc_route_table  do
      provision(@vpc_igw)
      provision(@vpc_route_table)    
    end
    provision(@vpc_route)
    # configure the network to use the route table
    @vpc_network.update(network: {route_table_href: to_s(@vpc_route_table.href)})
  end
    
   provision(@cluster_sg_rule_int_tcp)
   provision(@cluster_sg_rule_int_udp)
   
  # In the spirit of portability, run some logic to update the MCI in case the off-the-shelf
  # image has been deprecated. 
  # This adds about a minute to the launch but is worth it to avoid a failure due to the cloud provider
  # deprecating the image we use.
  $cloud_name = map( $map_cloud, $param_location, "cloud" )
  $mci_name = map($map_config, "mci", "name")
  call mci.find_mci($mci_name) retrieve @mci
  @cloud = find("clouds", $cloud_name)
  call mci.find_image_href(@cloud, $map_image_name_root, "PFT Base Linux", $param_location) retrieve $image_href
  call mci.mci_upsert_cloud_image(@mci, @cloud.href, $image_href)

  if map($map_cloud, $param_location, "ssh_key")
    provision(@ssh_key)
  end

  provision(@linux_servers)

end

define enable(@linux_servers, $param_costcenter, $map_cloud, $param_location) return @servers, $server_ips do
  
    # Tag the servers with the selected project cost center ID.
    $tags=[join([map($map_cloud, $param_location, "tag_prefix"), ":costcenter=",$param_costcenter])]
    rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
    
    # Wait until all the servers have IP addresses
    $server_ips = map @server in @linux_servers return $ip do
      sleep_until(@server.public_ip_addresses[0])
      $ip = @server.public_ip_addresses[0]
    end
    
    @servers = @linux_servers
end 

# Update some of the networking components to remove dependencies that would prevent cleaning up
# the network.
# Terminate the servers. We'll let auto-terminate handle the networking resources.
define terminate(@linux_servers, @vpc_network, @vpc_route_table, $param_location) return @linux_servers do
  
  # Terminate the servers in the network.
  delete(@linux_servers)
  
  if $param_location == "AWS" 
    # switch back in the default route table so that auto-terminate doesn't hit a dependency issue when cleaning up.
    # Another approach would have been to not create and associate a new route table but instead find the default route table
    # and add the outbound 0.0.0.0/0 route to it.
    @other_route_table = @vpc_route_table #  initializing the variable
    # Find the route tables associated with our network. 
    # There should be two: the one we created above and the default one that is created for new networks.
    @route_tables=rs_cm.route_tables.get(filter: [join(["network_href==",to_s(@vpc_network.href)])])
    foreach @route_table in @route_tables do
      if @route_table.href != @vpc_route_table.href
        # We found the default route table
        @other_route_table = @route_table
      end
    end
    # Update the network to use the default route table 
    @vpc_network.update(network: {route_table_href: to_s(@other_route_table.href)})
  end
   
end


