#
# Cookbook Name:: nova-network
# Recipe:: nova-controller
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

if node["nova"]["network"]["provider"] == "quantum"
  case node["quantum"]["plugin"] 
  when "nec"
    include_recipe "nova-network::quantum-trema"
  when "ryu"
    include_recipe "nova-network::quantum-ryu"
  end
  include_recipe "nova::api-metadata"
  include_recipe "nova-network::quantum-server"
  include_recipe "nova-network::quantum-plugin"
  include_recipe "nova-network::quantum-dhcp-agent"
  include_recipe "nova-network::quantum-l3-agent"
  if node["quantum"]["lbaas"]["enabled"] == "True"
    include_recipe "nova-network::quantum-lbaas-agent"
  end
  case node["quantum"]["plugin"] 
  when "ryu"
    include_recipe "nova-network::quantum-ryu-app"
  end

else
  include_recipe "nova-network::nova-setup"
end
