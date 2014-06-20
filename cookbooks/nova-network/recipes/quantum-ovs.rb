# Cookbook Name:: nova-network
# Recipe:: quantum-ovs

include_recipe "osops-utils"
include_recipe "nova-network::quantum-common"

platform_options = node["quantum"]["platform"]

node["quantum"]["ovs_build"]["packages"].each do |pkg|
  package pkg do
    action node["osops"]["do_package_upgrades"] == true ? :upgrade : :install
    options platform_options["package_overrides"]
  end
end

ovs_work_dir="/root/openvswitch"
ovs_version="1.10.0"

bash "install_ovs" do
  code <<-EOH
    mkdir #{ovs_work_dir}
    cd #{ovs_work_dir}
    #wget http://openvswitch.org/releases/openvswitch-#{ovs_version}.tar.gz
    wget http://172.16.1.232/openvswitch/openvswitch-#{ovs_version}.tar.gz
    tar zxf openvswitch-#{ovs_version}.tar.gz
    cd openvswitch-#{ovs_version}/
    fakeroot debian/rules binary
    cd ..
    dpkg -i ./openvswitch-common_#{ovs_version}-1_amd64.deb
    dpkg -i ./openvswitch-switch_#{ovs_version}-1_amd64.deb
    apt-get install dkms -y
    dpkg -i ./openvswitch-datapath-dkms_#{ovs_version}-1_all.deb
    EOH
    not_if { ::File.exists?("#{ovs_work_dir}/openvswitch-datapath-dkms_#{ovs_version}-1_all.deb") }
end


