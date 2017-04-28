# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.box = "centos-1611-02"

  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.memory = "1024"
  end

  # k8 master:
  config.vm.define "master" do |master|
    master.vm.network "public_network", ip: "192.168.1.80"
    master.vm.provision "shell", path: "./init-master.sh"
  end

  # k8 minion:
  (1..2).each do |i|
    hostname = "worker-%02d" % i
    config.vm.define hostname do |node|
      ip = "192.168.1.#{i+80}"
      node.vm.network "public_network", ip: ip
      node.vm.provision "shell", path: "./init-worker.sh", args: [ip, hostname]
    end
  end

  # nfs
  config.vm.define "nfs" do |nfs|
    ip = "192.168.1.50"
    nfs.vm.network "public_network", ip: ip
  end


end
