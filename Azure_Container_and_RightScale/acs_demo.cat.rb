name 'RS: Azure Container Service - Kubernetes Test CAT'
rs_ca_ver 20161221
short_description "Azure Container Service  - Kubernetes Test CAT"
import "sys_log"
import "plugins/rs_azure"

parameter "subscription_id" do
  like $rs_azure.subscription_id
end

parameter "refresh_token" do
  label "Refresh Token"
  type "string"
end

parameter "master_count" do
  label "Master Count"
  type "number"
  default 1
  allowed_values 1,3,5
end

parameter "agent_count" do
  label "Agent Count"
  type "number"
  default 2
end

parameter "agent_size" do
  label "Agent VM-Instance Size"
  type "string"
  default "Standard_DS2"
  allowed_values "Standard_A0", "Standard_A1", "Standard_A2", "Standard_A3", "Standard_A4", "Standard_A5",
    		"Standard_A6", "Standard_A7", "Standard_A8", "Standard_A9", "Standard_A10", "Standard_A11",
    		"Standard_D1", "Standard_D2", "Standard_D3", "Standard_D4",
    		"Standard_D11", "Standard_D12", "Standard_D13", "Standard_D14",
    		"Standard_D1_v2", "Standard_D2_v2", "Standard_D3_v2", "Standard_D4_v2", "Standard_D5_v2",
    		"Standard_D11_v2", "Standard_D12_v2", "Standard_D13_v2", "Standard_D14_v2",
    		"Standard_G1", "Standard_G2", "Standard_G3", "Standard_G4", "Standard_G5",
    		"Standard_DS1", "Standard_DS2", "Standard_DS3", "Standard_DS4",
    		"Standard_DS11", "Standard_DS12", "Standard_DS13", "Standard_DS14",
    		"Standard_GS1", "Standard_GS2", "Standard_GS3", "Standard_GS4", "Standard_GS5"
end

permission "read_creds" do
  actions   "rs_cm.show_sensitive","rs_cm.index_sensitive"
  resources "rs_cm.credentials"
end

resource "my_resource_group", type: "rs_cm.resource_group" do
  cloud_href "/api/clouds/3526"
  name @@deployment.name
  description join(["container resource group for ", @@deployment.name])
end

# https://docs.microsoft.com/en-us/azure/container-service/kubernetes/container-service-kubernetes-walkthrough
# https://github.com/Azure/azure-quickstart-templates/blob/master/101-acs-kubernetes/azuredeploy.json
# https://github.com/Azure/azure-quickstart-templates/blob/master/101-acs-kubernetes/azuredeploy.parameters.json
resource "my_container", type: "rs_azure_containerservices.containerservice" do
  name join(["myc", last(split(@@deployment.href, "/"))])
  resource_group @my_resource_group.name
  location "Central US"
  properties do {
   "orchestratorProfile" => {
      "orchestratorType" =>  "Kubernetes"
    },
    "servicePrincipalProfile" => {
      "clientId" => cred("AZURE_APPLICATION_ID"),
      "secret" => cred("AZURE_APPLICATION_KEY")
    },
    "masterProfile" => {
      "count" =>  $master_count,
      "dnsPrefix" =>  join([@@deployment.name, "-master"])
    },
    "agentPoolProfiles" =>  [
      {
        "name" =>  "agentpools",
        "count" =>  $agent_count,
        "vmSize" =>  $agent_size,
        "dnsPrefix" =>  join([@@deployment.name, "-agent"])
      }
    ],
    "diagnosticsProfile" => {
      "vmDiagnostics" => {
          "enabled" =>  "false"
      }
    },
    "linuxProfile" => {
      "adminUsername" =>  "azureuser",
      "ssh" => {
        "publicKeys" =>  [
          {
            "keyData" =>  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1CfyxgqRTbPSXpLqEa9VbvtJxEcxI1JsB/9Dw0hha4PCIGw5pX7X/Dl8UbnkbvzUuzvDQ3Ap6jZpYB4sHRTN/8fv1F9HnQ5xkDRfyH2fnZmhrihlxzwy1AvufNhGqwPEZLl8znxRG94UR2oqa1KBtVX+zvjoAdrhAsuhNcix/3VpTkeoCyEjNknl3Jy8VYCX4CH0cQpyl/gjWGmXF4YxyyLeZ4LzRfUQl2lXH/eF4h0MwZsYSJChiR1UU6FSD4+NJbJa01gLCMJmox8DwKABK/iPnulR/gsTG/HLEXTtkqIrOaIuBnNsfnq2dkOcGgXDFbTi9X0irWZow/lQcJ0M5 container"
          }
        ]
      }
    }
  } end
end

resource "rightlink_vm_extension", type: "rs_azure_compute.extensions" do
  name join(["rightlink-", last(split(@@deployment.href, "/"))])
  resource_group @@deployment.name
  location "Central US"
  virtualMachineName "sample"
  properties do {
    "publisher" => "Microsoft.OSTCExtensions",
    "type" => "CustomScriptForLinux",
    "typeHandlerVersion" => "1.5",
    "autoUpgradeMinorVersion" => true,
    "settings" => {
       "fileUris" => [ "https://rightlink.rightscale.com/rll/10.6.0/rightlink.enable.sh" ],
       "commandToExecute" => join(['./rightlink.enable.sh -k "', $refresh_token,'" -t "RightLink 10.6.0 Linux Base" -d "',@@deployment.name,'" -c "azure_v2"'])
    }
  } end
end

operation "launch" do
 description "Launch the application"
 definition "launch_handler"
end

operation "terminate" do
  description "terminate"
  definition "delete_handler"
end

operation "scale" do
  description "Scale the agents"
  definition "scale_up"
end

define scale_up(@my_container,@rightlink_vm_extension,$agent_count,$master_count,$refresh_token) return @my_container do
  sub on_error: stop_debugging() do
    @container = @my_container.get()
    $object = to_object(@my_container)
    call sys_log.detail("object:" + to_s($object)+"\n")
    $fields = $object["details"][0]
    $old_master_count=$fields["properties"]["masterProfile"]["count"]
    $old_agent_count=$fields["properties"]["agentPoolProfiles"][0]["count"]
    call sys_log.detail("fields:" + to_s($fields) + "\n")
    $new_fields={}
    $new_fields["location"]=$fields["location"]
    $new_fields["name"]=$fields["name"]
    $new_fields["properties"]=$fields["properties"]
    $new_fields["id"]=$fields["id"]
    $new_fields["properties"]["masterProfile"]["count"] = $master_count
    $new_fields["properties"]["agentPoolProfiles"][0]["count"] = $agent_count
    call sys_log.detail("new_fields:" + to_s($new_fields) + "\n")
    call start_debugging()
    @new_container = @container.update($new_fields)
    call stop_debugging()
    $resource_group = split($fields["id"], '/')[4]
    call start_debugging()
    $status = @new_container.get().state
    call sys_log.detail(join(["container:", to_s(to_object(@new_container)),"\n"]))
    call sys_log.detail(join(["Status: ", $status]))
    sub on_error: skip, timeout: 60m do
      while $status != "Succeeded" do
        $status = @new_container.state
        call stop_debugging()
        call sys_log.detail(join(["Status: ", $status]))
        call start_debugging()
        sleep(10)
      end
    end
    call stop_debugging()
    call get_instance_count() retrieve $ic_count
    while $ic_count < (($agent_count-$old_agent_count)+($master_count-$old_master_count)) do
      call sys_log.detail(join(["instance_count:", $ic_count, " expected_count:", to_s((($agent_count-$old_agent_count)+($master_count-$old_master_count)))]))
      sleep(10)
      call get_instance_count() retrieve $ic_count
    end
    @servers = rs_cm.instances.get(filter: ["deployment_href=="+@@deployment.href])
    foreach @server in @servers do
      call sys_log.detail(join(["entering for:", @server.name]))
      task_label("Adding rightlink")
      @@st = rs_cm.server_template.empty()
      sub on_error: skip do
        @@st = @server.server_template()
      end
      if empty?(@@st)
        call sys_log.detail(join(["entering empty:", @server.name, '-', @server.state]))
        while @server.state != 'running' do
          call sys_log.detail(join([@server.name,"-",@server.state]))
          sleep(10)
        end
        $fields={}
        $fields["name"] = join(["rightlink-", last(split(@@deployment.href, "/"))])
        $fields["resource_group"] = @@deployment.name
        $fields["location"] = "Central US"
        $fields["virtualMachineName"] = @server.name
        $fields["properties"] = {}
        $fields["properties"]["publisher"] = "Microsoft.OSTCExtensions"
        $fields["properties"]["type"] = "CustomScriptForLinux"
        $fields["properties"]["typeHandlerVersion"] = "1.5"
        $fields["properties"]["autoUpgradeMinorVersion"] = true
        $fields["properties"]["settings"] = {}
        $fields["properties"]["settings"]["fileUris"] = [ "https://rightlink.rightscale.com/rll/10.6.0/rightlink.enable.sh" ]
        $fields["properties"]["settings"]["commandToExecute"] = join(['./rightlink.enable.sh -k "', $refresh_token,'" -t "RightLink 10.6.0 Linux Base" -d "',@@deployment.name,'" -c "azure_v2"'])
        call start_debugging()
        @vme=rs_azure_compute.extensions.create($fields)
        @new_resource = @vme.show(resource_group: @@deployment.name, virtualMachineName: @server.name, name: join(["rightlink-", last(split(@@deployment.href, "/"))]))
        $status = @new_resource.state
        while $status != "Succeeded" do
          call sys_log.detail(join([@server.name,"-VME-",$status]))
          $status = @new_resource.state
          if $status == "Failed"
            call stop_debugging()
            raise "Execution Name: "+ @@deployment.name + ", Status: " + $status + ", VirtualMachine: " + @server.name
          end
          sleep(30)
        end
        @vme = @new_resource.show(resource_group: @@deployment.name, virtualMachineName: @server.name, name: join(["rightlink-", last(split(@@deployment.href, "/"))]))
        while @server.state != 'operational' do
          call sys_log.detail(join([@server.name,"-",@server.state]))
          sleep(10)
        end 
        call run_rightscript_by_name(@server, "RL10 Linux Enable Docker Support (Beta)")
      end
    end
    @my_container = @new_container
  end
end

define get_instance_count() return $ic_count do
  @servers = rs_cm.instances.get(filter: ["deployment_href=="+@@deployment.href])
  $ic_count=0
  foreach @server in @servers do
    @@st = rs_cm.server_template.empty()
    sub on_error: skip do
      @@st = @server.server_template()
    end
    if empty?(@@st)
     $ic_count = $ic_count + 1
    end
  end
end

define run_rightscript_by_name(@target, $script_name) do
  @script = rs_cm.right_scripts.index(latest_only: true, filter: [join(["name==", $script_name])])
  @task = @target.run_executable(right_script_href: @script.href )
  sleep_until(@task.summary =~ "^(Completed|Aborted)")
  if @task.summary =~ "Aborted"
    raise "Failed to run " + $script_name
  end
end

define launch_handler(@my_resource_group,@my_container,@rightlink_vm_extension) return @my_resource_group,@my_container,@rightlink_vm_extension do
  call start_debugging()
  provision(@my_resource_group)
  provision(@my_container)
  call rl_and_docker(@rightlink_vm_extension)
  @rightlink_vm_extension=@rightlink_vm_extension
  if $$debugging != false
    call stop_debugging()
  end
end

define rl_and_docker(@rightlink_vm_extension) do
  @servers = rs_cm.instances.get(filter: ["deployment_href=="+@@deployment.href])
  foreach @server in @servers do
    call sys_log.detail(join(["entering for:", @server.name]))
    task_label("Adding rightlink")
    @@st = rs_cm.server_template.empty()
    sub on_error: skip do
      @@st = @server.server_template()
    end
    if empty?(@@st)
      call sys_log.detail(join(["entering empty:", @server.name, '-', @server.state]))
      while @server.state != 'running' do
        call sys_log.detail(join([@server.name,"-",@server.state]))
        sleep(10)
      end
      $name = @server.name
      $vme = to_object(@rightlink_vm_extension)
      call sys_log.detail(join(["vme:",to_s($vme)]))
      $vme["fields"]["virtualMachineName"] = to_s($name)
      @vme = $vme
      provision(@vme)
      while @server.state != 'operational' do
        call sys_log.detail(join([@server.name,"-",@server.state]))
        sleep(10)
      end 
      call run_rightscript_by_name(@server, "RL10 Linux Enable Docker Support (Beta)")
    end
  end
end

define delete_handler(@my_resource_group,@my_container,@rightlink_vm_extension) do
  delete(@my_container)
  delete(@my_resource_group)
end

define start_debugging() do
  if $$debugging == false || logic_and($$debugging != false, $$debugging != true)
    initiate_debug_report()
    $$debugging = true
  end
end

define stop_debugging() do
  if $$debugging == true
    $debug_report = complete_debug_report()
    call sys_log.detail($debug_report)
    $$debugging = false
  end
end