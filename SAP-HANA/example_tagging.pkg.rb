name "SAP-HANA PKG - Business Tags"
rs_ca_ver 20161221
short_description "Example Business Tags for SAP-HANA"

package "sap_hana/tagging"

parameter "param_bc" do 
  category "User Inputs"
  label "Billing Code" 
  constraint_description "Billing Code must be of the form 4 uppercase characters and 3 numerals (e.g. ABCD123)."
  type "string" 
  min_length 7
  max_length 7
  # This enforces a stricter windows password complexity in that all 4 elements are required as opposed to just 3.
  allowed_pattern '[A-Z]{4}[0-9]{3}'
  default "ABCD123"
end

parameter "param_env" do 
  category "User Inputs"
  label "Environment" 
  type "string" 
  allowed_values "PRD", "NPD", "SBX", "SYS", "DEV", "TEST", "UAT", "STAGE", "LOAD", "QA"
  default "TEST"
end

parameter "param_proj" do 
  category "User Inputs"
  label "Project" 
  type "string" 
  min_length 1 # This forces the user to enter a value. 
  default "Abc"
end

define deployment_resources_tagger($param_bc, $param_env, $param_proj)  do
  # Get the launching user's first and last name from the system and use that for the "businessowner" tag.
    $session = rs_cm.sessions.index(view: "whoami")
    $user_id = select($session[0]["links"], {"rel":"user"})[0]["href"]
    @user = rs_cm.get(href: $user_id)
    $business_owner = @user.first_name + " " + @user.last_name
  
    # Tag the servers appropriately.
    $tags=["ec2:MEMBERFIRM=US", "ec2:COUNTRY=US", "ec2:FUNCTION=CON", "ec2:SUBFUNCTION=DCP", "ec2:BUSINESSOWNER="+$business_owner, "ec2:BILLINGCODE="+$param_bc,"ec2:ENVIRONMENT="+$param_env, "ec2:PROJECTNAME="+$param_proj]
    rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)
end 
