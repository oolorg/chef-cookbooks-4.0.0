# Cookbook Name:: nova-network
# Recipe:: quantum-ryu-plugin

include_recipe "osops-utils"
include_recipe "nova-network::quantum-ovs"
include_recipe "nova-network::quantum-common"

platform_options = node["quantum"]["platform"]
plugin = node["quantum"]["plugin"]


node["quantum"][plugin]["packages"].each do |pkg|
  package pkg do
    action node["osops"]["do_package_upgrades"] == true ? :upgrade : :install
    options platform_options["package_overrides"]
  end
end

ryu_integration_bridge = node["quantum"]["ryu"]["integration_bridge"]

#OVS Setup
service "openvswitch-switch" do
  service_name "openvswitch-switch"
  supports :status => true, :restart => true
  action [:enable, :start]
end

bash "ovs_setup_for_ryu" do
  code <<-EOH
    ovs-vsctl --no-wait -- --may-exist add-br #{ryu_integration_bridge}
    ovs-vsctl br-set-external-id #{ryu_integration_bridge} bridge-id #{ryu_integration_bridge}
    EOH
  not_if "ovs-vsctl list-br | grep #{ryu_integration_bridge}"
end

#execute "create integration bridge" do
#  command "ovs-vsctl add-br #{node["quantum"]["ryu"]["integration_bridge"]}"
#  action :run
#  not_if "ovs-vsctl show | grep 'Bridge br-int'"
#end

#Ryu Agent Setup
service "quantum-plugin-ryu-agent" do
  service_name node["quantum"]["ryu"]["service_name"]
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, "template[/etc/quantum/quantum.conf]", :delayed
  subscribes :restart, "template[/etc/quantum/plugins/ryu/ryu.ini]", :delayed
end

