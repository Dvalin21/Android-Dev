#!/bin/bash

# Script to pull and decompile recovery or boot_a/boot_b partitions from an Android device

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if adb is installed
if ! command_exists adb; then
    echo "Error: adb is not installed. Please install Android platform tools first."
    exit 1
fi

# Check if unpackbootimg is installed
if ! command_exists unpackbootimg; then
    echo "Error: unpackbootimg is not installed. Please run the third script to install it first."
    exit 1
fi

# Start adb server
adb start-server

# List connected devices
devices=$(adb devices | grep -w "device" | awk '{print $1}')
if [ -z "$devices" ]; then
    echo "Error: No devices connected. Please connect an Android device with USB debugging enabled."
    exit 1
fi

echo "Connected devices:"
echo "$devices"

# Process each connected device
for device in $devices; do
    echo -e "\nProcessing device: $device"

    # Get device codename
    codename=$(adb -s "$device" shell getprop ro.product.device)
    if [ -z "$codename" ]; then
        codename=$(adb -s "$device" shell getprop ro.product.name)
    fi
    echo "Device Codename: $codename"

    # Check for ADB root access
    adb_root=$(adb -s "$device" shell whoami 2>/dev/null)
    if [ "$adb_root" != "root" ]; then
        echo "Warning: ADB does not have root access. Attempting to elevate privileges..."
        adb -s "$device" root >/dev/null 2>&1
        sleep 2  # Wait for adbd to restart
        adb_root=$(adb -s "$device" shell whoami 2>/dev/null)
        if [ "$adb_root" != "root" ]; then
            echo "Error: ADB root access unavailable. Root your device or use an alternative method (e.g., SP Flash Tool)."
            echo "Continuing without root, but pulling partitions may fail."
        else
            echo "ADB now running as root."
        fi
    else
        echo "ADB already running as root."
    fi

    # Try to find recovery partition (recovery, recovery_a, recovery_b)
    recovery_path=$(adb -s "$device" shell ls /dev/block/platform/*/by-name/recovery 2>/dev/null)
    if [ -z "$recovery_path" ]; then
        recovery_path=$(adb -s "$device" shell ls /dev/block/platform/*/by-name/recovery_a 2>/dev/null)
    fi
    if [ -z "$recovery_path" ]; then
        recovery_path=$(adb -s "$device" shell ls /dev/block/platform/*/by-name/recovery_b 2>/dev/null)
    fi

    if [ -n "$recovery_path" ]; then
        # Recovery partition found, pull it
        echo "Pulling recovery.img..."
        adb -s "$device" pull "$recovery_path" "recovery_$codename.img"
        if [ -f "recovery_$codename.img" ]; then
            echo "Recovery image pulled to recovery_$codename.img"
            # Decompile recovery image
            echo "Unpacking recovery_$codename.img..."
            unpackbootimg -i "recovery_$codename.img" -o "recovery_$codename_unpacked"
            if [ -d "recovery_$codename_unpacked" ]; then
                echo "Recovery image unpacked to recovery_$codename_unpacked"
            else
                echo "Error: Failed to unpack recovery_$codename.img"
            fi
        else
            echo "Failed to pull recovery.img"
        fi
    else
        # No recovery partition found, proceed with boot_a and boot_b
        echo "No recovery partition found. Pulling boot_a and boot_b instead."
        boot_a_path=$(adb -s "$device" shell ls /dev/block/platform/*/by-name/boot_a 2>/dev/null)
        boot_b_path=$(adb -s "$device" shell ls /dev/block/platform/*/by-name/boot_b 2>/dev/null)

        if [ -n "$boot_a_path" ] && [ -n "$boot_b_path" ]; then
            # Create working directory
            mkdir -p "device_$codename"
            
            # Try direct pull first
            echo "Pulling boot_a.img..."
            adb -s "$device" pull "$boot_a_path" "device_$codename/boot_a.img" 2>/tmp/adb_error_a
            pull_a_status=$?
            echo "Pulling boot_b.img..."
            adb -s "$device" pull "$boot_b_path" "device_$codename/boot_b.img" 2>/tmp/adb_error_b
            pull_b_status=$?

            if [ $pull_a_status -eq 0 ] && [ $pull_b_status -eq 0 ] && [ -f "device_$codename/boot_a.img" ] && [ -f "device_$codename/boot_b.img" ]; then
                echo "Boot images pulled to device_$codename/boot_a.img and device_$codename/boot_b.img"
            else
                echo "Direct pull failed. Error details:"
                cat /tmp/adb_error_a
                cat /tmp/adb_error_b
                rm -f /tmp/adb_error_a /tmp/adb_error_b

                # Fallback to on-device dump if root is available
                if [ "$adb_root" = "root" ]; then
                    echo "Attempting on-device dump as fallback..."
                    adb -s "$device" shell "dd if=$boot_a_path of=/sdcard/boot_a.img bs=4M"
                    adb -s "$device" shell "dd if=$boot_b_path of=/sdcard/boot_b.img bs=4M"
                    adb -s "$device" pull "/sdcard/boot_a.img" "device_$codename/boot_a.img"
                    adb -s "$device" pull "/sdcard/boot_b.img" "device_$codename/boot_b.img"
                    adb -s "$device" shell "rm /sdcard/boot_a.img /sdcard/boot_b.img"
                else
                    echo "Error: No root access for on-device dump. Use SP Flash Tool or root your device."
                    continue
                fi
            fi

            # Check if files were pulled successfully
            if [ -f "device_$codename/boot_a.img" ] && [ -f "device_$codename/boot_b.img" ]; then
                echo "Boot images pulled to device_$codename/boot_a.img and device_$codename/boot_b.img"
                
                # Decompile boot_a and boot_b
                echo "Unpacking boot_a.img..."
                unpackbootimg -i "device_$codename/boot_a.img" -o "device_$codename/boot_a_unpacked"
                if [ -d "device_$codename/boot_a_unpacked" ]; then
                    echo "Boot_a image unpacked to device_$codename/boot_a_unpacked"
                else
                    echo "Error: Failed to unpack boot_a.img"
                fi
                
                echo "Unpacking boot_b.img..."
                unpackbootimg -i "device_$codename/boot_b.img" -o "device_$codename/boot_b_unpacked"
                if [ -d "device_$codename/boot_b_unpacked" ]; then
                    echo "Boot_b image unpacked to device_$codename/boot_b_unpacked"
                else
                    echo "Error: Failed to unpack boot_b.img"
                fi
            else
                echo "Failed to pull one or both boot images even with fallback."
            fi
        else
            echo "Error: Could not find boot_a and boot_b partitions."
            echo "Available partitions:"
            adb -s "$device" shell ls -d /dev/block/platform/*/by-name/* 2>/dev/null
        fi
    fi
done

echo -e "\nDevice processing complete."
