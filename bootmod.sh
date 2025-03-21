#!/bin/bash

# Script to decompile a boot.img file (including MTK ramdisk) and optionally repack it

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install required tools
echo "Checking and installing required tools..."
if ! command_exists unpackbootimg; then
    echo "Error: unpackbootimg is not installed. Please run the third script to install it first."
    exit 1
fi
if ! command_exists mkbootimg; then
    echo "Error: mkbootimg is not installed. Please run the third script to install it first."
    exit 1
fi
if ! command_exists lz4; then
    sudo apt update && sudo apt install -y lz4
fi
if ! command_exists xz; then
    sudo apt update && sudo apt install -y xz-utils
fi

# Check if boot.img exists in the current directory
if [ ! -f "boot.img" ]; then
    echo "Error: boot.img not found in the current directory."
    echo "Please place boot.img in $(pwd) or specify its path as an argument (e.g., ./script.sh /path/to/boot.img)."
    exit 1
fi

# Use provided boot.img path if given as an argument
boot_img="boot.img"
if [ -n "$1" ] && [ -f "$1" ]; then
    boot_img="$1"
    echo "Using provided boot.img: $boot_img"
fi

# Get device codename (optional, for naming)
codename=$(adb shell getprop ro.product.device 2>/dev/null)
if [ -z "$codename" ]; then
    codename=$(adb shell getprop ro.product.name 2>/dev/null)
fi
if [ -z "$codename" ]; then
    codename="unknown"
fi
echo "Device Codename (detected or default): $codename"

# Decompile boot.img with corrected options
output_dir="boot_${codename}_unpacked"
echo "Unpacking $boot_img..."
unpackbootimg --boot_img "$boot_img" --out "$output_dir"
if [ -d "$output_dir" ]; then
    echo "Boot image unpacked to $output_dir"
    ls -l "$output_dir"
else
    echo "Error: Failed to unpack $boot_img"
    echo "Check if $boot_img is a valid boot image or if unpackbootimg is correctly installed."
    exit 1
fi

# Find and decompile the ramdisk
ramdisk_file="$output_dir/ramdisk"  # Adjust based on actual output
if [ ! -f "$ramdisk_file" ]; then
    ramdisk_file="$output_dir/$(ls $output_dir | grep -E 'ramdisk|ramdisk.gz')"
fi
if [ -f "$ramdisk_file" ]; then
    echo "Decompiling ramdisk from $ramdisk_file..."
    mkdir -p "ramdisk_$codename"
    cd "ramdisk_$codename"

    # Check ramdisk format
    file_type=$(file "../$ramdisk_file")
    echo "Ramdisk file type: $file_type"

    if echo "$file_type" | grep -q "gzip"; then
        gunzip -c "../$ramdisk_file" | cpio -i -d -m 2>/dev/null
    elif echo "$file_type" | grep -q "LZ4"; then
        lz4 -d "../$ramdisk_file" - | cpio -i -d -m 2>/dev/null
    elif echo "$file_type" | grep -q "XZ"; then
        xz -dc "../$ramdisk_file" | cpio -i -d -m 2>/dev/null
    elif echo "$file_type" | grep -q "cpio"; then
        cpio -i -d -m < "../$ramdisk_file" 2>/dev/null
    else
        echo "Unknown format, attempting MTK header strip..."
        tail -c +513 "../$ramdisk_file" > ../ramdisk_no_header
        file_type=$(file ../ramdisk_no_header)
        echo "Adjusted ramdisk file type: $file_type"
        if echo "$file_type" | grep -q "gzip"; then
            gunzip -c ../ramdisk_no_header | cpio -i -d -m 2>/dev/null
        elif echo "$file_type" | grep -q "cpio"; then
            cpio -i -d -m < ../ramdisk_no_header 2>/dev/null
        else
            echo "Trying raw extraction as last resort..."
            cpio -i -d -m < "../$ramdisk_file" 2>/dev/null
        fi
        rm -f ../ramdisk_no_header
    fi

    if [ $? -eq 0 ] && [ -n "$(ls -A)" ]; then
        cd ..
        echo "Ramdisk decompiled to ramdisk_$codename"
        ls -l "ramdisk_$codename"
    else
        cd ..
        echo "Error: Failed to decompile ramdisk from $ramdisk_file"
        echo "Ramdisk may be corrupted or in an unsupported format."
        echo "Inspect with: file $ramdisk_file"
        echo "         and: hexdump -C $ramdisk_file | head"
        exit 1
    fi
else
    echo "Error: No ramdisk file found in $output_dir"
    echo "The boot image may not contain a ramdisk or unpacking failed."
    exit 1
fi

# Offer to repack (optional)
echo "Would you like to repack the boot image after making changes? (y/n)"
read -r repack
if [ "$repack" = "y" ] || [ "$repack" = "Y" ]; then
    # Gather parameters from unpacked files
    kernel="$output_dir/$(ls $output_dir | grep zImage)"
    ramdisk="$output_dir/$(ls $output_dir | grep ramdisk)"
    dtb="$output_dir/$(ls $output_dir | grep dtb)"
    base=$(cat "$output_dir/$(ls $output_dir | grep base)")
    cmdline=$(cat "$output_dir/$(ls $output_dir | grep cmdline)")
    pagesize=$(cat "$output_dir/$(ls $output_dir | grep pagesize)")

    # Construct mkbootimg command
    mkbootimg_cmd="mkbootimg --kernel $kernel --ramdisk $ramdisk --base $base --cmdline \"$cmdline\" --pagesize $pagesize"
    if [ -n "$dtb" ] && [ -f "$dtb" ]; then
        mkbootimg_cmd="$mkbootimg_cmd --dtb $dtb"
    fi
    mkbootimg_cmd="$mkbootimg_cmd --output new_boot_$codename.img"

    echo "Repacking boot image with command:"
    echo "$mkbootimg_cmd"
    eval "$mkbootimg_cmd"
    
    if [ -f "new_boot_$codename.img" ]; then
        echo "Boot image repacked as new_boot_$codename.img"
    else
        echo "Error: Failed to repack boot image"
        echo "Check if all required files (kernel, ramdisk, etc.) are present in $output_dir"
        exit 1
    fi
fi
