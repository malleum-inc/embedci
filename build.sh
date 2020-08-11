#!/usr/bin/env bash

set -e

arch="$1"
chroot_dir="chroot_${1}"
install_manager="yum"
linux_distro='fedora'
debian_version="${2:-buster}"
docker_file="Dockerfile-$arch"

deboostrap_variant="minbase"
debootstrap_flags="--variant=${deboostrap_variant}"

version=`cat VERSION`

echo "Starting build system for ${version}"

function check_args {
  if [[ "$arch" == "" || "$debian_version" == "" ]]; then
    echo "usage: $0 <cpu architecture> [cpu architecture]"
    exit 1
  fi
}

function is_fedora {
  if [[ "$linux_distro" == 'fedora' ]]; then
    return 0;
  fi;
  return 1
}

function detect_os {
  echo -n 'Detecting base Linux variant... '
  if is_package_installed apt &>/dev/null; then
    install_manager=apt
    linux_distro='debian'
    echo 'Debian'
  else
    echo 'Fedora'
  fi;
}

function is_package_installed {
  echo -n "Detecting if '$1' is installed... "
  if which $1 &>/dev/null; then
    echo "yes!"
    return 0;
  fi;
  echo "no."
  return 1;
}

function init_debootstrap {
  if ! is_package_installed debootstrap; then
    echo "Installing debootstrap..."
    sudo $install_manager install -y debootstrap
  fi;
}

function init_qemu_user_static {
  if ! is_package_installed qemu-arm-static; then
    echo "Installing qemu-user-static..."
    sudo $install_manager install -y qemu-user-static
  fi;
}

function init_docker {
  pending_reboot=0
  if ! is_package_installed docker; then
    echo "Installing Docker..."
    if is_fedora; then
      sudo dnf -y install dnf-plugins-core
      sudo dnf -y config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      sudo sed -ie 's/$releasever/31/g' /etc/yum.repos.d/docker-ce.repo
      sudo dnf -y install docker-ce docker-ce-cli containerd.io grubby
      sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
      sudo firewall-cmd --permanent --zone=trusted --add-interface=docker0
      sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-masquerade
      sudo firewall-cmd --permanent --zone=trusted --add-interface=docker0
      sudo firewall-cmd --permanent --zone=FedoraWorkstation --add-masquerade
      sudo firewall-cmd --reload
      pending_reboot=1
    else
      sudo apt update
      sudo apt install -y \
                          apt-transport-https \
                          ca-certificates \
                          curl \
                          gnupg-agent \
                          software-properties-common
      curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
      sudo add-apt-repository \
                              "deb [arch=amd64] https://download.docker.com/linux/debian \
                               $(lsb_release -cs) \
                               stable"
      sudo apt update
      sudo apt install -y docker-ce docker-ce-cli containerd.io
    fi;
    echo -n "Enabling Docker... "
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "$USER"
    newgrp docker
    echo "done."

    if [[ $pending_reboot == 1 ]]; then
      while true; do
        read -p "Fedora requires a reboot after installing Docker for the first time. Would you like to reboot? (y|n): " yn
        case $yn in
            [Yy]* ) sudo shutdown -P now; break;;
            [Nn]* ) echo "Please reboot before re-running this script"; exit 1;;
            * ) echo "Please answer yes or no.";;
        esac
      done
    fi
  fi
  docker login
}

function init_fakeroot {
  if ! is_package_installed fakeroot; then
    echo "Installing fakeroot and fakechroot... "
    sudo $install_manager install -y fakeroot fakechroot
  fi;
}

function create_chroot {
  if [[ ! -f "$docker_file" ]]; then
    echo "Specified architecture is not supported yet: ${arch}"
    exit 1
  fi;

  if [[ ! -d $chroot_dir ]]; then
    echo -n "Creating Debian root filesystem for ${arch}... "
    fakechroot fakeroot debootstrap $debootstrap_flags --arch="$arch" "$debian_version" "$chroot_dir" || :
    echo "done."
  fi
}

function build_docker {
  echo "Building Docker container... "
  docker_versioned_tag="${arch}/embedci:${version}"
  docker_latest_tag="${arch}/embedci:latest"
  cp -f "$docker_file" "${chroot_dir}/Dockerfile"
  pushd "$chroot_dir"
  echo Dockerfile > .dockerignore
  docker build . -t "$docker_versioned_tag" -t "$docker_latest_tag"
  docker run -v "/usr/bin/qemu-${arch}-static:/usr/bin/qemu-${arch}-static" "$docker_versioned_tag" true
  popd
}

check_args
detect_os
init_debootstrap
init_qemu_user_static
init_docker
init_fakeroot
create_chroot
build_docker