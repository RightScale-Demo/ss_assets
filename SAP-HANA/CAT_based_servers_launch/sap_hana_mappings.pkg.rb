name "SAP-HANA PKG - Mappings"
rs_ca_ver 20161221
short_description "Mappings for SAP-HANA"

package "sap_hana/mappings"

mapping "map_image" do {
  "AWS" => {
    "name" => "suse-sles-sap-12-sp1-v20170121-hvm-ssd-x86_64-2f28c0e5-af3e-4d22-95f1-6c1af645c209-ami-be32c5a8.3",
    "resource_uid" => "ami-cef80ed8"
  },
  "AzureRM" => {
    "name" => "TBD",
    "resource_uid" => "TBD"
  }
}
end

mapping "map_cloud" do {
  "AWS" => {
    "cloud" => "EC2 us-east-1",
    "network" => "Demo-vpc", 
    "subnet" => "Demo-subnet-1a",
    "sg" => '@sec_group',  
    "ssh_key" => "@ssh_key"
  },
  "AzureRM" => {   
    "cloud" => "AzureRM East US",
    "network" => "pft_arm_network",
    "subnet" => "default",
    "sg" => '@sec_group',  
    "ssh_key" => null
  }
}
end

mapping "map_instancetype" do {
  "Standard Performance" => {
    "AWS" => "t2.large",
    "Azure" => "D1",
    "AzureRM" => "D1",
    "Google" => "n1-standard-1",
    "VMware" => "small",
  },
  "High Performance" => {
    "AWS" => "r3.2xlarge",
    "Azure" => "D2",
    "AzureRM" => "D1",
    "Google" => "n1-standard-2",
    "VMware" => "large",
  }
} end