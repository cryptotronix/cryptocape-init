#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "You must be root to run this script"
    exit 1
fi

crypto_cape_attached_p(){
    dmesg | grep "dtbo 'BB-BONE-CRYPTO-00A0.dtbo' loaded"
}

tpm_active(){
    TPM_ACTIVE=$(cat /sys/class/misc/tpm0/device/active)
}

tpm_enabled(){
    TPM_ENABLED=$(cat /sys/class/misc/tpm0/device/enabled)
}

tpm_owned(){
    TPM_OWNED=$(cat /sys/class/misc/tpm0/device/owned)
}

if [[ crypto_cape_attached_p -ne 0 ]]; then
    echo "You must boot with the CryptoCape attached"
    exit 1
fi

part1(){
    apt-get install -y git trousers tpm-tools libtspi1 libtspi-dev build-essential

    gcc tpm_assert/tpm_assertpp.c -o tpm_assertpp

    echo Killing tcsd
    pkill tcsd

    echo Setting PP
    ./tpm_assertpp

    if [[ "$?" != 0 ]]; then
        echo "Setting PP failed. We can't continue."
        exit 1
    fi

    echo Restarting tcsd
    tcsd

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
    cat /sys/class/misc/tpm0/device/pubek | grep "^$C_PUBEK_START"
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
