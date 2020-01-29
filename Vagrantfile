# -*- mode: ruby -*-
# vi: set ft=ruby :

# Para aprovechar este Vagrantfile necesita Vagrant y Virtualbox instalados:
#
#   * Virtualbox
#
#   * Vagrant
#
#   * Plugins de Vagrant:
#       + vagrant-proxyconf y su configuracion si requiere de un Proxy para salir a Internet
#       + vagrant-cachier
#       + vagrant-disksize
#       + vagrant-hostmanager
#       + vagrant-share
#       + vagrant-vbguest

VAGRANTFILE_API_VERSION = "2"

HOSTNAME = "harbor"
primera_vez = false
#en Ubuntu se puede usar en false siempre:
#primera_vez = false

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  if Vagrant.has_plugin?("vagrant-hostmanager")
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.manage_guest = true
    config.hostmanager.ignore_private_ip = false
    config.hostmanager.include_offline = true

    # uso cachier con NFS solamente si el hostmanager gestiona los nombres en /etc/hosts del host
    if not primera_vez && Vagrant.has_plugin?("vagrant-cachier")

      config.cache.auto_detect = false
      # W: Download is performed unsandboxed as root as file '/var/cache/apt/archives/partial/xyz' couldn't be accessed by user '_apt'. - pkgAcquire::Run (13: Permission denied)

      config.cache.synced_folder_opts = {
        owner: "_apt"
      }
      # Configure cached packages to be shared between instances of the same base box.
      # More info on http://fgrehm.viewdocs.io/vagrant-cachier/usage
      config.cache.scope = :box
   end

  end

 config.vm.define HOSTNAME do |srv|

    srv.vm.box = "ubuntu/bionic64"
    #srv.vm.box = "debian/buster64" # Antes de usar Buster, revisar Debian-Buster-fix.md
    srv.disksize.size = '20GB'


    srv.vm.network "private_network", ip: "192.168.33.11"
    srv.vm.network "forwarded_port", guest: 80, host: 8080
    srv.vm.network "forwarded_port", guest: 443, host: 8443


    srv.vm.boot_timeout = 3600
    srv.vm.box_check_update = true
    srv.ssh.forward_agent = true
    srv.ssh.forward_x11 = true
    srv.vm.hostname = HOSTNAME

    if Vagrant.has_plugin?("vagrant-hostmanager")
      srv.hostmanager.aliases = %W(#{HOSTNAME+".dominio.local.tld'"} #{HOSTNAME} )
    end

    if Vagrant.has_plugin?("vagrant-vbguest") then
        srv.vbguest.auto_update = ! primera_vez
        srv.vbguest.no_install = ! primera_vez
    end

    srv.vm.synced_folder ".", "/vagrant", type: "virtualbox", disabled: primera_vez

    srv.vm.provider :virtualbox do |vb|
      vb.gui = false
      vb.cpus = 2
      vb.memory = "1536"

      # https://www.virtualbox.org/manual/ch08.html#vboxmanage-modifyvm mas parametros para personalizar en VB
    end
  end

    ##
    # Aprovisionamiento
    #
    config.vm.provision "fix-no-tty", type: "shell" do |s|
        s.privileged = false
        s.inline = "sudo sed -i '/tty/!s/mesg n/tty -s \\&\\& mesg n/' /root/.profile"
    end
    config.vm.provision "actualiza", type: "shell" do |s|  # http://foo-o-rama.com/vagrant--stdin-is-not-a-tty--fix.html
        s.privileged = false
        s.inline = <<-SHELL
          export DEBIAN_FRONTEND=noninteractive
          export APT_LISTCHANGES_FRONTEND=none
          export APT_OPTIONS=' -y --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold '

          sudo -E apt-get --purge remove apt-listchanges -y > /dev/null 2>&1
          sudo -E apt-get update -y -qq > /dev/null 2>&1
          sudo dpkg-reconfigure --frontend=noninteractive libc6 > /dev/null 2>&1
          sudo -E apt-get -q --option "Dpkg::Options::=--force-confold" --assume-yes install libssl1.1  > /dev/null 2>&1 # https://bugs.launchpad.net/ubuntu/+source/openssl/+bug/1832919

          [ Debian = $(lsb_release -is) ] && sudo -E apt-get install linux-image-amd64 ${APT_OPTIONS}

          LINUX_IMAGE_PACKAGE=$( apt-cache search "linux-image-4.*generic"  | cut --delimiter=" " --fields=1 | sort -nr | head -n1 )
          LINUX_HEADERS_PACKAGE=$( echo ${LINUX_IMAGE_PACKAGE} | sed "s/image/headers/" )
          [ Ubuntu = $(lsb_release -is) ] && sudo apt-get install ${LINUX_IMAGE_PACKAGE} ${LINUX_HEADERS_PACKAGE} ${APT_OPTIONS}

          sudo -E apt-get      upgrade ${APT_OPTIONS} > /dev/null 2>&1
          sudo -E apt-get dist-upgrade ${APT_OPTIONS} > /dev/null 2>&1
          sudo -E apt-get autoremove -y > /dev/null 2>&1
          sudo -E apt-get autoclean -y > /dev/null 2>&1
          sudo -E apt-get clean > /dev/null 2>&1
        SHELL
    end
    config.vm.provision "ssh_pub_key", type: :shell do |s|
      begin
          ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip
          s.inline = <<-SHELL
            mkdir -p /root/.ssh/
            touch /root/.ssh/authorized_keys
            echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys
            echo #{ssh_pub_key} >> /root/.ssh/authorized_keys
          SHELL
      rescue
          puts "No hay claves publicas en el HOME de su pc"
          s.inline = "echo OK sin claves publicas"
      end
    end

    proxy_host_port = ENV['all_proxy'] || ENV['http_proxy']  || ""
    proxy_host_port = if proxy_host_port.empty? then "" else proxy_host_port.scan(/\/\/([0-9\.]*):/)[0][0]+':'+proxy_host_port.scan(/:([0-9]*)$/)[0][0] end

end
