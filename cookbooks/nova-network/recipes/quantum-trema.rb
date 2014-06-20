# Cookbook Name:: nova-network
# Recipe:: quantum-trema

include_recipe "osops-utils"
include_recipe "nova-network::quantum-common"

platform_options = node["quantum"]["platform"]

node["quantum"]["trema"]["packages"].each do |pkg|
  package pkg do
    action node["osops"]["do_package_upgrades"] == true ? :upgrade : :install
    options platform_options["package_overrides"]
  end
end

node["quantum"]["sliceable_switch"]["packages"].each do |pkg|
  package pkg do
    action node["osops"]["do_package_upgrades"] == true ? :upgrade : :install
    options platform_options["package_overrides"]
  end
end

data_dir = "/opt/data"
trema_dir = "/opt/trema"
trema_apps_dir = "/opt/trema/apps"
trema_ss_dir = "/opt/trema/apps/sliceable_switch"

trema_data_dir = "/opt/data/trema"
trema_ss_etc_dir = "/opt/data/trema/sliceable_switch/etc"
trema_ss_db_dir = "/opt/data/trema/sliceable_switch/db"
trema_ss_script_dir = "/opt/data/trema/sliceable_switch/script"
trema_temp_dir = "/opt/data/trema/trema"
trema_ss_config = "/opt/data/trema/sliceable_switch/etc/sliceable.conf"
trema_ss_apache_config = "/etc/apache2/sites-available/sliceable_switch"
trema_apps_branch = "master"
trema_log_level="info"

execute "install_trema" do
  command "gem1.8 install trema"
  action :run
  not_if { ::File.exists?("/usr/local/bin/trema") }
end

directory trema_dir do
  action :create
  owner "root"
  group "root"
  mode "755"
  recursive true
end

directory trema_ss_etc_dir do
  action :create
  owner "root"
  group "root"
  mode "755"
  recursive true
end

directory trema_ss_db_dir do
  action :create
  owner "root"
  group "root"
  mode "777"
  recursive true
end

directory trema_ss_script_dir do
  action :create
  owner "root"
  group "root"
  mode "755"
  recursive true
end

directory trema_temp_dir do
  action :create
  owner "root"
  group "root"
  mode "750"
  recursive true
end

directory trema_apps_dir do
  action :create
  owner "root"
  group "root"
  mode "750"
  recursive true
end

bash "install_slicable_switch" do
  code <<-EOH
    _pwd=$(pwd)
    git clone https://github.com/trema/apps.git #{trema_apps_dir}
    cd #{trema_apps_dir}
    git checkout #{trema_apps_branch}
    make -C #{trema_dir}/apps/topology
    make -C #{trema_dir}/apps/flow_manager
    make -C #{trema_dir}/apps/sliceable_switch
    cd #{trema_ss_dir}
    rm -f filter.db slice.db
    ./create_tables.sh
    mv filter.db slice.db #{trema_ss_db_dir}
    chown -R www-data.www-data #{trema_ss_db_dir}
    cd $_pwd
    cp #{trema_ss_dir}/{Slice.pm,Filter.pm,config.cgi} #{trema_ss_script_dir}
    sed -i -e "s|/home/sliceable_switch/db|#{trema_ss_db_dir}|" #{trema_ss_script_dir}/config.cgi
    cp #{trema_ss_dir}/apache/sliceable_switch #{trema_ss_apache_config}
    sed -i -e "s|/home/sliceable_switch/script|#{trema_ss_script_dir}|" #{trema_ss_apache_config}
    a2enmod rewrite actions
    a2ensite sliceable_switch
    cp #{trema_ss_dir}/sliceable_switch_null.conf #{trema_ss_config}
    chmod ugo+rwx #{trema_ss_script_dir}/*
    chmod ugo+rwx #{trema_ss_db_dir}/*
    chmod ugo+rwx #{trema_ss_etc_dir}/*
    EOH
  not_if { ::File.exists?(trema_ss_config) }
end

template trema_ss_config do
  source "sliceable.conf.erb"
  owner "root"
  group "root"
  mode "0640"
  variables(
    "neutron_trema_apps_dir" => trema_apps_dir,
    "neutron_trema_ss_db_dir" => trema_ss_db_dir
  )
end

template "/root/start_trema.sh" do
  source "start_trema.sh.erb"
  owner "root"
  group "root"
  mode "0777"
  variables(
    "neutron_trema_log_level" => trema_log_level,
    "neutron_trema_temp_dir" => trema_temp_dir,
    "neutron_trema_ss_config" => trema_ss_config
  )
end

bash "start_trema" do
  code <<-EOH
    /usr/sbin/service apache2 restart
    LOGGING_LEVEL=#{trema_log_level} TREMA_TMP=#{trema_temp_dir} /usr/local/bin/trema run -d -c #{trema_ss_config}
    EOH
  not_if "ps -ef  | grep -v grep | grep '/usr/loca/bin/trema'"
end

#trema + OFS
#if node["quantum"]["nec"]["openflow_interface"] != "none" then

  nec_ofc_ofp_host = node["quantum"]["nec"]["ofc_host"]

  template "/root/ofs_info" do
    source "ofs_info.erb"
    owner "root"
    group "root"
    mode "0777"
    variables(
      "ofc_host" => nec_ofc_ofp_host,
    )
  end

  #dummy
  nec_ofs_name="ofsw1"

  template "/root/enum_sdn.py" do
    source "enum_sdn.py.erb"
    owner "root"
    group "root"
    mode "0777"
    variables(
    )
  end
  nec_ofs_cluster_name=node.chef_environment

#  bash "configure_ofs_setup_parameter" do
#    code <<-EOH
#      sed -i 's/SW_NAME=Switch1/SW_NAME=#{nec_ofs_name}/' /root/ofs_info
#      EOH
#  end
  bash "configure_ofs_setup_parameter" do
    code <<-EOH
      ENUM_SDN=$(/root/enum_sdn.py #{nec_ofs_cluster_name})
      sed -i 's/SW_NAME=[^=]*$/SW_NAME='"${ENUM_SDN}"'/' /root/ofs_info
      EOH
  end

  template "/root/ofs_info_update.sh" do
    source "ofs_info_update.sh.erb"
    owner "root"
    group "root"
    mode "0777"
    variables(
      "cluster_name" => nec_ofs_cluster_name
    )
  end

  template "/root/OFSsetup" do
    source "OFSsetup.erb"
    owner "root"
    group "root"
    mode "0777"
    variables(
    )
  end

  # Call OFS Setup Script
  bash "configure_ofs" do
    code <<-EOH
      /root/OFSsetup /root/ofs_info
      mv /root/OFSsetup /root/OFSsetup.done
      EOH
    not_if { ::File.exists?("/root/OFSsetup.done") }
  end


#end

