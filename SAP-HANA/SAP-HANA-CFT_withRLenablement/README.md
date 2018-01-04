# SAP-HANA CFT Launch with RightLink Enablement.
Launches a SAP-HANA cluster using one of the AWS-provided CFTs.
Once the instances are launched, the CAT then executes RightLink enablement to install the agent and
set up monitoring, etc.

# IMPORTANT NOTE
This is an expensive CAT to launch. The SAP-HANA nodes are not cheap.
The CAT has a built-in timer that will stop it after one hour of running.
Although the initial launch takes a long time, starting from stopped is pretty quick.

# Caveats
It takes a really long time to launch - like an hour.
This appears to have something to do with the SAP scripts that run on the restart that is executed to run the RL enablement script.
I suspect the SAP stuff since the Bastion server (i.e. no SAP stuff) only takes a few minutes to RightLink enable.

# Prerequisites
If you are using the SUSE for SAP AMIs, you will need to accept the terms and conditions:
- http://aws.amazon.com/marketplace/pp?sku=dgdq2f6vrm6evuoncsy2kouzw
Similarly, if using RHEL AMI, you need to accept Ts&Cs.

If you want to access the SAP cluster as a user, you need SAP client and need to tunnel through the Bastion server.
How to do all this is an exercise left to the reader.

# Set up/Installation
- Push the "SAP-HANA Wrapper" ServerTemplate located in this folder into the account.
- Upload the following package and CAT files
  - pft/err_utilities - https://github.com/rs-services/rs-premium_free_trial/blob/master/CATs/library/lib_util_err.pkg.rb
  - syslog - https://github.com/rightscale/rightscale-plugins/blob/master/libraries/sys_log.rb
  - plugins/rs_aws_cft - https://github.com/rightscale/rightscale-plugins/blob/master/aws/rs_aws_cft/aws_cft_plugin.rb
  - rl_enable/aws - https://github.com/RightScale-Demo/ss_assets/blob/master/shared/aws_rightlink_enablement/aws_rightlink_enablement.pkg.rb
  - cft/sap_hana_newvpc - https://github.com/RightScale-Demo/ss_assets/blob/master/SAP-HANA/SAP-HANA-CFT_withRLenablement/sap_hana_cft_stack_newVPC.pkg.rb
  - CAT: SAP-HANA - Launched by CFT and RightLink Enabled - https://github.com/RightScale-Demo/ss_assets/blob/master/SAP-HANA/SAP-HANA-CFT_withRLenablement/sap_hana_from_cft_withRLenablement.cat.rb
 - Create a Credential in the account named "PFT_RS_REFRESH_TOKEN" that contains a RightScale refresh token with permissions for RightLink enablement.
   - Or you can modify the CAT to reference a different token.
   
# Launch
- Fill in the parameters
  - You can leave them all to the defaults.
  - The only required entry is the master password.