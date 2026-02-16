# Third-Party Libraries Repository

This repository contains all dependencies for the main project as git submodules.

## Dependencies Included

- **Kokkos 4.7** - Performance portability programming model
- **Open MPI 4.1.x** - CUDA-aware MPI implementation (stable, production-ready)
- **pykokkos** - Python bindings for Kokkos (includes pykokkos-base)
- **pybind11** - C++/Python binding library
- **ADIOS2** - I/O framework
- **GoogleTest** - C++ testing framework
- **Google Benchmark** - C++ microbenchmarking library

### Open MPI Version Notes

The repository defaults to Open MPI v4.1.x for maximum stability:
- **v4.1.x**: Most stable, production-ready, fewer dependencies ✅ **RECOMMENDED & DEFAULT**
- **v5.0.x**: Current stable, requires newer PMIx, more complex build
- **main/v6.x**: Development branch, removed C++ bindings (not recommended)

## Quick Start

### 1. Clone with Submodules

```bash
git clone --recursive https://github.com/FUnTiDES-sim/FUnTiDES-TPL fun-tpl
cd fun-tpl 
```

Or if you already cloned without `--recursive`:

```bash
git submodule update --init --recursive
```

### 2. Install Dependencies

```bash
./install.sh --prefix=$HOME/local
```

This will build and install all dependencies to `$HOME/local`.

## Installation Options

```bash
./install.sh [OPTIONS]

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
```

### Smart Rebuilding

The script automatically detects which components are already installed:
- **First run**: Builds everything
- **Subsequent runs**: Skips already-installed components
- **Prompted rebuilds**: Asks if you want to rebuild each installed component
- **Force rebuild**: Use `--force` to rebuild everything without prompting

Example:
```bash
# First install
./install.sh --prefix=$HOME/local --enable-cuda

# Later, add tests (Kokkos and MPI will be skipped)
./install.sh --prefix=$HOME/local --enable-cuda

# Force complete rebuild
./install.sh --prefix=$HOME/local --enable-cuda --force
```

### Examples

**Basic installation to custom location:**
```bash
./install.sh --prefix=/opt/myproject
```

**With CUDA support for specific GPU architecture:**
```bash
./install.sh --prefix=$HOME/local --enable-cuda --cuda-arch=80
```

**Using system MPI, skip tests:**
```bash
./install.sh --prefix=$HOME/local --disable-mpi --skip-tests
```

**Build without Python dependencies:**
```bash
./install.sh --prefix=$HOME/local --skip-python
```

## Manual Submodule Initialization

If you need to manually initialize submodules in the `external/` folder:

```bash
# Initialize all submodules
git submodule update --init --recursive external/*

# Or initialize specific submodules
git submodule update --init external/kokkos
git submodule update --init external/openmpi
git submodule update --init external/pykokkos
git submodule update --init external/pybind11
git submodule update --init external/adios2
git submodule update --init external/googletest
git submodule update --init external/benchmark
```

## Adding Submodules (For Maintainers)

To set up this repository from scratch:

```bash
# Create external directory
mkdir -p external

# Add submodules
git submodule add -b 4.7.00 https://github.com/kokkos/kokkos.git external/kokkos
git submodule add -b v4.1.x https://github.com/open-mpi/ompi.git external/openmpi
git submodule add https://github.com/kokkos/pykokkos.git external/pykokkos
git submodule add -b v2.13.0 https://github.com/pybind/pybind11.git external/pybind11
git submodule add -b master https://github.com/ornladios/ADIOS2.git external/adios2
git submodule add -b v1.15.2 https://github.com/google/googletest.git external/googletest
git submodule add -b v1.9.0 https://github.com/google/benchmark.git external/benchmark

# Commit
git add .gitmodules external/
git commit -m "Add TPL submodules"
```

## Setting Up Your Environment

After installation, you need to configure your environment to use the TPL libraries. There are several ways to do this:

### Option 1: Source the Setup Script (Recommended)

The installation creates a `setup_env.sh` script in your installation directory:

```bash
# Load TPL environment (do this once per terminal session)
source /path/to/install/setup_env.sh

# Or use the provided standalone script
source setup_tpl_env.sh /path/to/install
```

This sets:
- `PATH` - for executables (mpirun, etc.)
- `LD_LIBRARY_PATH` - for shared libraries
- `CMAKE_PREFIX_PATH` - for CMake to find packages
- `PKG_CONFIG_PATH` - for pkg-config
- `PYTHONPATH` - for Python packages (if built)

### Option 2: Add to Your Shell Configuration

To automatically load TPL environment in every new terminal, add to `~/.bashrc` or `~/.zshrc`:

```bash
# TPL Environment
export TPL_PREFIX="$HOME/test"  # Change to your install path
export PATH="${TPL_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${TPL_PREFIX}/lib:${LD_LIBRARY_PATH}"
export CMAKE_PREFIX_PATH="${TPL_PREFIX}:${CMAKE_PREFIX_PATH}"
```

See `bashrc_snippet.sh` for a complete example.

### Option 3: Manual Export (Quick Testing)

For quick testing, manually export the variables:

```bash
export CMAKE_PREFIX_PATH=/path/to/install:$CMAKE_PREFIX_PATH
export LD_LIBRARY_PATH=/path/to/install/lib:$LD_LIBRARY_PATH
export PATH=/path/to/install/bin:$PATH
```

### Verify Installation

Check that everything is working:

```bash
# Check MPI
which mpirun
mpirun --version

# Check libraries
ls $CMAKE_PREFIX_PATH/lib/cmake/

# Test with a simple CMake project
cmake -DCMAKE_PREFIX_PATH=/path/to/install ..
```

## Using in Your Main Project

After installation, add this to your main project's `CMakeLists.txt`:

```cmake
# Set the prefix path to find all dependencies
set(CMAKE_PREFIX_PATH "/path/to/install/prefix")

# Find packages
find_package(Kokkos REQUIRED)
find_package(MPI REQUIRED)
find_package(pybind11 REQUIRED)
find_package(ADIOS2 REQUIRED)
find_package(GTest REQUIRED)
find_package(benchmark REQUIRED)

# Link to your targets
target_link_libraries(your_target 
    PRIVATE 
    Kokkos::kokkos
    MPI::MPI_CXX
    pybind11::pybind11
    adios2::adios2
    GTest::gtest
    benchmark::benchmark
)
```

Or rely on the `CMAKE_PREFIX_PATH` environment variable (if you sourced the setup script):
```bash
source /path/to/install/setup_env.sh
cmake ..  # No need to specify CMAKE_PREFIX_PATH
```

## Requirements

- CMake 3.18+
- C++17 compatible compiler (GCC 7+, Clang 5+)
- Python 3.7+ with pip (for pykokkos)
- CUDA Toolkit 11.0+ (optional, for GPU support)
- For building Open MPI from git:
  - autoconf, automake, libtool
  - perl (for autogen.pl)
  - flex, bison (recommended)

**Note:** The install script automatically installs Python build dependencies (scikit-build, cmake, ninja) when building pykokkos.

## Troubleshooting

### CUDA-aware MPI not working
Make sure CUDA toolkit is in your PATH:
```bash
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

### Open MPI configure script not found
The script automatically runs `autogen.pl` to generate the configure script. If this fails, ensure you have the required tools:
```bash
# Ubuntu/Debian
sudo apt-get install autoconf automake libtool perl flex bison

# RHEL/CentOS/Rocky
sudo yum install autoconf automake libtool perl flex bison

# Or manually generate:
cd external/openmpi
./autogen.pl
```

### Open MPI configure script errors (syntax errors, OAC_PUSH_PREFIX)
If you see syntax errors in the configure script like "OAC_PUSH_PREFIX" or "unexpected token", the configure script is corrupted. Clean and regenerate:

```bash
cd external/openmpi
make distclean 2>/dev/null || true
rm -f configure
./autogen.pl
cd ../..
rm -rf build/openmpi
./install.sh --prefix=... --enable-cuda
```

The updated install.sh now does this automatically when building from git.

### Open MPI build errors (autotools/m4 macros)
If you see errors about m4 macros, AC_MSG_WARN, or OPAL_BUILD_DOCS during the build, you may have a newer development branch. The repository now defaults to v4.1.x which is stable. If you need to switch:

```bash
cd external/openmpi
git fetch origin
git checkout v4.1.x  # Default, most stable
cd ../..
rm -rf build/openmpi
./install.sh --prefix=... --enable-cuda
```

### Open MPI PMIx version error (v5.0.x only)
If using v5.0.x and you see "PRRTE requires PMIx v0x00060001 or above", switch to v4.1.x:

```bash
cd external/openmpi
git fetch origin
git checkout v4.1.x
git pull origin v4.1.x
cd ../..
rm -rf build/openmpi
./install.sh --prefix=... --enable-cuda
```

**Check your current version:**
```bash
cd external/openmpi
git branch  # Shows current branch
cat VERSION # Shows version number
```

**IMPORTANT:** If you see version 5.x or 6.x, you MUST switch to v4.1.x as shown above. The .gitmodules default is v4.1.x, but if you cloned before the update, you may still be on an older branch.

### pykokkos installation fails
The install script now automatically installs build dependencies (scikit-build, cmake, ninja) and sets CUDA architecture flags.

**Important:** pykokkos builds its own internal Kokkos, which can take 10-15 minutes and may have CUDA architecture issues.

If you encounter errors:

```bash
# Option 1: Skip pykokkos entirely (recommended if you don't need Python bindings)
./install.sh --prefix=... --enable-cuda --skip-python

# Option 2: Specify CUDA architecture explicitly
export CMAKE_ARGS="-DKokkos_ENABLE_CUDA=ON -DKokkos_ARCH_AMPERE80=ON"
cd external/pykokkos
python3 -m pip install --prefix=/path/to/install --break-system-packages .
```

**Common pykokkos errors:**
- `CUDA enabled but no NVIDIA GPU architecture` → Script now auto-sets this from --cuda-arch
- `ModuleNotFoundError: No module named 'skbuild'` → Build dependencies missing (auto-fixed by script)
- `Could not build wheels for pykokkos-base` → CUDA architecture issue or build timeout
- Permission denied → Use `--break-system-packages` or `--user` flag

**Note:** If you only need Kokkos for C++ (not Python), skip pykokkos with `--skip-python`.

### CMake doesn't find dependencies
Make sure CMAKE_PREFIX_PATH is set correctly:
```bash
cmake -DCMAKE_PREFIX_PATH=/path/to/install/prefix ..
```

## Build Artifacts

After a successful build, your installation directory will contain:

```
install/
├── bin/           # Executables (mpirun, etc.)
├── include/       # Header files
├── lib/           # Libraries and CMake config files
│   ├── cmake/
│   └── python3.X/site-packages/  # Python packages
└── share/         # Documentation and examples
```

## Updating Dependencies

To update all submodules to their latest commits:

```bash
git submodule update --remote --merge
```

To update a specific dependency:

```bash
git submodule update --remote --merge external/kokkos
```

## License

Each dependency has its own license. Please refer to individual submodules for license information.

## Support

For issues with:
- **This TPL repository**: Open an issue in this repo
- **Individual libraries**: Refer to the respective library's issue tracker
