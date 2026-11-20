#!/bin/bash
set -e  # Exit on error

# ==============================================================================
# TPL Installation Script
# Builds and installs all third-party dependencies
# ==============================================================================

# Color output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color

# Default values
INSTALL_PREFIX="$(pwd)/install"
ENABLE_CUDA="auto"
ENABLE_CUDA_UVM="no"
CUDA_ARCH="70;75;80;86;89"
BUILD_PYTHON="yes"
BUILD_PYKOKKOS="yes"
BUILD_TESTS="yes"
BUILD_ADIOS2="no"
NUM_JOBS=8
PYKOKKOS_BUILD_THREADS=2
FORCE_REBUILD="no"
PYTHON_PREFIX=""
ENABLE_VENV="no"
VENV_NAME="tpl-venv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTERNAL_DIR="${SCRIPT_DIR}/external"
BUILD_DIR="${TPL_BUILD_DIR:-${SCRIPT_DIR}/build}"

# ==============================================================================
# Helper functions
# ==============================================================================

print_header() {
    echo -e "${BLUE}===================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}===================================================================${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed or not in PATH"
        return 1
    fi
    return 0
}

# Check if a component is already installed
is_installed() {
    local component=$1
    local check_file=$2

    if [ "$FORCE_REBUILD" = "yes" ]; then
        return 1  # Force rebuild, so not "installed"
    fi

    if [ -f "${INSTALL_PREFIX}/${check_file}" ] || [ -d "${INSTALL_PREFIX}/${check_file}" ]; then
        return 0  # Already installed
    fi
    return 1  # Not installed
}

# Ask user if they want to rebuild an already-installed component
ask_rebuild() {
    local component=$1

    if [ "$FORCE_REBUILD" = "yes" ]; then
        return 0  # Rebuild
    fi

    print_warning "${component} appears to be already installed"
    read -p "Rebuild ${component}? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0  # Rebuild
    fi
    return 1  # Skip
}

# ==============================================================================
# Parse arguments
# ==============================================================================

show_help() {
    cat << EOF
Usage: ./install.sh [OPTIONS]

Options:
  --prefix=PATH                Installation prefix (default: ./install)
  --enable-cuda                Enable CUDA support (default: auto-detect)
  --disable-cuda               Disable CUDA support
  --enable-cuda-uvm            Build Kokkos with CUDA UVM as default memory space (default: no)
  --cuda-arch=ARCH             CUDA architecture (default: 70;75;80;86;89)
  --skip-python                Skip all Python dependencies (kokkos module and pykokkos)
  --skip-pykokkos              Skip pykokkos Python interface (keep kokkos module only)
  --skip-tests                 Skip test libraries (GTest, GBench)
  --enable-adios2              Build ADIOS2 (default: no; needed only for FUNTIDES_ENABLE_ADIOS2=ON)
  --enable-venv                Use Python virtual environment (default: no)
  --venv-name=NAME             Virtual environment name (default: tpl-venv)
  --python-prefix=PATH         Python installation prefix (default: auto-detect)
  --jobs=N                     Number of parallel jobs (default: 8)
  --pykokkos-build-threads=N   Parallel threads for PyKokkos build, memory intensive (default: 2)
  --force                      Force rebuild of all components
  -h, --help                   Show this help message

Environment:
  TPL_BUILD_DIR                Build directory (default: ./build). Set it to keep
                               separate builds (e.g. one per platform) from one checkout.

Examples:
  ./install.sh --prefix=\$HOME/local
  ./install.sh --prefix=/opt/tpl --enable-cuda --cuda-arch=80 --enable-venv
  ./install.sh --skip-tests

EOF
}

for arg in "$@"; do
    case $arg in
        --prefix=*)
            INSTALL_PREFIX="${arg#*=}"
            ;;
        --enable-cuda)
            ENABLE_CUDA="yes"
            ;;
        --disable-cuda)
            ENABLE_CUDA="no"
            ;;
        --enable-cuda-uvm)
            ENABLE_CUDA_UVM="yes"
            ;;
        --cuda-arch=*)
            CUDA_ARCH="${arg#*=}"
            ;;
        --enable-mpi)
            print_warning "--enable-mpi is ignored: the TPL no longer builds MPI, use the system MPI"
            ;;
        --skip-python)
            BUILD_PYTHON="no"
            BUILD_PYKOKKOS="no"
            ;;
        --skip-pykokkos)
            BUILD_PYKOKKOS="no"
            ;;
        --skip-tests)
            BUILD_TESTS="no"
            ;;
        --enable-adios2)
            BUILD_ADIOS2="yes"
            ;;
        --enable-venv)
            ENABLE_VENV="yes"
            ;;
        --venv-name=*)
            VENV_NAME="${arg#*=}"
            ;;
        --jobs=*)
            NUM_JOBS="${arg#*=}"
            ;;
        --python-prefix=*)
            PYTHON_PREFIX="${arg#*=}"
            ;;
        --pykokkos-build-threads=*)
            PYKOKKOS_BUILD_THREADS="${arg#*=}"
            ;;
        --force)
            FORCE_REBUILD="yes"
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $arg"
            show_help
            exit 1
            ;;
    esac
done

# ==============================================================================
# Auto-detect CUDA
# ==============================================================================

if [ "$ENABLE_CUDA" = "auto" ]; then
    if command -v nvcc &> /dev/null; then
        ENABLE_CUDA="yes"
        print_info "CUDA detected: $(nvcc --version | grep release | awk '{print $5}' | cut -d',' -f1)"
    else
        ENABLE_CUDA="no"
        print_warning "CUDA not detected, building without GPU support"
    fi
fi

# ==============================================================================
# Print configuration
# ==============================================================================

print_header "TPL Build Configuration"
echo "Installation prefix:  $INSTALL_PREFIX"
echo "Build directory:      $BUILD_DIR"
echo "External directory:   $EXTERNAL_DIR"
echo "CUDA support:         $ENABLE_CUDA"
if [ "$ENABLE_CUDA" = "yes" ]; then
    echo "CUDA architectures:   $CUDA_ARCH"
    echo "CUDA UVM:             $ENABLE_CUDA_UVM"
fi
echo "Build Python deps:    $BUILD_PYTHON"
echo "Build pykokkos iface: $BUILD_PYKOKKOS"
echo "Build test libs:      $BUILD_TESTS"
echo "Build ADIOS2:         $BUILD_ADIOS2"
echo "Parallel jobs:        $NUM_JOBS"
echo ""

# ==============================================================================
# Check prerequisites
# ==============================================================================

print_header "Checking Prerequisites"

check_command cmake || exit 1
check_command make || exit 1
check_command g++ || check_command clang++ || exit 1

if [ "$BUILD_PYTHON" = "yes" ]; then
    check_command python3 || { print_error "python3 required for Python dependencies"; exit 1; }
    PYTHON_EXEC=$(which python3)
    print_info "Using Python: $PYTHON_EXEC"

    # Setup virtual environment if requested
    if [ "$ENABLE_VENV" = "yes" ]; then
        VENV_DIR="${INSTALL_PREFIX}/${VENV_NAME}"

        if [ ! -d "${VENV_DIR}" ]; then
            print_info "Creating Python virtual environment at ${VENV_DIR}"
            ${PYTHON_EXEC} -m venv "${VENV_DIR}"
        else
            print_info "Using existing virtual environment at ${VENV_DIR}"
        fi

        # Activate venv
        source "${VENV_DIR}/bin/activate"
        PYTHON_EXEC="${VENV_DIR}/bin/python"
        print_info "Activated virtual environment"
        print_info "Using Python: $PYTHON_EXEC"

        # Install requirements if file exists
        if [ -f "${SCRIPT_DIR}/requirements.txt" ]; then
            print_info "Installing Python requirements..."
            ${PYTHON_EXEC} -m pip install --upgrade pip
            ${PYTHON_EXEC} -m pip install -r "${SCRIPT_DIR}/requirements.txt"
            print_info "Python requirements installed"
        fi
    else
        # Check for pip without venv
        if ! ${PYTHON_EXEC} -m pip --version &> /dev/null; then
            print_error "pip is not available for Python 3"
            print_error "Install with: sudo apt-get install python3-pip (Ubuntu/Debian)"
            print_error "           or: sudo yum install python3-pip (RHEL/CentOS)"
            print_error "Or use --enable-venv to create isolated environment"
            exit 1
        fi

        print_info "pip is available"
    fi
fi

if [ "$ENABLE_CUDA" = "yes" ]; then
    check_command nvcc || { print_error "nvcc not found, disable CUDA or add it to PATH"; exit 1; }
    CUDA_PATH=$(dirname $(dirname $(which nvcc)))
    print_info "Using CUDA: $CUDA_PATH"
fi

# ==============================================================================
# Check submodules
# ==============================================================================

print_header "Checking Submodules"

# Function to check if a submodule is properly initialized
check_submodule() {
    local name=$1
    local path=$2
    local check_file=$3

    if [ ! -f "${path}/${check_file}" ]; then
        print_error "Submodule '${name}' is not properly initialized"
        print_error "Missing file: ${path}/${check_file}"
        print_info "Initializing ${name} submodule..."
        git submodule update --init --recursive "${path}" || {
            print_error "Failed to initialize ${name} submodule"
            print_error "Try manually: git submodule update --init --recursive ${path}"
            exit 1
        }

        # Check again after initialization
        if [ ! -f "${path}/${check_file}" ]; then
            print_error "${name} submodule still incomplete after initialization"
            exit 1
        fi
    fi
    print_info "${name} submodule OK"
}

# Check required submodules
check_submodule "Kokkos" "${EXTERNAL_DIR}/kokkos" "CMakeLists.txt"

if [ "$BUILD_PYTHON" = "yes" ]; then
    check_submodule "pybind11" "${EXTERNAL_DIR}/pybind11" "CMakeLists.txt"
    check_submodule "pykokkos" "${EXTERNAL_DIR}/pykokkos" "setup.py"
fi

if [ "$BUILD_ADIOS2" = "yes" ]; then
    check_submodule "ADIOS2" "${EXTERNAL_DIR}/adios2" "CMakeLists.txt"
fi

if [ "$BUILD_TESTS" = "yes" ]; then
    check_submodule "GoogleTest" "${EXTERNAL_DIR}/googletest" "CMakeLists.txt"
    check_submodule "Google Benchmark" "${EXTERNAL_DIR}/benchmark" "CMakeLists.txt"
fi

print_info "All required submodules are properly initialized"

# ==============================================================================
# Create build directories
# ==============================================================================

mkdir -p "${BUILD_DIR}"
mkdir -p "${INSTALL_PREFIX}"

# Absolute paths
INSTALL_PREFIX=$(cd "${INSTALL_PREFIX}" && pwd)
BUILD_DIR=$(cd "${BUILD_DIR}" && pwd)

# ==============================================================================
# Build Kokkos
# ==============================================================================

print_header "Building Kokkos"

# Check if already installed and whether to rebuild
REBUILD_KOKKOS="no"
if is_installed "Kokkos" "lib/cmake/Kokkos/KokkosConfig.cmake"; then
    print_info "Kokkos already installed at ${INSTALL_PREFIX}"
    if ask_rebuild "Kokkos"; then
        REBUILD_KOKKOS="yes"
        rm -rf "${BUILD_DIR}/kokkos"
    else
        print_info "Skipping Kokkos build"
    fi
else
    REBUILD_KOKKOS="yes"
fi

if [ "$REBUILD_KOKKOS" = "yes" ]; then

KOKKOS_BUILD_DIR="${BUILD_DIR}/kokkos"
mkdir -p "${KOKKOS_BUILD_DIR}"
cd "${KOKKOS_BUILD_DIR}"

CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"
    -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX}"
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    -DKokkos_ENABLE_SERIAL=ON
    -DKokkos_ENABLE_OPENMP=ON
    -DKokkos_ENABLE_TESTS=OFF
    -DKokkos_ENABLE_EXAMPLES=OFF
    -DBUILD_SHARED_LIBS=ON
)

if [ "$ENABLE_CUDA" = "yes" ]; then
    # Map the numeric arch to the Kokkos keyword
    case "${CUDA_ARCH}" in
        70) KOKKOS_ARCH_NAME="VOLTA70" ;;
        75) KOKKOS_ARCH_NAME="TURING75" ;;
        80) KOKKOS_ARCH_NAME="AMPERE80" ;;
        86) KOKKOS_ARCH_NAME="AMPERE86" ;;
        89) KOKKOS_ARCH_NAME="ADA89" ;;
        90) KOKKOS_ARCH_NAME="HOPPER90" ;;
        100) KOKKOS_ARCH_NAME="BLACKWELL100" ;;
        *)  KOKKOS_ARCH_NAME="${CUDA_ARCH}" ;; # Fallback
    esac

    CMAKE_ARGS+=(
        -DKokkos_ENABLE_CUDA=ON
        -DKokkos_ENABLE_CUDA_CONSTEXPR=ON
        -DKokkos_ENABLE_CUDA_UVM=$([ "$ENABLE_CUDA_UVM" = "yes" ] && echo ON || echo OFF)
        -DKokkos_ARCH_${KOKKOS_ARCH_NAME}=ON
        -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH}"
    )
    print_info "Enabling CUDA support with architecture: ${KOKKOS_ARCH_NAME} (UVM: ${ENABLE_CUDA_UVM})"
fi

print_info "Configuring Kokkos..."
cmake "${EXTERNAL_DIR}/kokkos" "${CMAKE_ARGS[@]}"

print_info "Building Kokkos..."
cmake --build . -j${NUM_JOBS}

print_info "Installing Kokkos..."
cmake --install .

print_info "Kokkos installed successfully"
fi  # End of Kokkos rebuild check

# ==============================================================================
# Build pybind11
# ==============================================================================

if [ "$BUILD_PYTHON" = "yes" ]; then
    print_header "Building pybind11"

    # Check if already installed and whether to rebuild
    REBUILD_PYBIND11="no"
    if is_installed "pybind11" "lib/cmake/pybind11/pybind11Config.cmake"; then
        print_info "pybind11 already installed"
        if ask_rebuild "pybind11"; then
            REBUILD_PYBIND11="yes"
            rm -rf "${BUILD_DIR}/pybind11"
        else
            print_info "Skipping pybind11 build"
        fi
    else
        REBUILD_PYBIND11="yes"
    fi

    if [ "$REBUILD_PYBIND11" = "yes" ]; then

    PYBIND11_BUILD_DIR="${BUILD_DIR}/pybind11"
    mkdir -p "${PYBIND11_BUILD_DIR}"
    cd "${PYBIND11_BUILD_DIR}"

    print_info "Configuring pybind11..."
    cmake "${EXTERNAL_DIR}/pybind11" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DPYBIND11_TEST=OFF \
        -DPYBIND11_INSTALL=ON \
        -DPython_EXECUTABLE="${PYTHON_EXEC}"

    print_info "Installing pybind11..."
    cmake --install .

    print_info "pybind11 installed successfully"
    fi  # End of pybind11 rebuild check
fi

# ==============================================================================
# Build pykokkos-base (and optional pykokkos Python interface)
# ==============================================================================

if [ "$BUILD_PYTHON" = "yes" ]; then
    print_header "Building pykokkos-base"

    # 1. Install Build Dependencies
    print_info "Installing build dependencies..."
    if [ "$ENABLE_VENV" != "yes" ]; then
        if ! ${PYTHON_EXEC} -m pip install --break-system-packages scikit-build cmake ninja patchelf; then
            print_error "Failed to install Python build dependencies for pykokkos"
            print_error "Tip: rerun manually to inspect full pip diagnostics"
            print_error "Command: ${PYTHON_EXEC} -m pip install --break-system-packages scikit-build cmake ninja patchelf"
            exit 1
        fi
    else
        if ! ${PYTHON_EXEC} -m pip install scikit-build cmake ninja patchelf; then
            print_error "Failed to install Python build dependencies for pykokkos"
            print_error "Tip: rerun manually to inspect full pip diagnostics"
            print_error "Command: ${PYTHON_EXEC} -m pip install scikit-build cmake ninja patchelf"
            exit 1
        fi
    fi

    # Build from a copy of the sources: scikit-build writes _skbuild/, dist/ and the egg-info next to
    # setup.py, which would be shared by every build made from this checkout (e.g. other platforms).
    PYKOKKOS_BUILD_SRC="${BUILD_DIR}/pykokkos"
    mkdir -p "${PYKOKKOS_BUILD_SRC}"
    if command -v rsync &> /dev/null; then
        rsync -a --exclude=.git --exclude=_skbuild --exclude=dist --exclude='*.egg-info' \
            "${EXTERNAL_DIR}/pykokkos/" "${PYKOKKOS_BUILD_SRC}/"
    else
        cp -au "${EXTERNAL_DIR}/pykokkos/." "${PYKOKKOS_BUILD_SRC}/"
    fi
    cd "${PYKOKKOS_BUILD_SRC}"

    # 2. Configure Environment
    export CMAKE_PREFIX_PATH="${INSTALL_PREFIX}:${CMAKE_PREFIX_PATH}"

    # 3. Prepare CMake Arguments
    # Note: scikit-build handles CMAKE_INSTALL_PREFIX automatically, so we don't pass it.

    PK_ARGS="-DCMAKE_BUILD_TYPE=Release"

    # --- FORCE EXTERNAL DEPENDENCIES (Interop & Py3.12 Fix) ---
    # We explicitly turn off internal builds and point to our installed libs.
    PK_ARGS="${PK_ARGS} -DENABLE_INTERNAL_PYBIND11=OFF"
    PK_ARGS="${PK_ARGS} -Dpybind11_ROOT=${INSTALL_PREFIX}"
    PK_ARGS="${PK_ARGS} -DENABLE_INTERNAL_KOKKOS=OFF"
    PK_ARGS="${PK_ARGS} -DKokkos_ROOT=${INSTALL_PREFIX}"

    # Feature flags (Must match how you built Kokkos)
    PK_ARGS="${PK_ARGS} -DENABLE_LAYOUTS=ON -DENABLE_VIEW_RANKS=4"

    # 4. Handle CUDA Architecture
    if [ "$ENABLE_CUDA" = "yes" ]; then
        # Parse the CUDA_ARCH list.
        IFS=';' read -ra ARCH_ARRAY <<< "$CUDA_ARCH"
        FIRST_ARCH="${ARCH_ARRAY[0]}"

        # Map architecture number to the specific Kokkos flag
        case "$FIRST_ARCH" in
            70) K_ARCH_FLAG="-DKokkos_ARCH_VOLTA70=ON" ;;
            75) K_ARCH_FLAG="-DKokkos_ARCH_TURING75=ON" ;;
            80) K_ARCH_FLAG="-DKokkos_ARCH_AMPERE80=ON" ;;
            86) K_ARCH_FLAG="-DKokkos_ARCH_AMPERE86=ON" ;;
            89) K_ARCH_FLAG="-DKokkos_ARCH_ADA89=ON" ;;
            90) K_ARCH_FLAG="-DKokkos_ARCH_HOPPER90=ON" ;;
            100) K_ARCH_FLAG="-DKokkos_ARCH_BLACKWELL100=ON" ;;
            *)  K_ARCH_FLAG="-DKokkos_ARCH_AMPERE80=ON" ;;
        esac

        PK_ARGS="${PK_ARGS} -DENABLE_CUDA=ON ${K_ARCH_FLAG} -DCMAKE_CUDA_ARCHITECTURES=${FIRST_ARCH}"
        # CudaUVMSpace views are bound only if Kokkos itself was built with
        # Kokkos_ENABLE_CUDA_UVM=ON: pykokkos-base reads KOKKOS_ENABLE_CUDA_UVM
        # from the installed KokkosCore_config.h (no pykokkos-base flag for it).
        print_info "Configuring PyKokkos-base for CUDA (Arch: ${FIRST_ARCH}, UVM: ${ENABLE_CUDA_UVM})"
    else
        PK_ARGS="${PK_ARGS} -DENABLE_CUDA=OFF -DENABLE_OPENMP=ON"
        print_info "Configuring PyKokkos-base for CPU (OpenMP)"
    fi

    # 5. Install pykokkos-base (C++ Bindings)
    print_info "Installing pykokkos-base..."

    # --- LIMIT RAM USAGE ---
    # Set parallelism to prevent OOM errors during template instantiation
    export CMAKE_BUILD_PARALLEL_LEVEL=${PYKOKKOS_BUILD_THREADS}
    print_info "Limiting build parallelism to ${CMAKE_BUILD_PARALLEL_LEVEL} to save RAM"

    if [ ! -f "install_base.py" ]; then
        print_error "install_base.py not found in $(pwd). Repo might be incomplete."
        exit 1
    fi

    # Run the installation script
    # The '--' separates the python setup arguments from the CMake arguments
    PK_PYTHON_ARGS="--force"
    if [ -n "${PYTHON_PREFIX}" ]; then
        PK_PYTHON_ARGS="${PK_PYTHON_ARGS} --prefix ${PYTHON_PREFIX}"
    fi
    if ! ${PYTHON_EXEC} install_base.py install ${PK_PYTHON_ARGS} -- ${PK_ARGS}; then
        print_error "Failed to install pykokkos-base."
        print_error "Command: ${PYTHON_EXEC} install_base.py install ${PK_PYTHON_ARGS} -- ${PK_ARGS}"
        exit 1
    fi

    # 6. Verify kokkos module from pykokkos-base

    if [ -n "${PYTHON_PREFIX}" ]; then
       _PY_VER=$(${PYTHON_EXEC} -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
       _SITE_PKGS="${PYTHON_PREFIX}/lib/python${_PY_VER}/site-packages"
       export PYTHONPATH="${_SITE_PKGS}:${PYTHONPATH}"
       # pykokkos-base installs as an egg; .pth files in PYTHONPATH dirs are not
       # processed by Python, so we must add the egg directory explicitly.
       _PK_EGG=$(find "${_SITE_PKGS}" -maxdepth 1 -name "pykokkos_base-*.egg" -type d 2>/dev/null | head -1)
       if [ -n "${_PK_EGG}" ]; then
           export PYTHONPATH="${_PK_EGG}:${PYTHONPATH}"
           print_info "Added egg ${_PK_EGG} to PYTHONPATH for kokkos module discovery"
       else
           print_info "Added ${_SITE_PKGS} to PYTHONPATH for kokkos module discovery"
       fi
    fi

    print_info "Verifying kokkos module..."
    if ! ${PYTHON_EXEC} -c "import kokkos"; then
        print_error "pykokkos-base installation completed, but 'import kokkos' failed."
        exit 1
    fi
    print_info "kokkos module available"

    # 7. Optionally install pykokkos (Python Interface)
    if [ "$BUILD_PYKOKKOS" = "yes" ]; then
        print_info "Installing pykokkos python interface..."

        INSTALL_CMD="${PYTHON_EXEC} -m pip install"
        if [ "$ENABLE_VENV" = "no" ]; then
            INSTALL_CMD="${INSTALL_CMD} --break-system-packages"
        fi
        # Use --no-build-isolation to ensure we use the environment we just configured
        INSTALL_CMD="${INSTALL_CMD} --no-build-isolation -v ."

        if ! ${INSTALL_CMD}; then
            print_error "Failed to install pykokkos python layer."
            print_error "Command: ${INSTALL_CMD}"
            exit 1
        fi

        print_info "Verifying pykokkos installation..."
        export LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib64:${LD_LIBRARY_PATH}"
        if ! ${PYTHON_EXEC} -c "import pykokkos"; then
            print_error "pykokkos installation completed, but 'import pykokkos' failed."
            exit 1
        fi
        print_info "pykokkos installed and verified successfully!"
    else
        print_info "Skipping pykokkos python interface (--skip-pykokkos)"
    fi

    # 8. Sanity-check: CudaUVMSpace views must be bound if Kokkos was built with UVM.
    # kokkos.CudaUVMSpace is an enum value that always exists, so query availability.
    if [ "$ENABLE_CUDA" = "yes" ] && [ "$ENABLE_CUDA_UVM" = "yes" ]; then
        if ! ${PYTHON_EXEC} -c "import kokkos, sys; sys.exit(0 if kokkos.get_memory_space_available('CudaUVMSpace') else 1)" 2>/dev/null; then
            print_error "CudaUVMSpace views are not available after installation."
            print_error "Kokkos was not built with -DKokkos_ENABLE_CUDA_UVM=ON."
            exit 1
        fi
        print_info "Verified: CudaUVMSpace views are available"
    fi
fi

# ==============================================================================
# Build ADIOS2
# ==============================================================================

if [ "$BUILD_ADIOS2" = "yes" ]; then
print_header "Building ADIOS2"

# Check if already installed and whether to rebuild
REBUILD_ADIOS2="no"
if is_installed "ADIOS2" "lib/cmake/adios2/adios2-config.cmake"; then
    print_info "ADIOS2 already installed"
    if ask_rebuild "ADIOS2"; then
        REBUILD_ADIOS2="yes"
        rm -rf "${BUILD_DIR}/adios2"
    else
        print_info "Skipping ADIOS2 build"
    fi
else
    REBUILD_ADIOS2="yes"
fi

if [ "$REBUILD_ADIOS2" = "yes" ]; then

ADIOS2_BUILD_DIR="${BUILD_DIR}/adios2"
mkdir -p "${ADIOS2_BUILD_DIR}"
cd "${ADIOS2_BUILD_DIR}"

CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"
    -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX}"
    -DADIOS2_USE_Kokkos=OFF
    -DADIOS2_USE_Fortran=OFF
    -DADIOS2_USE_ZeroMQ=OFF
    -DADIOS2_USE_HDF5_VOL=OFF
    -DBUILD_TESTING=OFF
    -DADIOS2_BUILD_EXAMPLES=OFF
    # FUnTiDES only uses the serial ADIOS2 API (one file per rank), so ADIOS2
    # never links MPI and cannot pick an MPI different from the application's.
    -DADIOS2_USE_MPI=OFF
)

# Note: ADIOS2_USE_CUDA is incompatible with ADIOS2_USE_Kokkos
# When using Kokkos, CUDA support comes through Kokkos, not directly
if [ "$ENABLE_CUDA" = "yes" ]; then
    print_info "CUDA support provided through Kokkos (ADIOS2_USE_CUDA incompatible with ADIOS2_USE_Kokkos)"
fi

if [ "$BUILD_PYTHON" = "yes" ]; then
    CMAKE_ARGS+=(-DADIOS2_USE_Python=ON)
    CMAKE_ARGS+=(-DPython_EXECUTABLE="${PYTHON_EXEC}")
    print_info "Enabling Python support"
else
    CMAKE_ARGS+=(-DADIOS2_USE_Python=OFF)
    print_info "Disabling Python support"
fi

print_info "Configuring ADIOS2..."
cmake "${EXTERNAL_DIR}/adios2" "${CMAKE_ARGS[@]}"

print_info "Building ADIOS2..."
cmake --build . -j${NUM_JOBS}

print_info "Installing ADIOS2..."
cmake --install .

print_info "ADIOS2 installed successfully"
fi  # End of ADIOS2 rebuild check
else
    print_info "Skipping ADIOS2 build (use --enable-adios2 to build it)"
fi  # End of BUILD_ADIOS2 check

# ==============================================================================
# Build GoogleTest
# ==============================================================================

if [ "$BUILD_TESTS" = "yes" ]; then
    print_header "Building GoogleTest"

    # Check if already installed and whether to rebuild
    REBUILD_GTEST="no"
    if is_installed "GoogleTest" "lib/cmake/GTest/GTestConfig.cmake"; then
        print_info "GoogleTest already installed"
        if ask_rebuild "GoogleTest"; then
            REBUILD_GTEST="yes"
            rm -rf "${BUILD_DIR}/googletest"
        else
            print_info "Skipping GoogleTest build"
        fi
    else
        REBUILD_GTEST="yes"
    fi

    if [ "$REBUILD_GTEST" = "yes" ]; then

    GTEST_BUILD_DIR="${BUILD_DIR}/googletest"
    mkdir -p "${GTEST_BUILD_DIR}"
    cd "${GTEST_BUILD_DIR}"

    print_info "Configuring GoogleTest..."
    cmake "${EXTERNAL_DIR}/googletest" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DBUILD_GMOCK=ON \
        -DINSTALL_GTEST=ON

    print_info "Building GoogleTest..."
    cmake --build . -j${NUM_JOBS}

    print_info "Installing GoogleTest..."
    cmake --install .

    print_info "GoogleTest installed successfully"
    fi  # End of GoogleTest rebuild check
fi

# ==============================================================================
# Build Google Benchmark
# ==============================================================================

if [ "$BUILD_TESTS" = "yes" ]; then
    print_header "Building Google Benchmark"

    # Check if already installed and whether to rebuild
    REBUILD_GBENCH="no"
    if is_installed "Google Benchmark" "lib/cmake/benchmark/benchmarkConfig.cmake"; then
        print_info "Google Benchmark already installed"
        if ask_rebuild "Google Benchmark"; then
            REBUILD_GBENCH="yes"
            rm -rf "${BUILD_DIR}/benchmark"
        else
            print_info "Skipping Google Benchmark build"
        fi
    else
        REBUILD_GBENCH="yes"
    fi

    if [ "$REBUILD_GBENCH" = "yes" ]; then

    GBENCH_BUILD_DIR="${BUILD_DIR}/benchmark"
    mkdir -p "${GBENCH_BUILD_DIR}"
    cd "${GBENCH_BUILD_DIR}"

    print_info "Configuring Google Benchmark..."
    cmake "${EXTERNAL_DIR}/benchmark" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DBENCHMARK_ENABLE_TESTING=OFF \
        -DBENCHMARK_ENABLE_GTEST_TESTS=OFF

    print_info "Building Google Benchmark..."
    cmake --build . -j${NUM_JOBS}

    print_info "Installing Google Benchmark..."
    cmake --install .

    print_info "Google Benchmark installed successfully"
    fi  # End of Google Benchmark rebuild check
fi

# ==============================================================================
# Create environment setup script
# ==============================================================================

print_header "Creating Environment Setup Script"

ENV_SCRIPT="${INSTALL_PREFIX}/setup_env.sh"

# Start with the header
cat > "${ENV_SCRIPT}" << 'EOF'
#!/bin/bash
# Source this script to set up the environment for using TPL libraries
EOF

echo "# Usage: source ${INSTALL_PREFIX}/setup_env.sh" >> "${ENV_SCRIPT}"
echo "" >> "${ENV_SCRIPT}"

# Add PATH and library paths
cat >> "${ENV_SCRIPT}" << EOF
export PATH="${INSTALL_PREFIX}/bin:\${PATH}"
export LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib:\${LD_LIBRARY_PATH}"
export CMAKE_PREFIX_PATH="${INSTALL_PREFIX}:\${CMAKE_PREFIX_PATH}"
EOF

# Add venv activation if used
if [ "$ENABLE_VENV" = "yes" ]; then
    cat >> "${ENV_SCRIPT}" << EOF

# Activate Python virtual environment
if [ -f "${INSTALL_PREFIX}/${VENV_NAME}/bin/activate" ]; then
    source "${INSTALL_PREFIX}/${VENV_NAME}/bin/activate"
    echo "Python virtual environment activated"
fi
EOF
elif [ "$BUILD_PYTHON" = "yes" ]; then
    # Add PYTHONPATH for non-venv Python installs
    cat >> "${ENV_SCRIPT}" << 'EOF'

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
EOF
    echo "export PYTHONPATH=\"${INSTALL_PREFIX}/lib/python\${PYTHON_VERSION}/site-packages:\${PYTHONPATH}\"" >> "${ENV_SCRIPT}"
fi

# Add footer
cat >> "${ENV_SCRIPT}" << EOF

echo "TPL environment configured!"
echo "Installation prefix: ${INSTALL_PREFIX}"
EOF

chmod +x "${ENV_SCRIPT}"

print_info "Environment setup script created: ${ENV_SCRIPT}"

# ==============================================================================
# Summary
# ==============================================================================

print_header "Installation Complete!"

cat << EOF

${GREEN}All dependencies have been successfully built and installed!${NC}

Installation directory: ${INSTALL_PREFIX}

To use these libraries in your project:

1. Add to your CMakeLists.txt:
   ${YELLOW}set(CMAKE_PREFIX_PATH "${INSTALL_PREFIX}")${NC}

2. Or set environment variable:
   ${YELLOW}export CMAKE_PREFIX_PATH="${INSTALL_PREFIX}:\$CMAKE_PREFIX_PATH"${NC}

3. Or source the setup script:
   ${YELLOW}source ${INSTALL_PREFIX}/setup_env.sh${NC}

Libraries installed:
  - Kokkos $([ "$ENABLE_CUDA" = "yes" ] && echo "(with CUDA)" || echo "(CPU only)")
EOF

if [ "$BUILD_PYTHON" = "yes" ]; then
    if [ -f "${INSTALL_PREFIX}/lib/cmake/pybind11/pybind11Config.cmake" ]; then
        echo "  - pybind11"
    fi

    if [ "$BUILD_PYKOKKOS" = "yes" ]; then
        # Check if pykokkos was actually installed (either to venv or prefix)
        PYKOKKOS_INSTALLED="no"
        if [ "$ENABLE_VENV" = "yes" ] && [ -f "${INSTALL_PREFIX}/${VENV_NAME}/bin/python" ]; then
            if "${INSTALL_PREFIX}/${VENV_NAME}/bin/python" -c "import pykokkos" 2>/dev/null; then
                PYKOKKOS_INSTALLED="yes"
            fi
        elif ${PYTHON_EXEC:-python3} -c "import pykokkos" 2>/dev/null; then
            PYKOKKOS_INSTALLED="yes"
        fi

        if [ "$PYKOKKOS_INSTALLED" = "yes" ]; then
            echo "  - pykokkos $([ "$ENABLE_CUDA" = "yes" ] && { [ "$ENABLE_CUDA_UVM" = "yes" ] && echo "(CudaSpace and CudaUVMSpace views)" || echo "(CudaSpace views)"; } || echo "")"
        fi
    else
        echo "  - pykokkos (skipped; kokkos python module only)"
    fi
elif [ "$BUILD_PYTHON" = "no" ]; then
    echo "  - Python dependencies (skipped)"
fi

if [ "$BUILD_ADIOS2" = "yes" ]; then
    echo "  - ADIOS2"
fi

if [ "$BUILD_TESTS" = "yes" ]; then
    if [ -f "${INSTALL_PREFIX}/lib/cmake/GTest/GTestConfig.cmake" ]; then
        echo "  - GoogleTest"
    fi
    if [ -f "${INSTALL_PREFIX}/lib/cmake/benchmark/benchmarkConfig.cmake" ]; then
        echo "  - Google Benchmark"
    fi
fi

echo ""

if [ "$BUILD_PYTHON" = "no" ]; then
    echo -e "${YELLOW}Note:${NC} Python dependencies were skipped."
    echo "To add them later, run: ./install.sh --prefix=${INSTALL_PREFIX} --enable-cuda --enable-venv"
    echo ""
fi

echo -e "${GREEN}Happy coding!${NC}"
