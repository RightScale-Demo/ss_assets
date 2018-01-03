name "SAP-HANA New VPC CFT Package"
rs_ca_ver 20161221
short_description  "SAP-HANA New VPC CFT Stack declaration."
long_description "Uses CFT plugin to launch the SAP-HANA \"New VPC\" CFT stack.
See the following link for more information on this and related CFTs:
https://docs.aws.amazon.com/quickstart/latest/sap-hana/welcome.html"

package "cft/sap_hana_newvpc"

import "plugins/rs_aws_cft"


### resource declarations ###
resource "ssh_key", type: "ssh_key" do
  name join(["sap_sshkey_", last(split(@@deployment.href,"/"))])
  cloud "EC2 us-east-1"
end

### placement declarations ###
resource "placement_group", type: "placement_group" do 
  name join(["sap_pg_", last(split(@@deployment.href,"/"))])
  cloud "EC2 us-east-1"
end

#### CFT Stack Section ####
# Currently using the CFT that creates the VPCs, etc.
# TO-DO: Use the CFT that prompts for the VPCs, etc and/or create the VPCs, etc using CAT resource declarations.
resource "stack", type: "rs_aws_cft.stack" do
  stack_name join(["saphana-", last(split(@@deployment.href, "/"))])
  template_url "https://s3.amazonaws.com/sap-hana-demo/SAP-HANA-NewVPC.template"
  description "SAP-HANA CFT Launch"
  capabilities "CAPABILITY_IAM"
  parameter_1_name "KeyName"
  parameter_1_value @ssh_key.name
  parameter_2_name "PlacementGroupName"
  parameter_2_value @placement_group.name
  parameter_3_name "VPCCIDR"
  parameter_4_name "HANAInstallMedia"
  parameter_5_name "AvailabilityZone"
  parameter_6_name "AutoRecovery"
  parameter_7_name "Encryption"
  parameter_8_name "DMZCIDR"
  parameter_9_name "PrivSubCIDR"
  parameter_10_name "RemoteAccessCIDR"
  parameter_11_name "DomainName"
  parameter_12_name "HANAMasterHostname"
  parameter_13_name "HANAWorkerHostname"
  parameter_14_name "PrivateBucket"
  parameter_15_name "Proxy"
  parameter_16_name "MyOS"
  parameter_17_name "MyInstanceType"
  parameter_18_name "InstallHANA"
  parameter_19_name "HostCount"
  parameter_20_name "SID"
  parameter_21_name "SAPInstanceNum"
  parameter_22_name "HANAMasterPass"
  parameter_23_name "VolumeType"
  parameter_24_name "InstallRDPInstance"
  parameter_3_value $vpccidr
  parameter_4_value $hanainstallmedia
  parameter_5_value $availabilityzone
  parameter_6_value $autorecovery
  parameter_7_value $encryption
  parameter_8_value $dmzcidr
  parameter_9_value $privsubcidr
  parameter_10_value $remoteaccesscidr
  parameter_11_value $domainname
  parameter_12_value $hanamasterhostname
  parameter_13_value $hanaworkerhostname
  parameter_14_value $privatebucket
  parameter_15_value $proxy
  parameter_16_value $myos
  parameter_17_value $myinstancetype
  parameter_18_value $installhana
  parameter_19_value $hostcount
  parameter_20_value $sid
  parameter_21_value $sapinstancenum
  parameter_22_value $hanamasterpass
  parameter_23_value $volumetype
  parameter_24_value $installrdpinstance
end

## Parameters being passed to CFT
## I could also make some decisions about things and not expose all parameters, but just keeping things 
## straight forward for now.
parameter "vpccidr" do
    label "VPCCIDR"
    description "CIDR block for the Amazon VPC to create for SAP HANA deployment"
    type "string"
    default "10.0.0.0/16"
    allowed_pattern "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})"
end

parameter "hanainstallmedia" do
    label "HANAInstallMedia"
    description "Full path to Amazon S3 location of SAP HANA software files (e.g., s3://myhanabucket/sap-hana-sps11/)."
    default ""
    type "string"
end

parameter "availabilityzone" do
    label "AvailabilityZone"
    description "The Availability Zone where SAP HANA subnets will be created."
    default "us-east-1c"
    type "string"
end

parameter "autorecovery" do
    label "AutoRecovery"
    type "string"
    description "Enable (Yes) or disable (No) automatic recovery feature for SAP HANA nodes."
    default "Yes"
    allowed_values "Yes", "No"
end

parameter "encryption" do
    label "Encryption"
    type "string"
    description "Enable (Yes) or disable (No) encryption on EBS volumes."
    default "No"
    allowed_values "Yes", "No"
end

parameter "dmzcidr" do
    label "DMZCIDR"
    description "CIDR block for the public DMZ subnet located in the new VPC."
    type "string"
    default "10.0.2.0/24"
    allowed_pattern "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})"
end

parameter "privsubcidr" do
    label "PrivSubCIDR"
    description "CIDR block for the private subnet where SAP HANA will be deployed."
    type "string"
    default "10.0.1.0/24"
    allowed_pattern "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})"
end

parameter "remoteaccesscidr"  do
    label "RemoteAccessCIDR"
    description "CIDR block from where you want to access your bastion and RDP instances."
    type "string"
    min_length "9"
    max_length "18"
    default "0.0.0.0/0"
    allowed_pattern "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})"
    constraint_description "This must be a valid CIDR range in the format x.x.x.x/x."
end

## Not bothering to expose this parameter.
## Just use the CFT defaults
##    "BASTIONInstanceType": {
##        "Description": "Amazon EC2 instance type for the bastion host.",
##        "Type": "String",
##        "Default": "t2.small",
##        "AllowedValues": [
##            "t2.small",
##            "t2.medium",
##            "t2.large",
##            "m4.large",
##            "c4.large"
##        ]
##    },


parameter "domainname"  do
    label "DomainName"
    type "string"
    description "Name to use for fully qualified domain names."
    default "local"
end

parameter "hanamasterhostname" do
    label "HANAMasterHostname"
    type "string"
    description "Host name to use for SAP HANA master node (DNS short name)."
    default "imdbmaster"
end

parameter "hanaworkerhostname"  do
    label "HANAWorkerHostname"
    type "string"
    description "Host name to use for SAP HANA worker node(s) (DNS short name)."
    default "imdbworker"
end

parameter "privatebucket" do
    label "PrivateBucket"
    description "Main build bucket where templates and scripts are located."
    type "string"
    default "quickstart-reference/sap/hana/latest" # "sap-hana-scripts" 
end

parameter "proxy" do
    label "Proxy"
    description "Proxy address for http access (e.g., http://xyz.abc.com:8080 or http://10.x.x.x:8080)."
    type "string"
    default ""
end

### Leaving CFT defaults
##    "EnableLogging": {
##        "Description": "Enable (Yes) or disable (No) logging with AWS CloudTrail and AWS Config.",
##        "Default": "No",
##        "Type": "String",
##        "AllowedValues": [
##            "Yes",
##            "No"
##        ]
##    },
##    "CloudTrailS3Bucket": {
##        "Description": "Name of S3 bucket where AWS CloudTrail trails and AWS Config log files can be stored (e.g., mycloudtrail).",
##        "Default": "",
##        "Type": "String"
##    },


# NOTE some of these images require accepting the terms and conditions in AWS
parameter "myos" do
    label "MyOS"
    type "string"
    description "Operating system (SLES or RHEL) and version for master/worker nodes."
    default "RedHatLinux72"
    allowed_values "SuSELinux11SP4",
        "SuSELinux12",
        "SuSELinux12SP1",
        "SuSELinux12SP1ForSAP",
        "SuSELinux12SP2ForSAP",
        "RedHatLinux66",
        "RedHatLinux67",
        "RedHatLinux72"
end

parameter "myinstancetype"  do
    label "MyInstanceType"
    type "string"
    description "Instance type for SAP HANA host."
    default "r4.2xlarge"
    allowed_values "r3.8xlarge",
        "r3.4xlarge",
        "r3.2xlarge",
        "r4.16xlarge",
        "r4.8xlarge",
        "r4.4xlarge",
        "r4.2xlarge",
        "x1.16xlarge",
        "x1.32xlarge",
        "x1e.4xlarge",
        "x1e.32xlarge"
end

#### CFT defaults
##    "RDPInstanceType": {
##        "Type": "String",
##        "Description": "Instance type for Windows RDP instance.",
##        "Default": "c4.large",
##        "AllowedValues": [
##            "c4.large",
##            "c4.xlarge",
##            "m4.large",
##            "m4.xlarge"
##        ]
##    },

parameter "installrdpinstance" do
    label "InstallRDPInstance"
    type "string"
    description "Install (Yes) or don't install (No) optional Windows RDP instance."
    default "No"
    allowed_values "Yes", "No"
end

parameter "installhana"  do
    label "InstallHANA"
    type "string"
    description "Install (Yes) or don't install (No) HANA. When set to No, only AWS infrastructure is provisioned."
    default "No"
    allowed_values "Yes", "No"
end

parameter "hostcount"  do
    label "HostCount"
    type "number"
    description "Total number of SAP HANA nodes you want to deploy in the SAP HANA cluster."
    default 1
    min_value 1
    max_value 5
end

parameter "sid"  do
    label "SID"
    type "string"
    default "HDB"
    description "SAP HANA system ID for installation and setup."
    allowed_pattern "([A-Z]{1}[0-9A-Z]{2})"
    constraint_description "This value must consist of 3 characters."
end

parameter "sapinstancenum"  do
    label "SAPInstanceNum"
    type "string"
    default "00"
    description "SAP HANA instance number to use for installation and setup, and to open ports for security groups."
    allowed_pattern "([0-8]{1}[0-9]{1}|[9]{1}[0-7]{1})"
    constraint_description "Instance number must be between 00 and 97."
end

parameter "hanamasterpass"  do
    label "HANAMasterPass"
    type "string"
    description "SAP HANA password to use during installation."
    no_echo "true"
    min_length "8"
    allowed_pattern "^(?=.*?[a-z])(?=.*?[A-Z])(?=.*[0-9]).*"
    constraint_description "This must be at least 8 characters, including uppercase, lowercase, and numeric values."
end

parameter "volumetype"  do
    label "VolumeType"
    type "string"
    description "EBS volume type: General Purpose SSD (gp2) or Provisioned IOPS SSD (io1)."
    default "gp2"
    allowed_values "gp2", "io1"
end



