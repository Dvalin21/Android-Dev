#!/bin/bash

# Script to set up a Linux system (Ubuntu 20.04 or later) for Android development
# Includes installation of essential packages and the latest Android SDK

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Ubuntu version (requires 20.04 or later)
echo "Checking Ubuntu version..."
UBUNTU_VERSION=$(lsb_release -rs)
if [[ "$UBUNTU_VERSION" < "20.04" ]]; then
    echo "Error: Ubuntu 20.04 or later is required. Current version: $UBUNTU_VERSION"
    exit 1
fi
echo "Ubuntu version $UBUNTU_VERSION is compatible."

# Install required packages for Android development
echo "Installing required packages..."
sudo apt update
sudo apt install -y \
    git \
    gnupg \
    flex \
    bison \
    build-essential \
    zip \
    curl \
    zlib1g-dev \
    gcc-multilib \
    g++-multilib \
    libc6-dev-i386 \
    lib32ncurses5-dev \
    x11proto-core-dev \
    libx11-dev \
    lib32z1-dev \
    libgl1-mesa-dev \
    libxml2-utils \
    xsltproc \
    unzip \
    fontconfig \
    repo \
    openjdk-11-jre-headless
echo "Package installation complete."

# Set up Android SDK
SDK_DIR="$HOME/Android/Sdk"
if [ ! -d "$SDK_DIR" ]; then
    echo "Downloading Android SDK command-line tools..."
    # Note: Check https://developer.android.com/studio#command-line-tools for the latest version
    SDK_URL="https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip"
    wget "$SDK_URL" -O /tmp/commandlinetools.zip
    if [ ! -f /tmp/commandlinetools.zip ]; then
        echo "Error: Failed to download Android SDK command-line tools."
        exit 1
    fi
    echo "Extracting SDK to $SDK_DIR..."
    mkdir -p "$SDK_DIR/cmdline-tools"
    unzip /tmp/commandlinetools.zip -d "$SDK_DIR/cmdline-tools"
    mv "$SDK_DIR/cmdline-tools/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
    rm /tmp/commandlinetools.zip
else
    echo "Android SDK directory already exists at $SDK_DIR."
fi

# Install platform-tools (includes adb and fastboot) using sdkmanager
echo "Installing platform-tools..."
yes | "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" "platform-tools"

# Determine shell configuration file (bash or zsh)
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
    echo "Using zsh configuration file: $SHELL_CONFIG"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
    echo "Using bash configuration file: $SHELL_CONFIG"
else
    SHELL_CONFIG=""
    echo "Warning: Neither .bashrc nor .zshrc found."
fi

# Update PATH with Android SDK tools
if [ -n "$SHELL_CONFIG" ]; then
    if ! grep -q "$SDK_DIR/cmdline-tools/latest/bin" "$SHELL_CONFIG"; then
        echo "Adding Android SDK tools to PATH in $SHELL_CONFIG"
        echo "export PATH=\$PATH:$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools" >> "$SHELL_CONFIG"
        echo "Please restart your terminal or run 'source $SHELL_CONFIG' to apply changes."
    else
        echo "PATH already includes Android SDK tools."
    fi
else
    echo "Please manually add the following to your shell configuration:"
    echo "export PATH=\$PATH:$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools"
fi

# Check disk space (recommend at least 100GB free on /)
echo "Checking disk space..."
DISK_SPACE=$(df -BG / | grep '/' | awk '{print $4}' | sed 's/G//')
if [ "$DISK_SPACE" -lt 100 ]; then
    echo "Warning: Less than 100GB of disk space available on /. Current free space: ${DISK_SPACE}GB"
    echo "Android development (e.g., AOSP builds) may require more space."
else
    echo "Sufficient disk space available: ${DISK_SPACE}GB"
fi

# Check RAM (recommend at least 16GB)
echo "Checking RAM..."
RAM=$(free -m | grep Mem | awk '{print $2}')
if [ "$RAM" -lt 16000 ]; then
    echo "Warning: Less than 16GB of RAM available. Current RAM: $((RAM / 1024))GB"
    echo "Android development may perform better with more RAM."
else
    echo "Sufficient RAM available: $((RAM / 1024))GB"
fi

# Final instructions
echo "Android development environment setup complete!"
echo "To install additional SDK components (e.g., build-tools, platforms), use sdkmanager:"
echo "Example: $SDK_DIR/cmdline-tools/latest/bin/sdkmanager \"build-tools;30.0.3\" \"platforms;android-30\""
echo "Adjust the versions based on your project requirements."
