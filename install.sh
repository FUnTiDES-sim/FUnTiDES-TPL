#!/usr/bin/env bash

# env parameters
# to export in env file
export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export NB_MAKE_PROCS=12

# path parameters
export INSTALL_DIR="/home/alexis/install"
export BUILD_DIR="/home/alexis/build"

# dependencies parameters
export KOKKOS_DIR=$SCRIPT_DIR/external/kokkos

# launch installation
bash $SCRIPT_DIR/scripts/install/install_kokkos.sh
