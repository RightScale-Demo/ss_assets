# Docker WordPress with RDS Backend
Launches a Docker host running a WordPress container and uses a plugin to launch
an AWS RDS as the DB backend for the WordPress server. 

# Prerequisites
- VPC defined
- RDS subnet group defined for the VPC
- "default" security group for the VPC allow inbound 3306 from at least the VPC CIDR.
- Docker Node ServerTemplate
  - MultiCloud marketplace version should be ok
- Install AWS RDS plugin
  - https://github.com/rightscale/rightscale-plugins
- PFT pkg: 
  - lib_util_creds.pkg.rb
  - lib_util_account.pkg.rb
  - lib_util_err.pkg.rb
  
