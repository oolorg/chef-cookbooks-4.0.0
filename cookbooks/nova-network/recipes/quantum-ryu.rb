# Cookbook Name:: nova-network
# Recipe:: quantum-ryu

include_recipe "osops-utils"
include_recipe "nova-network::quantum-common"

platform_options = node["quantum"]["platform"]
plugin = node["quantum"]["plugin"]


node["quantum"]["ryu_app"]["packages"].each do |pkg|
  package pkg do
    action node["osops"]["do_package_upgrades"] == true ? :upgrade : :install
    options platform_options["package_overrides"]
  end
end

#Ryu Setup
ryu_dir = "/opt/ryu"
#ryu_branch = "master"
ryu_branch = "v3.3"
ryu_conf = "/etc/ryu/ryu.conf"

directory ryu_dir do
  action :create
  owner "root"
  group "root"
  mode "750"
  recursive true
end

ryu_setup_py = "/opt/ryu/setup.py"

bash "install_ryu" do
  code <<-EOH
    _pwd=$(pwd)
    git clone https://github.com/osrg/ryu.git #{ryu_dir}
    cd #{ryu_dir}
    git checkout #{ryu_branch}
    python ./setup.py install
    cd $_pwd
    EOH
  not_if { ::File.exists?(ryu_setup_py) }
end

