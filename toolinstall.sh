#!/bin/bash

# Script to install unpackbootimg, mkbootimg, and tools for super.img (lpunpack and lpmake) using Python 3.10

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install dependencies for building tools
echo "Installing dependencies..."
sudo apt update
sudo apt install -y git make gcc g++ libelf-dev libssl-dev python3.10

# Ensure Python 3.10 is properly configured
if ! command_exists python3.10; then
    echo "Error: Python 3.10 is not installed. Please install it manually and rerun the script."
    exit 1
fi
echo "Python 3.10 is installed: $(python3.10 --version)"

# Install unpackbootimg and mkbootimg from AOSP
echo "Installing unpackbootimg and mkbootimg from AOSP..."

# Clone the AOSP repository (platform/system/tools/mkbootimg) via HTTPS
if [ ! -d "aosp-tools-mkbootimg" ]; then
    git clone https://android.googlesource.com/platform/system/tools/mkbootimg aosp-tools-mkbootimg
else
    echo "AOSP mkbootimg repository already cloned."
fi

# Install unpack_bootimg.py and mkbootimg.py with dependencies
cd aosp-tools-mkbootimg
sudo mkdir -p /usr/local/lib/aosp-tools-mkbootimg
sudo cp -r * /usr/local/lib/aosp-tools-mkbootimg/
# Create executable wrappers in /usr/local/bin/
echo '#!/bin/bash' | sudo tee /usr/local/bin/unpackbootimg > /dev/null
echo 'python3.10 /usr/local/lib/aosp-tools-mkbootimg/unpack_bootimg.py "$@"' | sudo tee -a /usr/local/bin/unpackbootimg > /dev/null
echo '#!/bin/bash' | sudo tee /usr/local/bin/mkbootimg > /dev/null
echo 'python3.10 /usr/local/lib/aosp-tools-mkbootimg/mkbootimg.py "$@"' | sudo tee -a /usr/local/bin/mkbootimg > /dev/null
sudo chmod +x /usr/local/bin/unpackbootimg /usr/local/bin/mkbootimg
cd ..

# Verify installation of unpackbootimg and mkbootimg
if command_exists unpackbootimg && command_exists mkbootimg; then
    echo "unpackbootimg and mkbootimg installed successfully."
    # Test the tools with --help to ensure they run with Python 3.10
    unpackbootimg --help >/dev/null 2>&1 && mkbootimg --help >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Tools verified: unpackbootimg and mkbootimg are functional with Python 3.10."
    else
        echo "Error: Tools installed but failed to run."
        echo "Testing unpackbootimg manually:"
        unpackbootimg --help
        echo "Testing mkbootimg manually:"
        mkbootimg --help
        echo "Check the output above for errors."
        exit 1
    fi
else
    echo "Error: Failed to install unpackbootimg or mkbootimg."
    exit 1
fi

# Install tools for super.img (lpunpack and lpmake) from Dvalin21/lpunpack
echo "Installing lpunpack and lpmake from https://github.com/Dvalin21/lpunpack..."

# Clone Dvalin21/lpunpack repository via HTTPS (public repo, no auth needed)
if [ ! -d "dvalin21-lpunpack" ]; then
    git clone https://github.com/Dvalin21/lpunpack.git dvalin21-lpunpack
else
    echo "Dvalin21/lpunpack repository already cloned."
fi

# Build and install lpunpack and lpmake (assuming source code or binaries are present)
cd dvalin21-lpunpack
if [ -f "lpunpack" ] && [ -f "lpmake" ]; then
    # If precompiled binaries exist, copy them directly
    sudo cp lpunpack /usr/local/bin/
    sudo cp lpmake /usr/local/bin/
    sudo chmod +x /usr/local/bin/lpunpack /usr/local/bin/lpmake
else
    # If source code needs building (assuming a Makefile or build script exists)
    if [ -f "Makefile" ]; then
        make
        sudo cp lpunpack /usr/local/bin/
        sudo cp lpmake /usr/local/bin/
        sudo chmod +x /usr/local/bin/lpunpack /usr/local/bin/lpmake
    else
        echo "Error: No precompiled lpunpack/lpmake binaries or Makefile found in the repository."
        echo "Please check the repository contents at https://github.com/Dvalin21/lpunpack."
        exit 1
    fi
fi
cd ..

# Verify installation of lpunpack and lpmake
if command_exists lpunpack && command_exists lpmake; then
    echo "lpunpack and lpmake installed successfully."
    # Test the tools with --help (basic check since they may not have --version)
    lpunpack --help >/dev/null 2>&1 && lpmake --help >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Tools verified: lpunpack and lpmake are functional."
    else
        echo "Warning: Tools installed but may not run correctly."
        echo "Testing lpunpack manually:"
        lpunpack --help
        echo "Testing lpmake manually:"
        lpmake --help
        echo "Check the output above for errors."
    fi
else
    echo "Error: Failed to install lpunpack or lpmake."
    exit 1
fi

echo "Installation complete. You can now use unpackbootimg, mkbootimg, lpunpack, and lpmake."
