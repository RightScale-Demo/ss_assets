# VPC Set Up CAT
Creates a segregated VPC with a public and private subnet, Internet gateway, NAT gateway, and security group.
Launches a server in the public subnet and X servers in the private subnet.

Implements the AWS use-case described here: 
https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-nat-gateway.html#nat-gateway-basics

# Prerequisites
- VPC Plugin
  - Use Colocated plugin or use the official version but point resource pool at the same region used by the CAT.
- PFT Linux ServerTemplate and MCI has been set up.
  - See https://github.com/rs-services/rs-premium_free_trial/tree/master/Account_Management
  - Upload and run the mci_management_base_linux.cat.rb CAT.
  - Upload and run the st_management_base_linux.cat.rb CAT.
- Various PFT package files.
  

