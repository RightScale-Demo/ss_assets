name "CFT - RedShift Cluster"
rs_ca_ver 20161221
short_description "![CFT](https://s3.amazonaws.com/rs-pft/cat-logos/cft_logo.png) ![RedShift](https://s3.amazonaws.com/rs-pft/cat-logos/redshift.png)\n
Launches a CloudFormation Template that instantiates a RedShift Cluster"

import "pft/err_utilities"
import "pft/permissions"
import "plugins/rs_aws_cft"

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
    "api_endpoint" => "cloudformation.us-east-1.amazonaws.com" },
  "us-west-1" => {
    "api_endpoint" => "cloudformation.us-west-1.amazonaws.com" },
  "us-west-2" => {
    "api_endpoint" => "cloudformation.us-west-2.amazonaws.com" } }
end

# PARAMETERS (INPUTS)
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
  default_value @stack.OutputValue
end

resource "stack", type: "rs_aws_cft.stack" do
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

# OPERATIONS
# Ensure all outputs have an entry in output_mappings for launch operation below
#operation "launch" do
#  definition "launch"
#  output_mappings do {
#    $out_clusterendpoint => $clusterendpoint
#  } end
#end

#operation "terminate" do
#  definition "terminate"
#end

# DEFINITIONS (ORCHESTRATION LOGIC)
# CloudFormation template and parameters are in the call to create_stack
# On the line below, inputs must be passed in and outputs must be returned
#define launch(@stack) return @stack, $clusterendpoint do
#  
#  provision(@stack)
#  
#  # Gather CloudFormation outputs
#  call get_stack_outputs(@stack) retrieve $outputs
#
#  # Map CloudFormation outputs to outputs for this CloudApp
#  $clusterendpoint = $outputs["ClusterEndpoint"]
#end

#define terminate($map_region) do
#  $$api_endpoint = "cloudformation.us-east-1.amazonaws.com"
#
#  call delete_stack()
#end
#
## CLOUDFORMATION UTILITIES
## No customization needed below this line
#define create_stack($params) return $response do
#  $default_params = {
#    "Action": "CreateStack"
#  }
#
#  $merged_params = $params + $default_params
#
#  call cf_api($merged_params) retrieve $response
#  
#  call err_utilities.log("create_stack response", to_s($response))
#
#end
#
#define delete_stack() return $response do
#  $default_params = {
#    "Action": "DeleteStack"
#  }
#
#  call cf_api($default_params) retrieve $response
#  
#  call err_utilities.log("delete_stack response", to_s($response))
#
#end
#
#define get_stack_outputs(@stack) return $outputs do
#  $default_params = {
#    "Action": "DescribeStacks"
#  }
#
#  call cf_api($default_params) retrieve $response
#  
#  call err_utilities.log("get_stack_outputs response", to_s($response))
#
#  $outputs = $response["body"]["DescribeStacksResponse"]["DescribeStacksResult"]["Stacks"]["member"]["Outputs"]["member"]
#
#  $tmpobj = {}
#
#  # If only one output exists, it will be a single value instead of array
#  # This will normalize any response into an array
#  if type($outputs) != "array"
#    $outputs = [$outputs]
#  end
#
#  foreach $output in $outputs do
#    $tmpobj[$output["OutputKey"]] = $output["OutputValue"]
#  end
#
#  $outputs = $tmpobj
#  
#end
#
#define get_stack_status() return $status do
#  $default_params = {
#    "Action": "DescribeStacks"
#  }
#
#  call cf_api($default_params) retrieve $response
#  
#  call err_utilities.log("get_stack_status response", to_s($response))
#
#  $status = $response["body"]["DescribeStacksResponse"]["DescribeStacksResult"]["Stacks"]["member"]["StackStatus"]
#end
#
#define cf_api($params) return $response do
#  call sys_get_execution_id() retrieve $execution_id
#
#  $default_params = {
#    "StackName": "stack" + $execution_id
#  }
#
#  $merged_params = $params + $default_params
#
#  $response = http_request(
#    https: true,
#    verb: "get",
#    host: $$api_endpoint,
#    signature: { "type": "aws" },
#    query_strings: $merged_params
#  )
#  
#
#end
#
## GENERAL UTILITIES
## No customization needed below this line
#
## Returns all tags for a specified resource. Assumes that only one resource
## is passed in, and will return tags for only the first resource in the collection.
#
## @param @resource [ResourceCollection] a ResourceCollection containing only a
##   single resource for which to return tags
##
## @return $tags [Array<String>] an array of tags assigned to @resource
#define get_tags_for_resource(@resource) return $tags do
#  $tags = []
#  $tags_response = rs_cm.tags.by_resource(resource_hrefs: [@resource.href])
#  $inner_tags_ary = first(first($tags_response))["tags"]
#  $tags = map $current_tag in $inner_tags_ary return $tag do
#    $tag = $current_tag["name"]
#  end
#  $tags = $tags
#end
#
## Fetches the execution id of "this" cloud app using the default tags set on a
## deployment created by SS.
## selfservice:href=/api/manager/projects/12345/executions/54354bd284adb8871600200e
##
## @return [String] The execution ID of the current cloud app
#define sys_get_execution_id() return $execution_id do
#  call get_tags_for_resource(@@deployment) retrieve $tags_on_deployment
#  $href_tag = map $current_tag in $tags_on_deployment return $tag do
#    if $current_tag =~ "(selfservice:href)"
#      $tag = $current_tag
#    end
#  end
#
#  if type($href_tag) == "array" && size($href_tag) > 0
#    $tag_split_by_value_delimiter = split(first($href_tag), "=")
#    $tag_value = last($tag_split_by_value_delimiter)
#    $value_split_by_slashes = split($tag_value, "/")
#    $execution_id = last($value_split_by_slashes)
#  else
#    $execution_id = "N/A"
#  end
#end
