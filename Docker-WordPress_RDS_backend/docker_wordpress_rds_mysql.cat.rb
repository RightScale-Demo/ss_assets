# Docker WordPress Container with an RDS backend for the DB.
#
# Key Features:
#   Creates an RDS instance using SS plugin
#   Launches a Docker server and a WordPress container on the server which connects to the RDS for the DB.
#   Tags both the Docker Server and RDS Instance with various tags.
#
# TO-DO
# Handle the username and password for the DB access better.
# Add bits to support creating and deleting the RDS security group.


name 'WordPress Container with External RDS DB Server - Plugin'
rs_ca_ver 20161221
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/docker.png) ![logo](https://s3.amazonaws.com/rs-pft/cat-logos/amazon_rds_glossy.png) 

WordPress Container with External RDS MySQL DB Server"

import "pft/creds_utilities"
import "pft/account_utilities"
import "pft/err_utilities"
import "plugins/rs_aws_rds"

mapping "map_cat" do {
  "cloud_info" => {   
    "cloud" => "EC2 us-east-1",
    "availiblity_zone" => "us-east-1a",
    "network" => "Demo-vpc",
    "subnet" => "Demo-subnet-1a"
  },
  "script_info" => {
    "compose_script_href" => "/api/right_scripts/593001003",  # APP docker services compose
    "services_up_script_href" => "/api/right_scripts/593002003" # APP docker services up
  }
} end

### Inputs ####
parameter "param_db_username" do 
  category "RDS Configuration Options"
  label "RDS DB User Name" 
  type "string" 
  min_length 1
  max_length 16
  allowed_pattern '^[a-zA-Z].*$'
  no_echo false
end

parameter "param_db_password" do 
  category "RDS Configuration Options"
  label "RDS DB User Password" 
  type "string" 
  min_length 8
  max_length 41
  no_echo true
end

parameter "param_db_size" do 
  category "RDS Configuration Options"
  label "DB Size (GB)" 
  type "number" 
  default 5
  min_value 5
  max_value 25
end

parameter "param_costcenter" do 
  category "Deployment Options"
  label "Budget Code" 
  type "number" 
  min_value 1
  max_value 999999
  default 1164
end

### Outputs ###
output "wordpress_url" do
  label "WordPress Link"
  category "Outputs"
end

output "rds_url" do
  label "RDS Link"
  category "Outputs"
end

output "rds_endpoint" do
  category "Outputs"
  label "RDS Endpoint"
  default_value @rds.endpoint_address
end

### Security Group Definitions ###
resource "sec_group", type: "security_group" do
  name join(["DockerServerSecGrp-",last(split(@@deployment.href,"/"))])
  description "Docker Server deployment security group."
  cloud map($map_cat, "cloud_info", "cloud")
  network map($map_cat, "cloud_info", "network")
end

resource "sec_group_rule_http", type: "security_group_rule" do
  name "Docker deployment HTTP Rule"
  description "Allow HTTP access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "8080",
    "end_port" => "8080"
  } end
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  like @sec_group_rule_http
  name "Docker deployment SSH Rule"
  description "Allow SSH access."
  protocol_details do {
    "start_port" => "22",
    "end_port" => "22"
  } end
end  

#resource "rds_sec_group", type: "security_group" do
#  name join(["RdsSecGrp-",last(split(@@deployment.href,"/"))])
#  description "RDS security group."
#  cloud map($map_cat, "cloud_info", "cloud")
#  network map($map_cat, "cloud_info", "network")
#end
#
#resource "rds_sec_group_rule_3306", type: "security_group_rule" do
#  name "RDS 3306 Rule"
#  description "Allow access to RDS."
#  security_group @rds_sec_group
#  source_type "group"
#  direction "ingress"
#  group_owner cred("AWS_ACCOUNT_NUMBER")
#  protocol "tcp"
#  protocol_details do {
#    "start_port" => "3306",
#    "end_port" => "3306"
#  } end
#end 

### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud map($map_cat, "cloud_info", "cloud")
end

resource 'wordpress_docker_server', type: 'server' do
  name 'Docker Wordpress'
  cloud map($map_cat, "cloud_info", "cloud")
  network map($map_cat, "cloud_info", "network")
  subnets [map($map_cat, "cloud_info", "subnet")]
  ssh_key_href @ssh_key
  security_group_hrefs @sec_group
  server_template find('Docker Node', revision: 5)
  inputs do {
    'DOCKER_ENVIRONMENT' => 'text:TBD',
    'DOCKER_PROJECT' => 'text:rightscale',
    'DOCKER_SERVICES' => 'text:wordpress:
  image: wordpress
  ports:
    - 8080:80',
  } end
end

resource "rds", type: "rs_aws_rds.db_instance" do
  availability_zone map($map_cat, "cloud_info", "availability_zone")
  db_instance_class "db.t2.small"
  allocated_storage $param_db_size
  backup_retention_period "0" # Don't do backups
  db_instance_identifier join(["my-rds-", last(split(@@deployment.href, "/"))])
  db_name join(["mydb", last(split(@@deployment.href, "/"))])
  db_subnet_group_name "demo-subnet-group"
  engine "mysql"
  engine_version "5.6.35" 
  master_username $param_db_username
  master_user_password $param_db_password
  storage_encrypted "false"
  storage_type "standard"
  tag_key_1 "BudgetCode"
  tag_value_1 $param_costcenter
end

# Operations
operation "launch" do
    description 'Launch the application' 
    definition 'launch_handler' 
    
    output_mappings do {
      $wordpress_url => $wordpress_link,
      $rds_url => $rds_link,
    } end
end 

operation "terminate" do
    description 'Terminate the application' 
    definition 'termination_handler' 
end 

########
# RCL
########
define launch_handler(@wordpress_docker_server, @rds, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_ssh, $param_costcenter, $param_db_username, $param_db_password, $map_cat)  return @wordpress_docker_server, @rds, $rds_link, @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group, $wordpress_link do 

  concurrent return @sec_group, @ssh_key do
      provision(@ssh_key)
      # provision security groups
      provision(@sec_group)
  end
  
  #provision secuirty group roles
  provision(@sec_group_rule_http)
  provision(@sec_group_rule_ssh)
#  $rds_sg_rule = to_object(@rds_sec_group_rule_3306)
#  $rds_sg_rule['fields']['group_name'] = @sec_group.resource_uid
#  @rds_sec_group_rule_3306 = $rds_sg_rule
#  provision(@rds_sec_group_rule_3306)
#  
#  # set security group for rds
#  $rds = to_object(@rds)
#  $rds["fields"]["db_security_group"] = @sec_group.resource_uid
#  @rds = $rds

#  concurrent return @rds, @wordpress_docker_server do
    provision(@rds)
    provision(@wordpress_docker_server)
#  end
  
  # configure the docker wordpress environment variables to point at the DB server
  $docker_env = "wordpress:\n   WORDPRESS_DB_HOST: " + @rds.endpoint_address + "\n   WORDPRESS_DB_USER: "+ $param_db_username + "\n   WORDPRESS_DB_PASSWORD: " + $param_db_password  # + "\n" #  WORDPRESS_DB_NAME: dwp_rds_db"
  $inp = {
    'DOCKER_ENVIRONMENT' => join(["text:", $docker_env])
  } 
  @wordpress_docker_server.current_instance().multi_update_inputs(inputs: $inp) 
  
  # Run docker stuff to launch wordpress
  $right_script_href = map($map_cat, "script_info", "compose_script_href")
  @tasks = @wordpress_docker_server.current_instance().run_executable(right_script_href: $right_script_href)

  $right_script_href = map($map_cat, "script_info", "services_up_script_href")
  @tasks = @wordpress_docker_server.current_instance().run_executable(right_script_href: $right_script_href)
    
  $wordpress_server_address = @wordpress_docker_server.current_instance().public_ip_addresses[0]
  $wordpress_link = join(["http://",$wordpress_server_address,":8080"])
    
  # Tag the docker server with the required tags.
  $tags=[join(["ec2:BudgetCode=",$param_costcenter]), join(["ec2:ExecutionName=",$execution_name]), join(["ec2:Owner=",$userid]), join(["ec2:Description=",$execution_description])]
  rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)

  # Create Credentials with the DB creds
  $deployment_number = last(split(@@deployment.href,"/"))
  call creds_utilities.createCreds(["CAT_RDS_USERNAME_"+$deployment_number,"CAT_RDS_PASSWORD_"+$deployment_number])
    
  # Build the link to show the RDS info in CM.
  # NOTE: As seen in other places in this CAT, the assumption is that the RDS is in AWS US-East-1
  call account_utilities.find_account_number() retrieve $rs_account_number
  $rds_link = join(['https://my.rightscale.com/acct/',$rs_account_number,'/clouds/1/rds_browser?ui_route=instances/rds-instance-',last(split(@@deployment.href,"/")),'/info'])

end

define termination_handler(@wordpress_docker_server, @rds, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_ssh)  return @wordpress_docker_server, @rds, @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group do 

  concurrent return @rds, @wordpress_docker_server do
    delete(@rds)
    delete(@wordpress_docker_server)
  end
  
  concurrent return @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh do
    delete(@ssh_key)
    delete(@sec_group_rule_http)
    delete(@sec_group_rule_ssh)
  end
  
  delete(@sec_group)

  # Delete the creds we created for the user-provided DB username and password
  $deployment_number = last(split(@@deployment.href,"/"))
  call creds_utilities.deleteCreds(["CAT_RDS_USERNAME_"+$deployment_number,"CAT_RDS_PASSWORD_"+$deployment_number])

end

