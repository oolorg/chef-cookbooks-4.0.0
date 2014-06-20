#
# Cookbook Name:: nova-network
# Recipe:: quantum-server (API service)
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
include_recipe "mysql::client"
include_recipe "mysql::ruby"
include_recipe "osops-utils"
include_recipe "nova-network::quantum-common"

platform_options = node["quantum"]["platform"]

if node["developer_mode"]
  node.set_unless["quantum"]["db"]["password"] =
    "quantum"
else
  node.set_unless["quantum"]["db"]["password"] =
    secure_password
end

node.set_unless['quantum']['service_pass'] =
  secure_password
node.set_unless["quantum"]["quantum_metadata_proxy_shared_secret"] =
  secure_password

packages = platform_options["quantum_api_packages"]

platform_options["quantum_api_packages"].each do |pkg|
  package pkg do
    action node["osops"]["do_package_upgrades"] == true ? :upgrade : :install
    options platform_options["package_overrides"]
  end
end

ks_admin_endpoint =
  get_access_endpoint("keystone-api", "keystone", "admin-api")
ks_service_endpoint =
  get_access_endpoint("keystone-api", "keystone", "service-api")
keystone =
  get_settings_by_role("keystone-setup", "keystone")

# Create db and user
# return connection info
# defined in osops-utils/libraries
mysql_info = create_db_and_user(
  "mysql",
  node["quantum"]["db"]["name"],
  node["quantum"]["db"]["username"],
  node["quantum"]["db"]["password"]
)

#for_neutron
neutron_plugin_config_file = node["quantum"]["plugin_config"]
case node["quantum"]["plugin"]
when "nec"
  neutron_plugin_config_file = "/etc/quantum/plugins/nec/nec.ini"
when "ryu"
  neutron_plugin_config_file = "/etc/quantum/plugins/ryu/ryu.ini"
end

template "/etc/default/quantum-server" do
  source "quantum-server.erb"
  owner "root"
  group "root"
  mode "0640"
  variables(
    "db_ip_address" => mysql_info["host"],
    "neutron_plugin_config" => neutron_plugin_config_file
  )
end
#for_neutron

service "quantum-server" do
  service_name platform_options["quantum_api_service"]
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, "template[/etc/quantum/quantum.conf]", :delayed
  subscribes :restart, "template[/etc/quantum/api-paste.ini]", :delayed
#for_neutron
  case node["quantum"]["plugin"]
  when "nec"
    subscribes :restart, "template[/etc/quantum/plugins/nec/nec.ini]", :delayed
  when "ryu"
    subscribes :restart, "template[/etc/quantum/plugins/ryu/ryu.ini]", :delayed
  else
    subscribes :restart, "template[/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini]", :delayed
  end
#for_neutron
end

keystone_tenant "Register Service Tenant" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  tenant_name node["quantum"]["service_tenant_name"]
  tenant_description "Service Tenant"
  tenant_enabled true
  action :create
end

keystone_user "Register Service User" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  tenant_name node["quantum"]["service_tenant_name"]
  user_name node["quantum"]["service_user"]
  user_pass node["quantum"]["service_pass"]
  user_enabled true
  action :create
end

keystone_role "Grant 'admin' role to service user for service tenant" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  tenant_name node["quantum"]["service_tenant_name"]
  user_name node["quantum"]["service_user"]
  role_name node["quantum"]["service_role"]
  action :grant
end

keystone_register "Reqister Quantum Service" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  service_name "quantum"
  service_type "network"
  service_description "Quantum Network Service"
  action :create_service
end

api_endpoint = get_bind_endpoint("quantum", "api")
keystone_register "Register Quantum Endpoint" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  service_type "network"
  endpoint_region "RegionOne"
  endpoint_adminurl api_endpoint["uri"]
  endpoint_internalurl api_endpoint["uri"]
  endpoint_publicurl api_endpoint["uri"]
  action :create_endpoint
end
