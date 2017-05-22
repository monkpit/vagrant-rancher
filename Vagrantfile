Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  config.vm.communicator = "ssh"
  config.vm.hostname = "#{Socket.gethostname.split(/\./)[0]}.vm"
  config.vm.network "forwarded_port", guest: 53, host: 5300
  config.vm.network "forwarded_port", guest: 80, host: 8000
  config.vm.network "forwarded_port", guest: 1080, host: 1080
  for i in 2000..2100
    config.vm.network :forwarded_port, guest: i, host: i
  end
  config.vm.network "forwarded_port", guest: 5000, host: 5000
  config.vm.network "forwarded_port", guest: 5380, host: 5380
  config.vm.network "forwarded_port", guest: 5601, host: 5601
  config.vm.network "forwarded_port", guest: 8080, host: 8080
  config.vm.network "forwarded_port", guest: 8500, host: 8500
  config.vm.network "forwarded_port", guest: 8888, host: 8888
  config.vm.network "forwarded_port", guest: 9200, host: 9200
  config.vm.network "forwarded_port", guest: 9300, host: 9300
  config.vm.provider "virtualbox" do |vb|
    vb.cpus = "2"
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.memory = "4096"
  end
  config.vm.provision "file", source: "~/.gitconfig", destination: "/home/vagrant/.gitconfig"
  config.vm.provision "file", source: "~/.ssh/id_rsa", destination: "/home/vagrant/.ssh/id_rsa"
  config.vm.provision :shell, path: "scripts/bootstrap.sh"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
end
