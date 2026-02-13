# Third-Party Libraries Repository

This repository contains all dependencies for the main project as git submodules.

## Dependencies Included

- **Kokkos 4.7** - Performance portability programming model
- **Open MPI** - CUDA-aware MPI implementation
- **pykokkos** - Python bindings for Kokkos (includes pykokkos-base)
- **pybind11** - C++/Python binding library
- **ADIOS2** - I/O framework
- **GoogleTest** - C++ testing framework
- **Google Benchmark** - C++ microbenchmarking library

## Quick Start

### 1. Clone with Submodules

```bash
git clone --recursive https://github.com/yourusername/your-tpl-repo.git
cd your-tpl-repo
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
  -h, --help             Show this help message
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
git submodule add -b main https://github.com/open-mpi/ompi.git external/openmpi
git submodule add https://github.com/kokkos/pykokkos.git external/pykokkos
git submodule add -b v2.13.0 https://github.com/pybind/pybind11.git external/pybind11
git submodule add -b master https://github.com/ornladios/ADIOS2.git external/adios2
git submodule add -b v1.15.2 https://github.com/google/googletest.git external/googletest
git submodule add -b v1.9.0 https://github.com/google/benchmark.git external/benchmark

# Commit
git add .gitmodules external/
git commit -m "Add TPL submodules"
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

Or set the environment variable:
```bash
export CMAKE_PREFIX_PATH=/path/to/install/prefix:$CMAKE_PREFIX_PATH
```

## Requirements

- CMake 3.18+
- C++17 compatible compiler (GCC 7+, Clang 5+)
- Python 3.7+ (for pykokkos)
- CUDA Toolkit 11.0+ (optional, for GPU support)
- For building Open MPI from git:
  - autoconf, automake, libtool
  - perl (for autogen.pl)
  - flex, bison (recommended)

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

### Open MPI C++ bindings error
If you see an error about MPI C++ bindings, you may have the development branch (v6.x) which removed C++ support. Switch to the stable v5.0.x branch:
```bash
cd external/openmpi
git fetch origin
git checkout v5.0.x
cd ../..
# Clean and rebuild
rm -rf build/openmpi
./install.sh --prefix=... --enable-cuda
```

### pykokkos installation fails
Ensure you have a compatible Python environment:
```bash
python3 -m pip install --upgrade pip setuptools wheel
```

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
