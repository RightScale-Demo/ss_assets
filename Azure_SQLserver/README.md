# Azure SQL CAT 
Launches an ARM SQL server using plugin.

# Prerequisites
- Install and set up Azure SQL server plugin
  - https://github.com/rightscale/rightscale-plugins
  - The TENANT_ID needed to modify the plugin resource_pool can be found in the AZURE_TENANT_ID cred in the account.

# To-does
- Something a bit more interesting than just creating a SQL server and database.
- Include the security and auditing policy stuff.
  - Needs managing storage account key and endpoint currently.
  - But there may be an update to the plugin to do this programmatically.
