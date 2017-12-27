# NOTE: Currently being lazy and opening the system to 0.0.0.0/0 instead of doing a two-tiered approach with a
# jump server in a DMZ.
# The CFT has all sorts of specific ports and two-tiered approach. Will implement that later.

name "SAP-HANA PKG - Security Groups"
rs_ca_ver 20161221
short_description "Security Group configuration for SAP-HANA"

package "sap_hana/security_groups"

import "sap_hana/mappings"
import "pft/parameters"

resource "sec_group", type: "security_group" do
  name join(["HanaSecGrp-",last(split(@@deployment.href,"/"))])
  description "SAP Hana Securiy Group security group."
  cloud map($map_cloud, $param_location, "cloud")
  network map($map_cloud, $param_location, "network")
end

resource "sec_group_rule_all_inbound_tcp", type: "security_group_rule" do
  name join(["AllInbound-",last(split(@@deployment.href,"/"))])
  description "Wide open fun."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "1",
    "end_port" => "65535"
  } end
end

resource "sec_group_rule_udp111", type: "security_group_rule" do
  name join(["Udp111rule-",last(split(@@deployment.href,"/"))])
  description "UDP 111"
  source_type "cidr_ips"
  security_group @sec_group
  protocol "udp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "111",
    "end_port" => "111"
  } end
end

resource "sec_group_rule_udp2049", type: "security_group_rule" do
  name join(["Udp2049rule-",last(split(@@deployment.href,"/"))])
  description "UDP 2049"
  source_type "cidr_ips"
  security_group @sec_group
  protocol "udp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "2049",
    "end_port" => "2049"
  } end
end

resource "sec_group_rule_udp400x", type: "security_group_rule" do
  name join(["Udp400xrule-",last(split(@@deployment.href,"/"))])
  description "UDP 4000-4002"
  source_type "cidr_ips"
  security_group @sec_group
  protocol "udp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "4000",
    "end_port" => "4002"
  } end
end

parameter "param_location" do 
  like $parameters.param_location
end

mapping "map_cloud" do 
  like $mappings.map_cloud
end