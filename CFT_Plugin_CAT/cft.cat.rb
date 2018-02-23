name "CFT - RedShift Cluster"
rs_ca_ver 20161221
short_description "![CFT](https://s3.amazonaws.com/rs-pft/cat-logos/cft_logo.png) ![RedShift](https://s3.amazonaws.com/rs-pft/cat-logos/redshift.png)\n
Launches a CloudFormation Template that instantiates a RedShift Cluster"

import "pft/err_utilities"
import "pft/permissions"
import "plugins/rs_aws_useast1_cft"
import "plugins/rs_aws_uswest1_cft"

##################
# Permissions    #
##################
permission "pft_general_permissions" do
  like $permissions.pft_general_permissions
end

permission "pft_sensitive_views" do
  like $permissions.pft_sensitive_views
end

# MAPPINGS (CONFIGURATION)
# Customize with additional regions if needed
mapping "map_region" do {
  "us-east-1" => {
    "name_space" => "rs_aws_useast1_cft" },
  "us-west-1" => {
    "name_space" => "rs_aws_uswest1_cft" }
} end

# PARAMETERS (INPUTS)
parameter "param_region" do
  type "string"
  label "Region for Deployment"
  allowed_values "us-east-1", "us-west-1"
  default "us-east-1"
end

parameter "databasename" do
  type "string"
  label "DB Name"
  allowed_pattern "([a-z]|[0-9])+"
  default "defaultdb"
end

parameter "masterusername" do
  type "string"
  label "DB Master User Name"
  allowed_pattern "([a-z])([a-z]|[0-9])*"
  default "dbuser"
end

parameter "masteruserpassword" do
  type "string"
  label "DB Master Password"
  allowed_pattern "/^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z]).{8,16}$/"
  constraint_description "Must be 8-16 characters with at least one uppercase, one lowercase, and one digit."
  no_echo true
end

parameter "numberofnodes" do
  type "number"
  label "NumberOfNodes"
  min_value 1
  max_value 3
  default 1
end

# OUTPUTS
# Replace with desired outputs
output "out_clusterendpoint" do
  label "RedShift Cluster Endpoint"
end

resource "stack", type: "rs_aws_useast1_cft.stack" do
  stack_name join(["redshift-", last(split(@@deployment.href, "/"))])
  template_url "https://s3-us-west-2.amazonaws.com/cloudformation-templates-us-west-2/Redshift.template"
  description "RedShift via CFT"
  parameter_1_name "DatabaseName"
  parameter_1_value $databasename
  parameter_2_name "NumberOfNodes"
  parameter_2_value $numberofnodes
  parameter_3_name "MasterUsername"
  parameter_3_value $masterusername
  parameter_4_name "MasterUserPassword"
  parameter_4_value $masteruserpassword
  parameter_5_name "ClusterType"
  parameter_5_value switch(equals?($numberofnodes, 1), "single-node", "multi-node")
end

operation "launch" do
  definition "launcher"
end

define launcher(@stack, $map_region, $param_region) return @stack do
  
  # Update the stack declaration with the correct plugin namespace based on user selection
  $stack_object = to_object(@stack)
  $stack_object["namespace"] = map($map_region, $param_region, "name_space")
  @stack = $stack_object

  provision(@stack)
end
  
define log($summary, $details) do
  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: $summary , detail: $details})
end

# OPERATIONS
operation "enable" do
  definition "post_launch"
  output_mappings do {
    $out_clusterendpoint => $clusterendpoint
  } end
end

define post_launch(@stack) return $clusterendpoint do
   $clusterendpoint = @stack.OutputValue[0]
end
