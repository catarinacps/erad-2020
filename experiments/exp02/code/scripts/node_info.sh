#!/bin/bash

check(){
  if [ -x "$(command -v $*)" ]; then
    ($*)
  else
    echo $*" not found"
  fi
}

_(){ sed "s/^/      /" <(check $*); }

#_(){ echo; }

echo "* Node: "$(hostname)

echo "** Env"
_ env

echo "** CPU Info"
_ cpufreq-info

echo "** Modules"
_ lsmod

echo "** GPUS"
_ nvidia-smi -q

echo "** Network"
_ ip address

echo "** PCI"
_ lspci

echo "** Memory"
_ lsmem


