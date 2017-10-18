# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.box = "ubuntu/xenial/v20171012"

  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.memory = "1024"
  end

  # k8 master:
  config.vm.define "master" do |master|

    master.vm.network "public_network",
      auto_config: false

    master.vm.provision "shell",
      run: "always",
      inline: "echo -e \"auto enp0s8
      iface enp0s8 inet static
      address 192.168.1.80
      netmask 255.255.255.0
      gateway 192.168.1.254
      dns-nameservers 8.8.4.4 8.8.8.8\" >> /etc/network/interfaces"

    master.vm.provision "shell",
      run: "always",
      inline: "ifconfig enp0s8 192.168.1.80 netmask 255.255.255.0 up"

    #master.vm.provision "shell",
    #  run: "always",
    #  inline: "route add default gw 192.168.1.254"

    master.vm.provision "shell",
      run: "always",
      inline: "eval `route -n | awk '{ if ($8 ==\"enp0s3\" && $2 != \"0.0.0.0\") print \"route del default gw \" $2; }'`"

    # trigger reload
    master.vm.provision "reload"

    master.vm.provision "shell",
      path: "init-master.sh",
      args: ["192.168.1.80"]

  end

  # k8 minion:
  (1..2).each do |i|
    hostname = "worker-%02d" % i
    config.vm.define hostname do |node|
      ip = "192.168.1.#{i+80}"

      node.vm.network "public_network",
        auto_config: false

      node.vm.provision "shell",
        run: "always",
        args: [ip],
        inline: "echo -e \"auto enp0s8
        iface enp0s8 inet static
        address $1
        netmask 255.255.255.0
        gateway 192.168.1.254
        dns-nameservers 8.8.4.4 8.8.8.8\" >> /etc/network/interfaces"

      node.vm.provision "shell",
        run: "always",
        inline: "eval `route -n | awk '{ if ($8 ==\"enp0s3\" && $2 != \"0.0.0.0\") print \"route del default gw \" $2; }'`"

      # trigger reload
      node.vm.provision :reload

      node.vm.provision "shell",
        path: "./init-worker.sh",
        args: [ip, hostname]
    end
  end

  # nfs
  config.vm.define "nfs" do |nfs|
    ip = "192.168.1.50"
    nfs.vm.network "public_network", ip: ip
    nfs.vm.provision "shell", path: "./init-nfs.sh", args: [ip, "nfs"]
  end


end
