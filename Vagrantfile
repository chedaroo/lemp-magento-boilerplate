# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"

  # CHANGE THIS:
  config.vm.hostname = "magento.local"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  #
  # /!\ The IP should be in the same range as the VirtualBox Host-Only Network adapter
  #     => see ipconfig in Windows
  #
  config.vm.network :private_network, ip: "192.168.56.101"

  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
    v.cpus = 4
  end

  config.vm.provision :shell, :path => "bin/vagrant-bootstrap.sh"
  # config.vm.provision :shell, :path => "bin/create-waterlee-starter-theme.sh"
  config.vm.provision "shell", inline: "sudo service nginx restart", run: "always"
  #config.vm.provision "shell", inline: "nc -z -w5 localhost 1025 || mailcatcher --ip=0.0.0.0", run: "always"

  config.vm.synced_folder "./src", "/home/vagrant/src", type: "rsync",
    rsync__exclude: [".git/", ".settings/"],
	rsync_args: ["--verbose", "--archive", "--delete", "-z", "--copy-links", "--omit-dir-times"]
  config.vm.synced_folder "./.modman", "/home/vagrant/.modman", type: "rsync",
    rsync__exclude: [".git/", "/src"],
	rsync_args: ["--verbose", "--archive", "--delete", "-z", "--copy-links", "--omit-dir-times"]
  config.vm.synced_folder "./vendor", "/home/vagrant/vendor", type: "rsync",
    rsync__exclude: [".git/"],
	rsync_args: ["--verbose", "--archive", "--delete", "-z", "--copy-links", "--omit-dir-times"]

  # Update location of rsync on host (cygwin rsync and openshh must be installed on host for this to work)
  ENV["VAGRANT_DETECTED_OS"] = ENV["VAGRANT_DETECTED_OS"].to_s + " cygwin"
end
