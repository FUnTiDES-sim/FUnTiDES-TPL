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

if [ ! -d "${EXTERNAL_DIR}/kokkos/.git" ]; then
    print_warning "Submodules not initialized. Initializing now..."
    git submodule update --init --recursive
fi

print_info "All submodules ready"

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
else
    print_info "Skipping Open MPI build (using system MPI or disabled)"
fi

# ==============================================================================
# Build Kokkos
# ==============================================================================

print_header "Building Kokkos"

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

# ==============================================================================
# Build pybind11
# ==============================================================================

if [ "$BUILD_PYTHON" = "yes" ]; then
    print_header "Building pybind11"

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
fi

# ==============================================================================
# Build pykokkos
# ==============================================================================

if [ "$BUILD_PYTHON" = "yes" ]; then
    print_header "Building pykokkos"

    cd "${EXTERNAL_DIR}/pykokkos"

    # Set environment for pykokkos build
    export CMAKE_PREFIX_PATH="${INSTALL_PREFIX}:${CMAKE_PREFIX_PATH}"
    export PYTHONPATH="${INSTALL_PREFIX}/lib/python$(${PYTHON_EXEC} -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/site-packages:${PYTHONPATH}"

    print_info "Installing pykokkos..."
    ${PYTHON_EXEC} -m pip install --prefix="${INSTALL_PREFIX}" --no-build-isolation .

    print_info "pykokkos installed successfully"
fi

# ==============================================================================
# Build ADIOS2
# ==============================================================================

print_header "Building ADIOS2"

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

if [ "$ENABLE_CUDA" = "yes" ]; then
    CMAKE_ARGS+=(-DADIOS2_USE_CUDA=ON)
    print_info "Enabling CUDA support"
fi

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

# ==============================================================================
# Build GoogleTest
# ==============================================================================

if [ "$BUILD_TESTS" = "yes" ]; then
    print_header "Building GoogleTest"

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
fi

# ==============================================================================
# Build Google Benchmark
# ==============================================================================

if [ "$BUILD_TESTS" = "yes" ]; then
    print_header "Building Google Benchmark"

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
