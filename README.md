# cryptocape-init

A collection of scripts to initialize the chips on the
CryptoCape. Currently, the TPM is the focus.

## To run

    git clone https://github.com/cryptotronix/cryptocape-init.git
    cd cryptocape-init
    ./tpm_clear_own.sh

The BBB will halt. Once power is re-applied, log back in and run the
script again to complete the procedure.

## Notes

This script will halt your BBB at least once, maybe more if it detects
an error condition. It will clear the TPM, which has the side effect
of removing the
[compliance vectors](http://cryptotronix.com/2014/08/28/compliance_mode/). It
will, once rebooted, create an Endorsement Key (EK) and take ownership.
