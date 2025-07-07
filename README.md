# Kali Base Image Build with Hashicorp Packer

This was my attempt at automating Kali builds in Proxmox with Hashicorp Packer. Most of the config is done with the sensitive variables file which will allow you to provision a user and SSH key. Ansible is used for post-install customizations and I'd really recommend that you build your own playbook to make Kali work the way you'd like it.

Start out with installing Packer on your machine and editing the sensitive vars file. Make sure the version of Kali you'd like to use is installed at `local:iso/kali-linux-2024.4-installer-amd64.iso` on the Proxmox target since downloading the ISO each time is not super fun. This is mainly intended for a home lab environment so take everything with a grain of salt and feel free to tinker. If you have any issues please feel free to open one [at the issues tab](https://gitlab.com/thadigus/kali-image-build-packer-on-proxmox/-/issues)!

It's important to know that Kali will not let you install without a password so my script will generate a random, very long, password for the user account and then the preseed file will use that password for the install. The password is then passed into Ansible. This means that you will likely want to change the password when you're done with Ansible so you can access the account. Be sure to set the password you'd like using the Ansible playbook, or you can install an SSH key. 

### Sample Preseed File

This is the basic Preseed file if you just need a general reference for your own project. I found it somewhat hard to track this down and get it working so here's what worked for me. Be sure to note the Packer variables noted with `${variablename}` in the file. Those variables are filled by Packer at runtime as a part of the build process. This way it's fairly modular.

```preseed
### Kali Linux Preseed Configuration
# This is the default preseed file to install a Kali Linux instance and setup for Ansible automated management.
# Heavy use of the following file: https://gitlab.com/kalilinux/recipes/kali-preseed-examples/-/blob/main/kali-linux-rolling-preseed.cfg?ref_type=heads

d-i debian-installer/locale string en_US.UTF-8
d-i console-keymaps-at/keymap select us
d-i mirror/country string United States
d-i mirror/http/hostname string http.kali.org
d-i mirror/http/directory string /kali
d-i keyboard-configuration/xkb-keymap select us
d-i mirror/http/proxy string
d-i mirror/suite string kali-rolling
d-i mirror/codename string kali-rolling

d-i clock-setup/utc boolean true
d-i time/zone string America/Indiana/Indianapolis

# Disable security, volatile and backports
d-i apt-setup/services-select multiselect 

# Enable contrib and non-free
d-i apt-setup/non-free boolean true
d-i apt-setup/contrib boolean true

# Disable source repositories too
d-i apt-setup/enable-source-repositories boolean false

# Partitioning
d-i partman-auto/method string regular
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-auto/disk string /dev/sda
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-partitioning/confirm_write_new_label boolean true

# Disable CDROM entries after install
d-i apt-setup/disable-cdrom-entries boolean true

# Upgrade installed packages and install OpenSSH for Ansible
d-i pkgsel/upgrade select full-upgrade
d-i pkgsel/include string openssh-server

# Change default hostname
d-i netcfg/get_hostname string kali
d-i netcfg/get_domain string turnerservices.cloud
d-i netcfg/choose_interface select auto
d-i netcfg/dhcp_timeout string 60
d-i hw-detect/load_firmware boolean false

# Account Setup
d-i passwd/root-login boolean false
d-i passwd/make-user boolean true
d-i passwd/user-fullname string Turner Ansible Service Account
d-i passwd/username string ${ssh_user}
d-i passwd/user-password password ${build_passwd} 
d-i passwd/user-password-again password ${build_passwd}

d-i apt-setup/use_mirror boolean true
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean false
d-i grub-installer/bootdev string /dev/sda
d-i finish-install/reboot_in_progress note

# Disable popularity-contest
popularity-contest popularity-contest/participate boolean false

# Late Command to Install Additional Software and Configure Network
d-i preseed/late_command string in-target systemctl enable ssh
```

## Packer Configuration

Luckily Packer configures itself for the most part. Be sure to follow Packer documentation for installation and troubleshooting of the first `init` and `verify` steps but most of this should be fairly straight forward. You can use the Packer Docker image to get started but I've had limited compatability with Ansible.

### Sample Secure Vars

Ensure that your secure vars are configured with at least the following lines at `./kali-packer-install-sensitive.auto.pkrvars.hcl`. These are the variables that have been set aside to make sure that this works for your given Proxmox environment. The Ansible user is used for post-install steps and for any other customizatoin you'd like to do. Be sure to add your own tasks/roles to `kali-packer-config.yml` for your own custom template.

```hcl
/*
    DESCRIPTION:
    Build account variables used for all builds.
    - Variables are passed to and used by guest operating system configuration files (e.g., ks.cfg, autounattend.xml).
    - Variables are passed to and used by configuration scripts.
*/

// Default Account Credentials
ssh_user                 = "ANSIBLE_SERVICE_ACCOUNT_USER" //SSH Username for Preseed/Kickstart to configure so Ansible can get into provision afterwards
build_key                = "ssh-rsa AAAAB3NzaC1yc....x/vq1OaLAz6pYk8=" // Actual public key you'd like installed for the Ansible user to be allowed in.

/*
    DESCRIPTION:
    Proxmox WebUI variables used for Linux builds. 
    - Variables are use by the source blocks.
*/

//Proxmox Credentials
proxmox_host             = "10.x.x.x"
proxmox_node             = "PROXMOXNODE"
proxmox_user             = "root@pam!APIKEY"
proxmox_apikey           = "XXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX"

// VM Config
vlan_tag                 = ""

// Optional Override for path to Ansible playbook (assumes you're starting at top level directory on your Git repo)
// ansible_provisioner_playbook_path = ""
```

### Script for Packer Build processes

I've tried my best to make this a super straight forward build process. This script can be ran once you've installed Packer, setup the variables file, and make sure that the ISO is present in the right location. Maybe in the future I'll augment this with an Ansible playbook and a Docker container with all of the dependencies already installed.

```shell
kali-packer-build.sh
```
