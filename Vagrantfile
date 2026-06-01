Vagrant.configure("2") do |config|
  # Lightweight but stable
  config.vm.box = "ubuntu/jammy64"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 4096
    vb.cpus = 2
  end

  config.vm.hostname = "badass"

  config.vm.network "private_network", ip: "192.168.56.10"

#   config.vm.provision "shell", path: "install.sh"
end
