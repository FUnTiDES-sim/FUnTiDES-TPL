# Third-Party Libraries Repository

This repository contains all dependencies for the main project as git submodules.

## Dependencies Included

- **Kokkos 4.7** - Performance portability programming model
- **pykokkos** - Python bindings for Kokkos (includes pykokkos-base)
- **pybind11** - C++/Python binding library
- **ADIOS2** - I/O framework (optional, `--enable-adios2`)
- **GoogleTest** - C++ testing framework
- **Google Benchmark** - C++ microbenchmarking library

### MPI

MPI is not provided: use the MPI of your machine (system package or module).
Building MPI here would risk a mismatch with the machine's MPI stack. ADIOS2,
when enabled, is built without MPI (FUnTiDES uses its serial API only), so the
TPL never links against any MPI.

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
  --prefix=PATH                Installation prefix (default: ./install)
  --enable-cuda                Enable CUDA support (default: auto-detect)
  --disable-cuda               Disable CUDA support
  --enable-cuda-uvm            Build Kokkos with CUDA UVM as default memory space (default: no)
  --cuda-arch=ARCH             GPU compute capability, single value, e.g. 89 for
                               RTX 40xx (default: auto-detect with nvidia-smi)
  --skip-python                Skip all Python dependencies (kokkos module and pykokkos)
  --skip-pykokkos              Skip pykokkos Python interface (keep kokkos module only)
  --skip-tests                 Skip test libraries (GTest, GBench)
  --enable-adios2              Build ADIOS2 (default: no; needed only for FUNTIDES_ENABLE_ADIOS2=ON)
  --enable-venv                Use Python virtual environment (default: no)
  --no-venv, --disable-venv    Do not use a virtual environment (default)
  --venv-name=NAME             Virtual environment name (default: tpl-venv)
  --python-prefix=PATH         Python installation prefix (default: auto-detect)
  --jobs=N                     Number of parallel jobs (default: 8)
  --pykokkos-build-threads=N   Parallel threads for PyKokkos build, memory intensive (default: 2)
  --force                      Force rebuild of all components
  -h, --help                   Show this help message
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

# Later, rerun (already-installed components are skipped)
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

**Skip tests, build ADIOS2:**
```bash
./install.sh --prefix=$HOME/local --skip-tests --enable-adios2
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

# Or use the standalone script of this repository
source FUnTiDES-TPL/setup_env.sh /path/to/install
```

Both scripts can be sourced several times: entries already present are not added again.
The generated script also activates the virtual environment when `--enable-venv` was used.

This sets:
- `PATH` - for executables
- `LD_LIBRARY_PATH` - for shared libraries
- `CMAKE_PREFIX_PATH` - for CMake to find packages
- `PKG_CONFIG_PATH` - for pkg-config
- `PYTHONPATH` - for Python packages (if built)

### Option 2: Add to Your Shell Configuration

To automatically load TPL environment in every new terminal, add to `~/.bashrc` or `~/.zshrc`:

```bash
# TPL Environment
source /path/to/install/setup_env.sh > /dev/null
```

See `bash_rc_snippet.sh` for a complete example.

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
find_package(MPI REQUIRED)          # system MPI, not provided by the TPL
find_package(pybind11 REQUIRED)
find_package(ADIOS2 REQUIRED)       # only if built with --enable-adios2
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
- MPI from the system (optional, only for MPI builds of FUnTiDES)

**Note:** The install script automatically installs Python build dependencies (scikit-build, cmake, ninja) when building pykokkos.

## Troubleshooting

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


### Troubleshooting: Pybind11 & NVCC Compilation Bug

When building the Python wrapper (`ENABLE_PYWRAP=ON`) with **CUDA/Kokkos enabled** on systems using newer host compilers (like GCC 13 or GCC 14), you might encounter a fatal compilation error from the NVIDIA compiler (`nvcc`) when it tries to parse the Pybind11 headers.

**Typical Error Output:**
`error: ambiguous template instantiation for ‘struct pybind11::detail::initimpl::factory<pybind11::enum_...`

This is a known bug in nvcc's C++ parser where it fails to parse a specific lambda function used inside pybind11.h when paired with modern GCC standard libraries.
The Workaround

To completely bypass this bug and finish compiling the Python module, comment out the problematic line in your local Pybind11 installation.

Locate your pybind11.h file. Look at the path in your compiler error log (e.g., ~/local/include/pybind11/pybind11.h or /usr/include/pybind11/pybind11.h).

Find the enum integer constructor. Open the file and search for the following exact line (usually around line 2237 or 2978, depending on your Pybind11 version):
C++

`def(init([](Scalar i) { return static_cast<Type>(i); }), arg("value"));`

Comment the line out by adding // to the beginning:
Recompile. Save the file and run make -j again in FUnTiDES.

Note: Commenting out this line removes the ability to instantiate enums directly from integers in Python (e.g., calling MethodType(1) will no longer work). However, standard enum attribute access (e.g., MethodType.SEM) remains completely intact and will function normally.

## Build Artifacts

After a successful build, your installation directory will contain:

```
install/
├── bin/           # Executables
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
