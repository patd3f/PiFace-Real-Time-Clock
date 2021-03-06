#!/bin/bash
#: Description: Enables the required modules for PiFace Clock.

#=======================================================================
# NAME: check_for_i2c_tools
# DESCRIPTION: Checks if i2c-tools is installed.
#=======================================================================
check_for_i2c_tools() {
    dpkg -s i2c-tools > /dev/null 2>&1
    if [[ $? -eq 1 ]]; then
        echo "The package `i2c-tools` is not installed. Install it with:"
        echo ""
        echo "    sudo apt-get install i2c-tools"
        echo ""
        exit 1
    fi
}

#=======================================================================
# NAME: set_revision_var
# DESCRIPTION: Stores the revision number of this Raspberry Pi into
#              $RPI_REVISION
#=======================================================================
set_revision_var() {
    rev_str=$(grep "Revision" /proc/cpuinfo)
    # get the last character
    len_rev_str=${#rev_str}
    chr_index=$(($len_rev_str-1))
    chr=${rev_str:$chr_index:$len_rev_str}
    if [[ $chr == "2" || $chr == "3" ]]; then
        RPI_REVISION="1"
    else
        RPI_REVISION="2"
    fi
}

#=======================================================================
# NAME: start_on_boot
# DESCRIPTION: Load the I2C modules and send magic number to RTC, on boot.
#=======================================================================
start_on_boot() {
    echo "Changing /etc/rc.local to load time from PiFace Clock."
    # remove exit 0
    sed -i "s/exit 0//" /etc/rc.local

    if [[ $RPI_REVISION == "1" ]]; then
        i=0  # i2c-0
    else
        i=1  # i2c-1
    fi

    cat >> /etc/rc.local << EOF
modprobe i2c-dev
# Calibrate the clock (default: 0x47). See datasheet for MCP7940N
i2cset -y $i 0x6f 0x08 0x47
modprobe i2c:mcp7941x
echo mcp7941x 0x6f > /sys/class/i2c-dev/i2c-$i/device/new_device
hwclock --hctosys
EOF
}

#=======================================================================
# MAIN
#=======================================================================
# check if the script is being run as root
if [[ $EUID -ne 0 ]]
then
    printf 'This script must be run as root.\nExiting..\n'
    exit 1
fi
RPI_REVISION=""
check_for_i2c_tools &&
set_revision_var &&
start_on_boot &&
if [[ ! -e /sys/class/i2c-dev/i2c-$i ]]; then
    echo "Enable I2C by using:"
    echo ""
    echo "    raspi-config"
    echo ""
    echo "Then navigate to 'Advanced Options' > 'I2C' and select 'yes' to "
    echo "enable the ARM I2C interface. Then *reboot* and set your clock "
    echo "with:"
else
    echo "Now *reboot* and set your clock with:"
fi
echo ""
echo '    sudo date -s "14 JAN 2014 10:10:30"'
echo "    hwclock --systohc"
echo ""
