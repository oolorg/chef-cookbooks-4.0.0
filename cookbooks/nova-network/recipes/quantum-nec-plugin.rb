# Cookbook Name:: nova-network
# Recipe:: quantum-nec-plugin

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

service "openvswitch-switch" do
  service_name "openvswitch-switch"
  supports :status => true, :restart => true
  action [:enable, :start]
end

#execute "create integration bridge" do
#  command "ovs-vsctl add-br #{node["quantum"]["nec"]["integration_bridge"]}"
#  action :run
#  not_if "ovs-vsctl show | grep 'Bridge br-int'"
#end

nec_integration_bridge = node["quantum"]["nec"]["integration_bridge"]
nec_ofc_ofp_host = node["quantum"]["nec"]["ofc_host"]
nec_ofc_ofp_port = node["quantum"]["nec"]["ofc_ofp_port"]
nec_host_ip = node["quantum"]["nec"]["host"]
nec_host_ip_r =  nec_host_ip.gsub(/\./, ' ')

bash "nec_plugin_ovs_setup" do
  code <<-EOH
    ovs-vsctl --no-wait -- --may-exist add-br #{nec_integration_bridge}
    ovs-vsctl br-set-external-id #{nec_integration_bridge} bridge-id #{nec_integration_bridge}
    ovs-vsctl set-controller #{nec_integration_bridge} tcp:#{nec_ofc_ofp_host}:#{nec_ofc_ofp_port}
    dpid=$(printf "%07d%03d%03d%03d\n" #{nec_host_ip_r})
    ovs-vsctl set Bridge #{nec_integration_bridge} other-config:datapath-id=$dpid
    ovs-vsctl set-fail-mode #{nec_integration_bridge} secure
    EOH
  not_if "ovs-vsctl list-br | grep #{nec_integration_bridge}"
end

if node["quantum"]["nec"]["openflow_interface"] != "none" then

  nec_openflow_interface = node["quantum"]["nec"]["openflow_interface"]
  bash "nec_plugin_ovs_setup" do
    code <<-EOH
      ovs-vsctl --no-wait -- --may-exist add-port #{nec_integration_bridge} #{nec_openflow_interface}
      EOH
    not_if "ovs-vsctl list-ports #{nec_integration_bridge} | grep #{nec_openflow_interface}"
  end
end

service "quantum-plugin-nec-agent" do
  service_name node["quantum"]["nec"]["service_name"]
  supports :status => true, :restart => true
  action :enable
  subscribes :restart, "template[/etc/quantum/quantum.conf]", :delayed
  subscribes :restart, "template[/etc/quantum/plugins/nec/nec.ini]", :delayed
end


