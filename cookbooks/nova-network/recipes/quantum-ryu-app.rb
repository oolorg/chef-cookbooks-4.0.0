# Cookbook Name:: nova-network
# Recipe:: quantum-ryu-app

include_recipe "osops-utils"
include_recipe "nova-network::quantum-common"

platform_options = node["quantum"]["platform"]

#refere to quantum-ryu-plugin.rb
ryu_dir = "/opt/ryu"
ryu_conf = "/etc/ryu/ryu.conf"

#bash "start_ryu" do
#  user "root"
#  group "root"
#  code <<-EOH
#    #{ryu_dir}/bin/ryu-manager --config-file #{ryu_conf} &
#    EOH
#  not_if "ps -ef  | grep -v grep | grep 'ryu-manager'"
#end

template "/root/start_ryu.sh" do
  source "start_ryu.sh.erb"
  owner "root"
  group "root"
  mode "0777"
  variables(
    "neutron_ryu_dir" => ryu_dir,
    "neutron_ryu_conf" => ryu_conf
  )
  notifies :restart, "service[quantum-server]", :delayed
  notifies :restart, "service[quantum-dhcp-agent]", :delayed
  notifies :restart, "service[quantum-l3-agent]", :delayed
  notifies :restart, "service[quantum-plugin-ryu-agent]", :delayed
end



