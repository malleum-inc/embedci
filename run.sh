#!/usr/bin/env bash

set -e

arch="$1"
version="$2"
variant="$3"


function check_args {
  if [[ "$arch" == "" || "$version" == "" || "$variant" == "" ]]; then
    echo "usage: $0 <cpu architecture> <debian version> <debian variant>"
    exit 1
  fi
}

function run_container {
  qemu_static="arm"
  case "$arch" in
    armel|armhf) qemu_static="/usr/bin/qemu-arm-static";;
    arm64) qemu_static="/usr/bin/qemu-aarch64-static";;
    *) qemu_static="/usr/bin/qemu-${arch}-static";;
  esac
  docker run -v "${qemu_static}:${qemu_static}" -it "${arch}/embedci:latest-${version}-${variant}"
}

check_args
run_container

