# Docker WordPress with RDS Backend
Launches a Docker host running a WordPress container and uses a plugin to launch
an AWS RDS as the DB backend for the WordPress server. 

# Prerequisites
Networking
- VPC defined with at least two subnets
- Update the VPC "default" security group to inbound 3306 from at least the VPC CIDR.
RDS
- RDS subnet group defined for the VPC
ServerTemplate and RightScripts
- Docker Node ServerTemplate
  - MultiCloud marketplace version should be ok

# Installation
- Install AWS RDS plugin
  - https://github.com/rightscale/rightscale-plugins
- PFT pkgs: 
  - lib_util_creds.pkg.rb
  - lib_util_account.pkg.rb
  - lib_util_err.pkg.rb
- Update the "cat_info" mapping with the applicable values.
  
