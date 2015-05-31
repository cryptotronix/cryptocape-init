#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "You must be root to run this script"
    exit 1
fi

#tpm sys moved, so let's check for the new dir...
#https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=313d21eeab9282e01fdcecd40e9ca87e0953627f
sys_tpm="/sys/class/tpm"
if [ ! -d ${sys_tpm}/tpm0/ ] ; then
    sys_tpm="/sys/class/misc"
fi

crypto_cape_attached_p(){
    dmesg | grep "dtbo 'BB-BONE-CRYPTO-00A0.dtbo' loaded"
}

tpm_active(){
    TPM_ACTIVE=$(cat ${sys_tpm}/tpm0/device/active)
}

tpm_enabled(){
    TPM_ENABLED=$(cat ${sys_tpm}/tpm0/device/enabled)
}

tpm_owned(){
    TPM_OWNED=$(cat ${sys_tpm}/tpm0/device/owned)
}

running_systemd_p(){
    INITSYS="ps h -p 1 -o comm"
    [ "$INITSYS" = "systemd" ]
}

tcsd_running_p(){
    pgrep tcsd 2>/dev/null 1>/dev/null
    [ $? -eq 0 ]
}

stop_tcsd(){
    echo "Stopping TCSD"
    if [ tcsd_running_p -eq 0 ]; then
        if [ running_systemd_p -eq 0 ]; then
            systemctl trousers.service stop
        else
            service trousers stop
        fi

        if [ tcsd_running_p -eq 0 ]; then
            pkill tcsd
        fi
    fi
}

start_tcsd(){
    echo "Starting TCSD"
    if [ tcsd_running_p -ne 0 ]; then
        if [ running_systemd_p -eq 0 ]; then
            systemctl trousers.service start
        else
            service trousers start
        fi

        if [ tcsd_running_p -ne 0 ]; then
            tcsd
        fi
    fi
}

if [[ crypto_cape_attached_p -ne 0 ]]; then
    echo "You must boot with the CryptoCape attached"
    exit 1
fi

prelude(){
    apt-get install -y git trousers tpm-tools libtspi1 libtspi-dev build-essential
}

part1(){

    prelude

    gcc tpm_assert/tpm_assertpp.c -o tpm_assertpp

    stop_tcsd

    echo Setting PP
    ./tpm_assertpp

    if [[ "$?" != 0 ]]; then
        echo "Setting PP failed. We can't continue."
        exit 1
    fi

    start_tcsd

    echo Clearing the TPM
    tpm_clear -f

    echo Enabling the TPM
    tpm_setenable -e -f
    tpm_setactive -a

    rm tpm_assertpp

    echo Halting the BBB. Pull power and re-connect to continue.
    halt
}

print_tpm_status(){
    tpm_active
    tpm_enabled
    tpm_owned

    echo "TPM Active: $TPM_ACTIVE"
    echo "TPM Enabled: $TPM_ENABLED"
    echo "TPM Owned: $TPM_OWNED"
}

is_compliance_vector_loaded(){
    C_PUBEK_START="AB 56 7C 0E 60 8C 5C 18 9E 90 2C 37 32 CF E3 FE"
    cat ${sys_tpm}/tpm0/device/pubek | grep "^$C_PUBEK_START"
}

need_EK(){
    IS_EK=$(tpm_getpubek 2>&1)
    echo "$IS_EK" | grep "No EK"
}

part2(){

    need_EK
    if [[ "$?" == "0" ]]; then
        echo "Creating a new EK"
        tpm_createek
    fi

    echo "***************************************************************"
    echo "***************************************************************"
    echo "About to take ownership. Using the well-known password for the SRK."
    echo "This command will take a few seconds, please be patient."
    echo "***************************************************************"
    echo "***************************************************************"

    echo "Enter a new owner password"
    OWN_RESULT=$(tpm_takeownership -z 2>&1)

    if [[ "$?" != "0" ]]; then
        echo "Command failed."
        echo "$OWN_RESULT" | grep "Internal software error"
        if [[ "$?" == 0 ]]; then
            echo "Internal Software Error: halting. Remove and re-apply power and try again."
            halt
        fi

    else
        echo "Congrats! Your TPM is now ready to use."
    fi
}

## main

print_tpm_status

if [[ $TPM_ACTIVE == "1" ]] &&
    [[ $TPM_ENABLED == "1" ]] &&
    [[ $TPM_OWNED == "0" ]]; then

    is_compliance_vector_loaded

    if [[ "$?" == 0 ]]; then
        part1
    else
        part2
    fi
else
    part1
fi
