NOT USED IN THE DEMO ACCOUNT
But kept here for reference.






# Sets up networking used for SAP-HANA CAT.
# Done separately for now
#       

name "Networking Constructs CAT"
rs_ca_ver 20161221
short_description "Testing the configuration of networking constructs."

mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
  }
}
end

### Network Definitions ###
resource "vpc_network", type: "network" do
#  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
  name "sap_vpc_test"
  cloud map($map_cloud, "AWS", "cloud")
  cidr_block "192.168.164.0/24"
end



resource "vpc_subnet", type: "subnet", provision: "provision_subnet" do
#  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
  name "sap_subnet_test"
  cloud map($map_cloud, "AWS", "cloud")
  network @vpc_network
  cidr_block "192.168.164.0/28"
end

define provision_subnet(@declaration) return @subnet do
  $object = to_object(@declaration)
  $fields = $object["fields"] 
    
  call log("provisioning subnet", to_s($object))
   
  # create the resource
  $cloud_href =  $fields["cloud_href"]
  @cloud = rs_cm.get(href: $cloud_href)
  @subnet = @cloud.subnets().create($fields)
  @subnet = @subnet.get()

  
  # Now that the subnet is provisioned, update the default route table to allow access to RS platform
# DOESN'T WORK YET DUE TO ISSUS WITH IGW NOT GETTING ATTACHED TO NETWORK
#  # Get the default route table
#  @default_route_table = @subnet.network().default_route_table()
#  # Create a route back to RS platform
#  @route = @default_route_table.routes().create(route: {destination_cidr_block: "0.0.0.0/0", next_hop_type: "network_gateway", next_hop_href: @igw.href, route_table_href: @default_route_table.href})
#  # Add route to the default route table
#  @default_route_table.update(   rs.route_tables.get(filter: [join(["network_href==",to_s(@resource.network().href)])])[0]
#  # Update the route table to use the default route table 
#  @vpc_network.update(network: {route_table_href: to_s(@other_route_table.href)})
end

resource "vpc_igw", type: "network_gateway", provision: "provision_gateway" do
#  name join(["cat_igw_", last(split(@@deployment.href,"/"))])
  name "sap_igw_test"
  cloud map($map_cloud, "AWS", "cloud")
  type "internet"
  network @vpc_network
end

define provision_gateway(@declaration) return @igw do
  $object = to_object(@declaration)
  $fields = $object["fields"] 
    
  call log("provisioning gateway", to_s($object))
   
  # create the resource
  @igw = rs_cm.network_gateways.create($fields)
  @igw = @igw.get()
  
  # Update the IGW with the network
  $network_href = $fields["network_href"]
  call log("network_href: "+$network_href, "igw: "+to_s(to_object(@igw)))
  @igw.update(network_gateway: {network_href: $network_href})
end

operation "terminate" do 
  description "Clean up"
  definition "terminate"
end

define terminate(@vpc_igw) do
  # Remove the network attachement for the gateway to avoid dependency issues
  @vpc_igw.update(network_gateway: {network_href: ""})
  delete(@vpc_igw)
end



# create an audit entry 
define log($summary, $details) do
  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: $summary , detail: $details})
end


## switch back in the default route table so that auto-terminate doesn't hit a dependency issue when cleaning up.
## Another approach would have been to not create and associate a new route table but instead find the default route table
## and add the outbound 0.0.0.0/0 route to it.
#
#@other_route_table = @vpc_route_table #  initializing the variable
## Find the route tables associated with our network. 
## There should be two: the one we created above and the default one that is created for new networks.
#@route_tables=rs.route_tables.get(filter: [join(["network_href==",to_s(@vpc_network.href)])])
#foreach @route_table in @route_tables do
#  if @route_table.href != @vpc_route_table.href
#    # We found the default route table
#    @other_route_table = @route_table
#  end
#end
## Update the network to use the default route table 
#@vpc_network.update(network: {route_table_href: to_s(@other_route_table.href)})
#
## detact the network from the gateway
#@vpc_igw.update(network_gateway: {network_href: ""})
#
#delete(@vpc_network)
#delete(@vpc_sec_group)
#
#end

#
#------------
#### Network Definitions ###
#resource "vpc_network", type: "network" do
#  name join(["cat_vpc_", last(split(@@deployment.href,"/"))])
#  cloud map($map_cloud, "AWS", "cloud")
#  cidr_block "192.168.164.0/24"
#end
#
#resource "vpc_subnet", type: "subnet" do
#  name join(["cat_subnet_", last(split(@@deployment.href,"/"))])
#  cloud map($map_cloud, "AWS", "cloud")
#  network_href @vpc_network
#  cidr_block "192.168.164.0/28"
#end
#
#resource "vpc_igw", type: "network_gateway" do
#  name join(["cat_igw_", last(split(@@deployment.href,"/"))])
#  cloud map($map_cloud, "AWS", "cloud")
#  type "internet"
#  network @vpc_network
#end
#
#resource "vpc_route_table", type: "route_table" do
#  name join(["cat_route_table_", last(split(@@deployment.href,"/"))])
#  cloud map($map_cloud, "AWS", "cloud")
#  network @vpc_network
#end
#
## This route is needed to allow the server to be able to talk back to RightScale.
## For a production environment you would probably want to limit the outbound route to just RightScale CIDRs and required ports.
## But for a demo CAT, this is fine. :)
#resource "vpc_route", type: "route" do
#  name join(["cat_internet_route_", last(split(@@deployment.href,"/"))])
#  destination_cidr_block "0.0.0.0/0" 
#  next_hop_network_gateway @vpc_igw
#  route_table @vpc_route_table
#end
#