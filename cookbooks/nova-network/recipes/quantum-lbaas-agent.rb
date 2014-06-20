# Cookbook Name:: nova-network
# Recipe:: quantum-lbaas-agent

include_recipe "osops-utils"
include_recipe "sysctl::default"
include_recipe "nova-network::quantum-common"

platform_options = node["quantum"]["platform"]
plugin = node["quantum"]["plugin"]

platform_options["quantum_lbaas_packages"].each do |pkg|
  package pkg do
    action node["osops"]["do_package_upgrades"] == true ? :upgrade : :install
    options platform_options["package_overrides"]
  end
end

#directory "/etc/quantum/plugins/services/agent_loadbalancer/" do
#  action :create
#  owner "root"
#  group "quantum"
#  mode "750"
#  recursive true
#end

#service "quantum-lbaas-agent" do
#  service_name platform_options["quantum-lbaas-agent"]
#  supports :status => true, :restart => true
#  action :nothing
#  subscribes :restart, "template[/etc/quantum/quantum.conf]", :delayed
#  subscribes :restart, "template[/etc/quantum/plugins/services/agent_loadbalancer/lbaas_agent.ini]", :delayed
#end

service "quantum-lbaas-agent" do
  service_name platform_options["quantum-lbaas-agent"]
  supports :status => true, :restart => true
  action :nothing
  subscribes :restart, "template[/etc/quantum/quantum.conf]", :delayed
  subscribes :restart, "template[/etc/quantum/lbaas_agent.ini]", :delayed
end


#template "/etc/quantum/plugins/services/agent_loadbalancer/lbaas_agent.ini" do
template "/etc/quantum/lbaas_agent.ini" do
  source "lbaas_agent.ini.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
  )
  notifies :restart, "service[quantum-lbaas-agent]", :delayed
  notifies :enable, "service[quantum-lbaas-agent]", :delayed
end


