#!/usr/bin/env bash

# env parameters
# to export in env file
export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export NB_MAKE_PROCS=12
export CMAKE_PREFIX_INSTALL=""

# path parameters
export INSTALL_DIR="$HOME/test/install"
export BUILD_DIR="$HOME/test/build"

# dependencies parameters
export KOKKOS_DIR=$SCRIPT_DIR/external/kokkos
export ADIOS_DIR=$SCRIPT_DIR/external/adios2

# launch installation
# 1. kokkos
bash $SCRIPT_DIR/scripts/install/install_kokkos.sh
export CMAKE_PREFIX_PATH=$INSTALL_DIR/kokkos:$CMAKE_PREFIX_PATH

# 2. adios2
bash $SCRIPT_DIR/scripts/install/install_adios2.sh
export CMAKE_PREFIX_PATH=$INSTALL_DIR/adios2:$CMAKE_PREFIX_PATH
