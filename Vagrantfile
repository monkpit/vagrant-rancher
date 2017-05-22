Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  config.vm.communicator = "ssh"
  config.vm.hostname = "#{Socket.gethostname.split(/\./)[0]}.vm"
  config.vm.network "forwarded_port", guest: 53, host: 5300 #dnsmasq
  config.vm.network "forwarded_port", guest: 80, host: 8000 #nginx-proxy
  config.vm.network "forwarded_port", guest: 1080, host: 1080
  for i in 2000..2100
    config.vm.network :forwarded_port, guest: i, host: i
  end
  config.vm.network "forwarded_port", guest: 3000, host: 3000 #grafana
  config.vm.network "forwarded_port", guest: 5000, host: 5000 #logstash
  config.vm.network "forwarded_port", guest: 5380, host: 5380 #dnsmasq
  config.vm.network "forwarded_port", guest: 5601, host: 5601 #kibana
  config.vm.network "forwarded_port", guest: 8080, host: 8080 #squid
  config.vm.network "forwarded_port", guest: 8500, host: 8500 #consul
  config.vm.network "forwarded_port", guest: 8888, host: 8888 #rancher
  config.vm.network "forwarded_port", guest: 9090, host: 9090 #prometheus
  config.vm.network "forwarded_port", guest: 9200, host: 9200 #consul
  config.vm.network "forwarded_port", guest: 9300, host: 9300 #consul
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
