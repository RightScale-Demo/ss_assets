# SAP-Hana Cluster CAT (kinda)
Launches a cluster based on the off-the-shelf SAP-HANA AMIs in AWS.
It DOES NOT do any configuration of the servers at this time. 
It only stands them up with the RL10 agent installed and basic rightlink monitoring enabled and some related alerts.

# Prerequisites
- Login to AWS Console to accept Terms and Conditions for using the AMI.
  - https://aws.amazon.com/marketplace/fulfillment?pricing=hourly&productId=2f28c0e5-af3e-4d22-95f1-6c1af645c209&ref_=dtl_psb_continue&region=us-east-1&versionTitle=v20170121
    - If the ami id changed - update the sap_hana_mappings.pkg.rb file to match the AMI ID and Resource ID.
- VPC set up and configured in the mappings.pkg.rb file.
- Setup ServerTemplates As Follows
  - Clone RL10 Base Linux ST
    - Name it: SAP-Hana Master Node
  - Modify Boot Sequence as follows:
    - Remove NTP - not SUSE compatible code and not really needed)
    - Remove RedHat Subscription Register - just because you're tinkering with the ST anyway
    - Remove Setup Automatic Upgrade - again just because
  - Clone the SAP-Hana Master Node
    - Name it: SAP-Hana Worker Node


# Installation
- Upload the packages and CAT file.
- Launch the CAT file.

# Known Limitations
- NOT FOR PRODUCTION
- SAP-HANA servers are not set up to work as a SAP-HANA cluster. But they are ready to be configured.
- Security group rules are rather lax.

# TO-DO
- Configure the SAP-HANA servers to be fully operational.
- Tighten up the security group definitions/rules. 
  
