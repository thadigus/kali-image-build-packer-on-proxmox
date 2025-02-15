#!/bin/bash
export PKR_VAR_build_passwd_local=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 13; echo);
/usr/bin/packer init -var-file=./kali-packer-install-sensitive.auto.pkrvars.hcl .
/usr/bin/packer validate -var-file=./kali-packer-install-sensitive.auto.pkrvars.hcl .
/usr/bin/packer build -force -var-file=./kali-packer-install-sensitive.auto.pkrvars.hcl .
