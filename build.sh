#!/usr/bin/env bash

set -e

arch="$1"
install_manager="yum"
linux_distro='fedora'
debian_version="${2:-buster}"
debian_variant="${3:-minbase}"

version=`cat VERSION`

echo "Starting build system for ${version}"

function check_args {
  if [[ "$arch" == "" || "$debian_version" == "" ]]; then
    echo "usage: $0 <cpu architecture> [debian version] [debian variant]"
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
    sudo $install_manager install -y qemu-user-binfmt
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
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo add-apt-repository \
                              "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
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
            [Yy]* ) sudo reboot; break;;
            [Nn]* ) echo "Please reboot before re-running this script"; exit 1;;
            * ) echo "Please answer yes or no.";;
        esac
      done
    fi
  fi
#  docker login
}

function build_docker {
  echo "Building Docker container... "
  docker_versioned_tag="${arch}/embedci:${version}-${debian_version}-${debian_variant}"
  docker_latest_tag="${arch}/embedci:latest-${debian_version}-${debian_variant}"

  qemu_static="/usr/bin/qemu-arm-static"
  case "$arch" in
    armel|armhf) qemu_static="/usr/bin/qemu-arm-static";;
    arm64) qemu_static="/usr/bin/qemu-aarch64-static";;
    *) qemu_static="/usr/bin/qemu-${arch}-static";;
  esac

  qemu_static_basename=$(basename "$qemu_static")

  cp "$qemu_static" .

  docker build . \
    -t "$docker_versioned_tag" \
    -t "$docker_latest_tag" \
    --build-arg "QEMU_STATIC=${qemu_static_basename}" \
    --build-arg "ARCH=${arch}" \
    --build-arg "DEBIAN_VERSION=${debian_version}" \
    --build-arg "DEBIAN_VARIANT=${debian_variant}"
  docker run -v "${qemu_static}:${qemu_static}" "$docker_versioned_tag" -c "uname -a"
  echo "Successfully built container ${docker_latest_tag}!"
}

check_args
detect_os
init_debootstrap
init_qemu_user_static
init_docker
build_docker