###########
# RightLink Enablement Package for AWS
#
# Provides definitions to apply user-data for RightLink enablement to raw instances in AWS.
#
# PREREQUISITES
# 



name "AWS RightLink Enablement Package"
rs_ca_ver 20161221
short_description  "Package to RightLink enable one or more AWS raw instances."
long_description "Injects user-data scripts to execute rightlink enablement logic on the instance.
Requires cloud-init to be pre-installed on the raw instances."

package "rl_enable/aws"

# Used to output debug info
import "pft/err_utilities", as: "debug"

# Orchestrate the RightLink enablement process.
# Inputs:
#   @instances - collection of one or more instances
#   server_template_name - name of the ServerTemplate to use when wrapping the instance(s).
# Processing:
#   Stops instances.
#   Injects user-data that runs RightLink enablement script.
#   Starts instances.
define rightlink_enable(@instances, $server_template_name) do
   
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
   call install_rl_installscript(@instance, $server_template_name, switch(@instance.name==null, @instance.resource_uid, @instance.name))
 end
 
 # Once the user-data is set, start the instance so RL enablement will be run
 call debug.log("starting instances", to_s(to_object(@stopped_instances)))
 @stopped_instances.start()
   
 $wake_condition = "/^(operational|stranded|stranded in booting)$/"
 sleep_until all?(@stopped_instances.state[], $wake_condition)

end

# Uses EC2 ModifyInstanceAttribute API to install user data that runs RL enablement script
define install_rl_installscript(@instance, $server_template, $servername) do
 
 $instance_id = @instance.resource_uid # needed for the API URL

 # generate the user-data that runs the RL enablement script.
 call build_rl_enablement_userdata($server_template, $servername) retrieve $user_data_base64

 # Go tell AWS to update the user-data for the instance
 $url = "https://ec2.amazonaws.com/?Action=ModifyInstanceAttribute&InstanceId="+$instance_id+"&UserData.Value="+$user_data_base64+"&Version=2014-02-01"
 
 call debug.log("url", $url)
 
 $signature = {
   "type":"aws",
   "access_key": cred("AWS_ACCESS_KEY_ID"),
   "secret_key": cred("AWS_SECRET_ACCESS_KEY")
   }
 $response = http_post(
   url: $url,
   signature: $signature
   )
   
  call debug.log("AWS API response", to_s($response))
end

define build_rl_enablement_userdata($server_template_name, $server_name) return $user_data_base64 do
 
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
 
    
  # base64 encode the user-data since AWS requires that 
  $user_data_base64 = to_base64($user_data)  
  # Remove the newlines that to_base64() puts in the result
  $user_data_base64 = gsub($user_data_base64, "
","")
  # Replace any = with html code %3D so the URL is valid.
  $user_data_base64 = gsub($user_data_base64, /=/, "%3D")
  
end