#!/bin/bash
set -e  # Exit on error

# ==============================================================================
# TPL Installation Script
# Builds and installs all third-party dependencies
# ==============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
INSTALL_PREFIX="$(pwd)/install"
ENABLE_CUDA="auto"
CUDA_ARCH="70,75,80,86"
BUILD_MPI="yes"
BUILD_PYTHON="yes"
BUILD_TESTS="yes"
NUM_JOBS=8
FORCE_REBUILD="no"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTERNAL_DIR="${SCRIPT_DIR}/external"
BUILD_DIR="${SCRIPT_DIR}/build"

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
  --prefix=PATH          Installation prefix (default: ./install)
  --enable-cuda          Enable CUDA support (default: auto-detect)
  --disable-cuda         Disable CUDA support
  --cuda-arch=ARCH       CUDA architecture (default: 70,75,80,86)
  --enable-mpi           Build Open MPI (default: yes)
  --disable-mpi          Use system MPI instead
  --skip-python          Skip Python dependencies (pykokkos)
  --skip-tests           Skip test libraries (GTest, GBench)
  --jobs=N               Number of parallel jobs (default: 8)
  --force                Force rebuild of all components
  -h, --help             Show this help message

Examples:
  ./install.sh --prefix=\$HOME/local
  ./install.sh --prefix=/opt/tpl --enable-cuda --cuda-arch=80
  ./install.sh --disable-mpi --skip-tests

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
        --cuda-arch=*)
            CUDA_ARCH="${arg#*=}"
            ;;
        --enable-mpi)
            BUILD_MPI="yes"
            ;;
        --disable-mpi)
            BUILD_MPI="no"
            ;;
        --skip-python)
            BUILD_PYTHON="no"
            ;;
        --skip-tests)
            BUILD_TESTS="no"
            ;;
        --jobs=*)
            NUM_JOBS="${arg#*=}"
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
fi
echo "Build Open MPI:       $BUILD_MPI"
echo "Build Python deps:    $BUILD_PYTHON"
echo "Build test libs:      $BUILD_TESTS"
echo "Parallel jobs:        $NUM_JOBS"
echo ""

# ==============================================================================
# Check prerequisites
# ==============================================================================

print_header "Checking Prerequisites"

check_command cmake || exit 1
check_command make || exit 1
check_command g++ || check_command clang++ || exit 1

if [ "$BUILD_MPI" = "yes" ]; then
    check_command autoconf || { print_error "autoconf required for Open MPI"; exit 1; }
    check_command automake || { print_error "automake required for Open MPI"; exit 1; }
    check_command libtool || { print_error "libtool required for Open MPI"; exit 1; }
    check_command perl || { print_error "perl required for Open MPI autogen.pl"; exit 1; }

    # Check for optional but commonly needed tools
    if ! check_command flex; then
        print_warning "flex not found - may be needed for Open MPI build"
    fi
    if ! check_command bison; then
        print_warning "bison not found - may be needed for Open MPI build"
    fi
fi

if [ "$BUILD_PYTHON" = "yes" ]; then
    check_command python3 || { print_error "python3 required for pykokkos"; exit 1; }
    PYTHON_EXEC=$(which python3)
    print_info "Using Python: $PYTHON_EXEC"

    # Check for pip
    if ! ${PYTHON_EXEC} -m pip --version &> /dev/null; then
        print_error "pip is not available for Python 3"
        print_error "Install with: sudo apt-get install python3-pip (Ubuntu/Debian)"
        print_error "           or: sudo yum install python3-pip (RHEL/CentOS)"
        exit 1
    fi

    print_info "pip is available"
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

if [ "$BUILD_MPI" = "yes" ]; then
    check_submodule "Open MPI" "${EXTERNAL_DIR}/openmpi" "autogen.pl"
fi

if [ "$BUILD_PYTHON" = "yes" ]; then
    check_submodule "pybind11" "${EXTERNAL_DIR}/pybind11" "CMakeLists.txt"
    check_submodule "pykokkos" "${EXTERNAL_DIR}/pykokkos" "setup.py"
fi

check_submodule "ADIOS2" "${EXTERNAL_DIR}/adios2" "CMakeLists.txt"

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
# Build Open MPI (if requested)
# ==============================================================================

if [ "$BUILD_MPI" = "yes" ]; then
    print_header "Building Open MPI"

    # Check if already installed
    if is_installed "Open MPI" "bin/mpirun"; then
        print_info "Open MPI already installed at ${INSTALL_PREFIX}/bin/mpirun"
        if ! ask_rebuild "Open MPI"; then
            print_info "Skipping Open MPI build"
            # Add to PATH for subsequent builds
            export PATH="${INSTALL_PREFIX}/bin:$PATH"
            export LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib:$LD_LIBRARY_PATH"
        else
            # Clean build directory before rebuild
            rm -rf "${BUILD_DIR}/openmpi"
        fi
    fi

    if ! is_installed "Open MPI" "bin/mpirun" || ask_rebuild "Open MPI" 2>/dev/null; then

    # Check if we need to run autogen (git checkout or no configure)
    # Submodules have .git as a file, not directory
    NEED_AUTOGEN=false

    if [ ! -f "${EXTERNAL_DIR}/openmpi/configure" ]; then
        NEED_AUTOGEN=true
    elif [ -e "${EXTERNAL_DIR}/openmpi/.git" ]; then
        # .git exists (either file for submodule or dir for regular clone)
        NEED_AUTOGEN=true
    fi

    if [ "$NEED_AUTOGEN" = "true" ]; then
        print_info "Generating configure script from git sources..."
        cd "${EXTERNAL_DIR}/openmpi"

        # Check which branch/version we're on
        if command -v git &> /dev/null && [ -e ".git" ]; then
            OMPI_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
            OMPI_VERSION=$(cat VERSION 2>/dev/null | head -1 || echo "unknown")
            print_info "Open MPI branch: ${OMPI_BRANCH}"
            print_info "Open MPI version: ${OMPI_VERSION}"

            # Warn if not on v4.1.x
            if [[ ! "$OMPI_BRANCH" =~ ^v4\.1 ]] && [[ ! "$OMPI_VERSION" =~ ^4\.1 ]]; then
                print_warning "Not on v4.1.x branch - you may encounter dependency issues"
                print_warning "Recommended: git checkout v4.1.x"
            fi
        fi

        # Clean any previous autogen artifacts
        if [ -f "Makefile" ]; then
            make distclean 2>/dev/null || true
        fi

        # Remove old configure to force regeneration
        rm -f configure

        # Run autogen
        if [ -f "autogen.pl" ]; then
            print_info "Running autogen.pl (this takes a few minutes)..."
            ./autogen.pl
        else
            print_error "Cannot find autogen.pl. Open MPI source may be incomplete."
            print_error "Try: git submodule update --init --recursive"
            exit 1
        fi
    fi

    MPI_BUILD_DIR="${BUILD_DIR}/openmpi"
    mkdir -p "${MPI_BUILD_DIR}"
    cd "${MPI_BUILD_DIR}"

    CONFIGURE_ARGS="--prefix=${INSTALL_PREFIX}"

    # Check Open MPI version to determine if we need internal PMIx
    OMPI_VERSION=""
    if [ -f "${EXTERNAL_DIR}/openmpi/VERSION" ]; then
        OMPI_VERSION=$(cat "${EXTERNAL_DIR}/openmpi/VERSION" | head -1)
        print_info "Detected Open MPI version: ${OMPI_VERSION}"
    fi

    # For v5.0+ we need internal PMIx to avoid system version conflicts
    if [[ "$OMPI_VERSION" =~ ^5\. ]] || [[ "$OMPI_VERSION" =~ ^6\. ]]; then
        print_warning "Open MPI v5.0+ detected - using internal PMIx/PRRTE"
        print_warning "For better stability, consider: cd external/openmpi && git checkout v4.1.x"
        CONFIGURE_ARGS="${CONFIGURE_ARGS} --with-pmix=internal --with-prrte=internal"
    fi

    if [ "$ENABLE_CUDA" = "yes" ]; then
        CONFIGURE_ARGS="${CONFIGURE_ARGS} --with-cuda=${CUDA_PATH}"
        print_info "Enabling CUDA-aware MPI (--with-cuda=${CUDA_PATH})"
    fi

    print_info "Configuring Open MPI..."
    ${EXTERNAL_DIR}/openmpi/configure ${CONFIGURE_ARGS}

    print_info "Building Open MPI (this may take a while)..."
    make -j${NUM_JOBS}

    print_info "Installing Open MPI..."
    make install

    # Add to PATH for subsequent builds
    export PATH="${INSTALL_PREFIX}/bin:$PATH"
    export LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib:$LD_LIBRARY_PATH"

    print_info "Open MPI installed successfully"
    fi  # End of rebuild check
else
    print_info "Skipping Open MPI build (using system MPI or disabled)"
fi

# ==============================================================================
# Build Kokkos
# ==============================================================================

print_header "Building Kokkos"

# Check if already installed
if is_installed "Kokkos" "lib/cmake/Kokkos/KokkosConfig.cmake"; then
    print_info "Kokkos already installed at ${INSTALL_PREFIX}"
    if ! ask_rebuild "Kokkos"; then
        print_info "Skipping Kokkos build"
    else
        rm -rf "${BUILD_DIR}/kokkos"
    fi
fi

if ! is_installed "Kokkos" "lib/cmake/Kokkos/KokkosConfig.cmake" || ask_rebuild "Kokkos" 2>/dev/null; then

KOKKOS_BUILD_DIR="${BUILD_DIR}/kokkos"
mkdir -p "${KOKKOS_BUILD_DIR}"
cd "${KOKKOS_BUILD_DIR}"

CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"
    -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX}"
    -DKokkos_ENABLE_SERIAL=ON
    -DKokkos_ENABLE_OPENMP=ON
    -DKokkos_ENABLE_TESTS=OFF
    -DKokkos_ENABLE_EXAMPLES=OFF
)

if [ "$ENABLE_CUDA" = "yes" ]; then
    CMAKE_ARGS+=(
        -DKokkos_ENABLE_CUDA=ON
        -DKokkos_ENABLE_CUDA_LAMBDA=ON
        -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH}"
    )
    print_info "Enabling CUDA support with architectures: ${CUDA_ARCH}"
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

    # Check if already installed
    if is_installed "pybind11" "lib/cmake/pybind11/pybind11Config.cmake"; then
        print_info "pybind11 already installed"
        if ! ask_rebuild "pybind11"; then
            print_info "Skipping pybind11 build"
        else
            rm -rf "${BUILD_DIR}/pybind11"
        fi
    fi

    if ! is_installed "pybind11" "lib/cmake/pybind11/pybind11Config.cmake" || ask_rebuild "pybind11" 2>/dev/null; then

    PYBIND11_BUILD_DIR="${BUILD_DIR}/pybind11"
    mkdir -p "${PYBIND11_BUILD_DIR}"
    cd "${PYBIND11_BUILD_DIR}"

    print_info "Configuring pybind11..."
    cmake "${EXTERNAL_DIR}/pybind11" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DPYBIND11_TEST=OFF \
        -DPYBIND11_INSTALL=ON

    print_info "Installing pybind11..."
    cmake --install .

    print_info "pybind11 installed successfully"
    fi  # End of pybind11 rebuild check
fi

# ==============================================================================
# Build pykokkos
# ==============================================================================

if [ "$BUILD_PYTHON" = "yes" ]; then
    print_header "Building pykokkos"

    # Install build dependencies first (system-wide or user, not to prefix)
    print_info "Installing pykokkos build dependencies..."

    # Try different methods to install dependencies
    if ${PYTHON_EXEC} -m pip install --break-system-packages scikit-build cmake ninja 2>/dev/null; then
        print_info "Build dependencies installed with --break-system-packages"
    elif ${PYTHON_EXEC} -m pip install --user scikit-build cmake ninja 2>/dev/null; then
        print_info "Build dependencies installed to user directory"
    else
        print_warning "Could not install build dependencies automatically"
        print_warning "You may need to install manually: pip install scikit-build cmake ninja"
    fi

    # Verify skbuild is available
    if ! ${PYTHON_EXEC} -c "import skbuild" 2>/dev/null; then
        print_error "scikit-build (skbuild) is not available for Python"
        print_error "Please install manually:"
        print_error "  python3 -m pip install --user scikit-build cmake ninja"
        print_error "Or skip Python dependencies: ./install.sh --skip-python"
        exit 1
    fi

    cd "${EXTERNAL_DIR}/pykokkos"

    # Set environment for pykokkos build
    export CMAKE_PREFIX_PATH="${INSTALL_PREFIX}:${CMAKE_PREFIX_PATH}"
    PYTHON_SITE_PACKAGES="${INSTALL_PREFIX}/lib/python$(${PYTHON_EXEC} -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/site-packages"
    export PYTHONPATH="${PYTHON_SITE_PACKAGES}:${PYTHONPATH}"

    # Set CUDA architecture for pykokkos-base's internal Kokkos build
    if [ "$ENABLE_CUDA" = "yes" ]; then
        # Convert comma-separated to array
        IFS=',' read -ra ARCH_ARRAY <<< "$CUDA_ARCH"
        # Use first architecture for pykokkos
        FIRST_ARCH="${ARCH_ARRAY[0]}"

        print_info "Setting CUDA architecture ${FIRST_ARCH} for pykokkos build"

        # Map architecture number to Kokkos flag name
        case "$FIRST_ARCH" in
            70) KOKKOS_ARCH="VOLTA70" ;;
            72) KOKKOS_ARCH="VOLTA72" ;;
            75) KOKKOS_ARCH="TURING75" ;;
            80) KOKKOS_ARCH="AMPERE80" ;;
            86) KOKKOS_ARCH="AMPERE86" ;;
            89) KOKKOS_ARCH="ADA89" ;;
            90) KOKKOS_ARCH="HOPPER90" ;;
            *) KOKKOS_ARCH="AMPERE80"; print_warning "Unknown CUDA arch ${FIRST_ARCH}, defaulting to AMPERE80" ;;
        esac

        # Set CMAKE arguments for pykokkos-base build
        export CMAKE_ARGS="-DKokkos_ENABLE_CUDA=ON -DKokkos_ARCH_${KOKKOS_ARCH}=ON -DCMAKE_CUDA_ARCHITECTURES=${FIRST_ARCH}"
        print_info "CMAKE_ARGS=${CMAKE_ARGS}"
    fi

    print_info "Installing pykokkos to ${INSTALL_PREFIX}..."
    print_warning "This may take 10-15 minutes as pykokkos builds its own Kokkos internally..."

    # Try installation with different methods
    if ${PYTHON_EXEC} -m pip install --prefix="${INSTALL_PREFIX}" --break-system-packages --no-build-isolation -v . 2>&1 | tee /tmp/pykokkos_install.log; then
        print_info "pykokkos installed with --break-system-packages"
    elif ${PYTHON_EXEC} -m pip install --prefix="${INSTALL_PREFIX}" --no-build-isolation -v . 2>&1 | tee /tmp/pykokkos_install.log; then
        print_info "pykokkos installed successfully"
    else
        print_error "Failed to install pykokkos"
        print_error "See /tmp/pykokkos_install.log for details"
        print_warning "pykokkos is optional - you can continue without it"
        print_warning "To skip Python dependencies next time: ./install.sh --skip-python"

        # Ask user if they want to continue
        read -p "Continue installation without pykokkos? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        print_info "Continuing without pykokkos..."
        return 0
    fi

    print_info "pykokkos installed successfully"
fi

# ==============================================================================
# Build ADIOS2
# ==============================================================================

print_header "Building ADIOS2"

# Check if already installed
if is_installed "ADIOS2" "lib/cmake/adios2/adios2-config.cmake"; then
    print_info "ADIOS2 already installed"
    if ! ask_rebuild "ADIOS2"; then
        print_info "Skipping ADIOS2 build"
    else
        rm -rf "${BUILD_DIR}/adios2"
    fi
fi

if ! is_installed "ADIOS2" "lib/cmake/adios2/adios2-config.cmake" || ask_rebuild "ADIOS2" 2>/dev/null; then

ADIOS2_BUILD_DIR="${BUILD_DIR}/adios2"
mkdir -p "${ADIOS2_BUILD_DIR}"
cd "${ADIOS2_BUILD_DIR}"

CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"
    -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX}"
    -DADIOS2_USE_Kokkos=ON
    -DBUILD_TESTING=OFF
    -DADIOS2_BUILD_EXAMPLES=OFF
)

if [ "$BUILD_MPI" = "yes" ] || command -v mpirun &> /dev/null; then
    CMAKE_ARGS+=(-DADIOS2_USE_MPI=ON)
    print_info "Enabling MPI support"
fi

# if [ "$ENABLE_CUDA" = "yes" ]; then
#     CMAKE_ARGS+=(-DADIOS2_USE_CUDA=ON)
#     print_info "Enabling CUDA support"
# fi

if [ "$BUILD_PYTHON" = "yes" ]; then
    CMAKE_ARGS+=(-DADIOS2_USE_Python=ON)
    print_info "Enabling Python support"
fi

print_info "Configuring ADIOS2..."
cmake "${EXTERNAL_DIR}/adios2" "${CMAKE_ARGS[@]}"

print_info "Building ADIOS2..."
cmake --build . -j${NUM_JOBS}

print_info "Installing ADIOS2..."
cmake --install .

print_info "ADIOS2 installed successfully"
fi  # End of ADIOS2 rebuild check

# ==============================================================================
# Build GoogleTest
# ==============================================================================

if [ "$BUILD_TESTS" = "yes" ]; then
    print_header "Building GoogleTest"

    # Check if already installed
    if is_installed "GoogleTest" "lib/cmake/GTest/GTestConfig.cmake"; then
        print_info "GoogleTest already installed"
        if ! ask_rebuild "GoogleTest"; then
            print_info "Skipping GoogleTest build"
        else
            rm -rf "${BUILD_DIR}/googletest"
        fi
    fi

    if ! is_installed "GoogleTest" "lib/cmake/GTest/GTestConfig.cmake" || ask_rebuild "GoogleTest" 2>/dev/null; then

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

    # Check if already installed
    if is_installed "Google Benchmark" "lib/cmake/benchmark/benchmarkConfig.cmake"; then
        print_info "Google Benchmark already installed"
        if ! ask_rebuild "Google Benchmark"; then
            print_info "Skipping Google Benchmark build"
        else
            rm -rf "${BUILD_DIR}/benchmark"
        fi
    fi

    if ! is_installed "Google Benchmark" "lib/cmake/benchmark/benchmarkConfig.cmake" || ask_rebuild "Google Benchmark" 2>/dev/null; then

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
cat > "${ENV_SCRIPT}" << EOF
#!/bin/bash
# Source this script to set up the environment for using TPL libraries
# Usage: source ${INSTALL_PREFIX}/setup_env.sh

export PATH="${INSTALL_PREFIX}/bin:\$PATH"
export LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib:\$LD_LIBRARY_PATH"
export CMAKE_PREFIX_PATH="${INSTALL_PREFIX}:\$CMAKE_PREFIX_PATH"

if [ "$BUILD_PYTHON" = "yes" ]; then
    PYTHON_VERSION=\$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    export PYTHONPATH="${INSTALL_PREFIX}/lib/python\${PYTHON_VERSION}/site-packages:\$PYTHONPATH"
fi

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

if [ "$BUILD_MPI" = "yes" ]; then
    echo "  - Open MPI $([ "$ENABLE_CUDA" = "yes" ] && echo "(CUDA-aware)" || echo "")"
fi

if [ "$BUILD_PYTHON" = "yes" ]; then
    echo "  - pybind11"
    echo "  - pykokkos"
fi

echo "  - ADIOS2"

if [ "$BUILD_TESTS" = "yes" ]; then
    echo "  - GoogleTest"
    echo "  - Google Benchmark"
fi

echo ""
echo -e "${GREEN}Happy coding!${NC}"
