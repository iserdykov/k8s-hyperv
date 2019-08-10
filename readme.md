# Kubernetes Cluster on Hyper-V

Practice real Kubernetes configurations on a local multi-node cluster.

Tested on: PowerShell 5.1 on Windows 10 Pro 1903, guest images Ubuntu 18.04 and 19.04.

## Changelog

Current state: pre-release; TODO: k8s helm setup

## Example usage:

```powershell

# open PowerShell (Admin) prompt
cd workdir

# INSTALL A) download the script
curl https://raw.githubusercontent.com/youurayy/k8s-hyperv/master/hyperv.ps1 -O -
# enable script run permission
set-executionpolicy remotesigned

# ---- or -----

# INSTALL B) clone the repo
git clone git@github.com:youurayy/k8s-hyperv.git
cd k8s-hyperv
# enable script run permission
.\unlock.bat

# examine and customize the script, e.g.:
code hyperv.ps1

# display help about provided commands
.\hyperv.ps1 help

# performs `choco install kubernetes-cli kubernetes-helm qemu-img`.
# you may perform these manually / selectively instead.
.\hyperv.ps1 install

# display configured variables (edit the script to change them)
.\hyperv.ps1 config

# TODO example

# download, prepare and cache the VM image templates
.\hyperv.ps1 image

# create a network switch - depending on the config setting,
# it will be either private or public network:
# - public: VMs will be accessible on your Wi-Fi; will get IPs from DHCP
# - private: VMs will need port fwd to be accessible from other than your local machine; will need IP assign

# the default CIDR (10.10.0.0/24) is configured to avoid colliding with the
# default CIDRs of Kubernetes Pod networking plugins (Calico etc.).
# default CIDRs to avoid:
# - Calico (192.168.0.0/16<->192.168.255.255)
# - Weave Net (10.32.0.0/12<->10.47.255.255)
# - Flannel (10.244.0.0/16<->10.244.255.255)
.\hyperv.ps1 net

#
.\hyperv.ps1 hosts

#
.\hyperv.ps1 macs

# launch the nodes
.\hyperv.ps1 master
.\hyperv.ps1 node1
.\hyperv.ps1 nodeN...
# ---- or -----
.\hyperv.ps1 master node1 node2 nodeN...

# ssh to the nodes and install basic Kubernetes cluster here.
# IPs can be found in `etc/hosts`
# by default, your `.ssh/id_rsa.pub` key was copied into the VMs' ~/.ssh/authorized_keys
# (note: this works only after `.\hyperv.ps1 hosts`, otherwise use IP addresses)
# use your host username (which is default), e.g.:
ssh master
ssh node1
ssh node2
...

# note: the initial cloud-config is set to power-down the nodes upon finish.
# use the 'info' command to see when the nodes finished initializing, and
# then run them again to setup k8s.
# you can disable this behavior by commenting out the powerdown in the cloud-init config.

# show info about existing VMs (size, run state)
.\hyperv.ps1 info # TODO

NAME    PID    %CPU  %MEM  RSS   STARTED  TIME     DISK  SPARSE  STATUS
master  36399  0.4   2.1   341M  3:51AM   0:26.30  40G   3.1G    RUNNING
node1   36418  0.3   2.1   341M  3:51AM   0:25.59  40G   3.1G    RUNNING
node2   37799  0.4   2.0   333M  3:56AM   0:16.78  40G   3.1G    RUNNING

# (optional) checkpoint the VMs at any time
.\hyperv.ps1 save # TODO

# stop all nodes
.\hyperv.ps1 stop # TODO

# delete all nodes' data (will not delete image templates)
.\hyperv.ps1 delete # TODO

# delete the network
.\hyperv.ps1 delete-net

```

#### License: https://www.apache.org/licenses/LICENSE-2.0
