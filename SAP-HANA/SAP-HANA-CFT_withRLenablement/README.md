# SAP-HANA CFT Launch with RightLink Enablement.
Launches a SAP-HANA cluster using one of the AWS-provided CFTs.
Once the instances are launched, the CAT then executes RightLink enablement to install the agent and
set up monitoring, etc.

# Caveats
It takes a really long time to launch - like an hour.
This appears to have something to do with the SAP scripts that run on the restart that is executed to run the RL enablement script.
The Bastion server (i.e. no SAP stuff) only takes a few minutes.

# TO-DOs
Figure out why the restart for the RL enablement of the SAP servers takes so long to complete.

# Prerequisites
If you are using the SUSE for SAP AMIs, you will need to accept the terms and conditions:
http://aws.amazon.com/marketplace/pp?sku=dgdq2f6vrm6evuoncsy2kouzw

Similarly, if using RHEL AMI, you need to accept Ts&Cs.

# Set up
- Create an MCI named "MCI Placeholder" that is just a blank-ish MCI.
