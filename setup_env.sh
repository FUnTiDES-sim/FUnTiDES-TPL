#!/bin/bash
# ============================================================================
# TPL Environment Setup Script
# ============================================================================
# This script sets up all environment variables needed to use the TPL libraries
#
# Usage:
#   source setup_tpl_env.sh [INSTALL_PREFIX]
#
# Example:
#   source setup_tpl_env.sh $HOME/test
#   source setup_tpl_env.sh /opt/tpl
#
# If no prefix is provided, it defaults to ./install
# ============================================================================

# Determine installation prefix
if [ -n "$1" ]; then
    TPL_PREFIX="$1"
elif [ -n "$TPL_INSTALL_PREFIX" ]; then
    TPL_PREFIX="$TPL_INSTALL_PREFIX"
else
    # Default to ./install relative to this script's directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TPL_PREFIX="${SCRIPT_DIR}/install"
fi

# Convert to absolute path
TPL_PREFIX="$(cd "${TPL_PREFIX}" 2>/dev/null && pwd)" || {
    echo "ERROR: Installation directory not found: $1"
    echo "Please provide a valid installation prefix:"
    echo "  source setup_tpl_env.sh /path/to/install"
    return 1
}

# Check if installation exists
if [ ! -d "${TPL_PREFIX}" ]; then
    echo "ERROR: Installation directory does not exist: ${TPL_PREFIX}"
    echo "Please run install.sh first or provide correct path"
    return 1
fi

# ============================================================================
# Set up environment variables
# ============================================================================

# Executables (mpirun, mpicc, etc.)
export PATH="${TPL_PREFIX}/bin:${PATH}"

# Shared libraries
export LD_LIBRARY_PATH="${TPL_PREFIX}/lib:${TPL_PREFIX}/lib64:${LD_LIBRARY_PATH}"

# CMake package configuration files
export CMAKE_PREFIX_PATH="${TPL_PREFIX}:${CMAKE_PREFIX_PATH}"

# pkg-config
export PKG_CONFIG_PATH="${TPL_PREFIX}/lib/pkgconfig:${TPL_PREFIX}/lib64/pkgconfig:${PKG_CONFIG_PATH}"

# Python packages (if installed)
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)
if [ -n "$PYTHON_VERSION" ]; then
    if [ -d "${TPL_PREFIX}/lib/python${PYTHON_VERSION}/site-packages" ]; then
        export PYTHONPATH="${TPL_PREFIX}/lib/python${PYTHON_VERSION}/site-packages:${PYTHONPATH}"
    fi
fi

# Store the prefix for reference
export TPL_INSTALL_PREFIX="${TPL_PREFIX}"

# ============================================================================
# Display information
# ============================================================================

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                  TPL Environment Activated                             ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Installation prefix: ${TPL_PREFIX}"
echo ""
echo "Environment variables set:"
echo "  PATH               = ${TPL_PREFIX}/bin:..."
echo "  LD_LIBRARY_PATH    = ${TPL_PREFIX}/lib:..."
echo "  CMAKE_PREFIX_PATH  = ${TPL_PREFIX}:..."
echo "  PKG_CONFIG_PATH    = ${TPL_PREFIX}/lib/pkgconfig:..."
if [ -n "$PYTHON_VERSION" ] && [ -d "${TPL_PREFIX}/lib/python${PYTHON_VERSION}/site-packages" ]; then
    echo "  PYTHONPATH         = ${TPL_PREFIX}/lib/python${PYTHON_VERSION}/site-packages:..."
fi
echo ""
echo "Available tools:"

# Check what's available
if command -v mpirun &> /dev/null; then
    MPIRUN_PATH=$(which mpirun)
    if [[ "$MPIRUN_PATH" == "${TPL_PREFIX}"* ]]; then
        echo "  ✓ MPI              ($(mpirun --version 2>&1 | head -1))"
    fi
fi

if [ -f "${TPL_PREFIX}/lib/cmake/Kokkos/KokkosConfig.cmake" ]; then
    echo "  ✓ Kokkos"
fi

if [ -f "${TPL_PREFIX}/lib/cmake/adios2/adios2-config.cmake" ]; then
    echo "  ✓ ADIOS2"
fi

if [ -f "${TPL_PREFIX}/lib/cmake/pybind11/pybind11Config.cmake" ]; then
    echo "  ✓ pybind11"
fi

if [ -f "${TPL_PREFIX}/lib/cmake/GTest/GTestConfig.cmake" ]; then
    echo "  ✓ GoogleTest"
fi

if [ -f "${TPL_PREFIX}/lib/cmake/benchmark/benchmarkConfig.cmake" ]; then
    echo "  ✓ Google Benchmark"
fi

if [ -n "$PYTHON_VERSION" ]; then
    if python3 -c "import pykokkos" 2>/dev/null; then
        echo "  ✓ pykokkos"
    fi
fi

echo ""
echo "To use in CMake projects:"
echo "  cmake -DCMAKE_PREFIX_PATH=${TPL_PREFIX} .."
echo ""
echo "Or rely on the CMAKE_PREFIX_PATH environment variable (already set)"
echo ""
