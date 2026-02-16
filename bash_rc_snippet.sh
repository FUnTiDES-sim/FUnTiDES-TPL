# ============================================================================
# TPL Environment Setup for .bashrc/.zshrc
# ============================================================================
# Add this to your ~/.bashrc or ~/.zshrc to automatically load TPL environment
#
# Instructions:
# 1. Edit the TPL_PREFIX path below to match your installation
# 2. Copy this entire block to the end of your ~/.bashrc or ~/.zshrc
# 3. Restart your terminal or run: source ~/.bashrc (or source ~/.zshrc)
# ============================================================================

# Set your TPL installation path
export TPL_PREFIX="$HOME/test"  # CHANGE THIS to your installation path

# Add TPL to environment
export PATH="${TPL_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${TPL_PREFIX}/lib:${TPL_PREFIX}/lib64:${LD_LIBRARY_PATH}"
export CMAKE_PREFIX_PATH="${TPL_PREFIX}:${CMAKE_PREFIX_PATH}"
export PKG_CONFIG_PATH="${TPL_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"

# Python packages (if you built Python dependencies)
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)
if [ -n "$PYTHON_VERSION" ] && [ -d "${TPL_PREFIX}/lib/python${PYTHON_VERSION}/site-packages" ]; then
    export PYTHONPATH="${TPL_PREFIX}/lib/python${PYTHON_VERSION}/site-packages:${PYTHONPATH}"
fi

# Optional: Create an alias to reload TPL environment
alias load-tpl='source ${TPL_PREFIX}/../setup_tpl_env.sh'

# ============================================================================
# End of TPL environment setup
# ============================================================================
