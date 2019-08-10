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
curl https://raw.githubusercontent.com/youurayy/k8s-hyperv/master/hyperv.sh -O -
# enable script run permission
set-executionpolicy remotesigned

# ---- or -----

# INSTALL B) clone the repo
git clone git@github.com:youurayy/k8s-hyperv.git
cd k8s-hyperv
# enable script run permission
.\unlock.bat

# examine and customize the script, e.g.:
code hyperv.sh

# display help about provided commands
.\hyperv.sh help

# performs `choco install kubernetes-cli kubernetes-helm qemu-img`.
# you may perform these manually / selectively instead.
.\hyperv.sh install

# display configured variables
.\hyperv.sh config

# download, prepare and cache the VM image templates
.\hyperv.sh image

# TODO
# while setting a new CIDR (by default 10.10.0.0/24) to avoid colliding with
# default CIDRs of Kubernetes Pod networking plugins (Calico etc.).
# (you should examine the vmnet.plist first to see if other apps are using it)
# note: default CIDRs to avoid:
# - Calico (192.168.0.0/16<->192.168.255.255)
# - Weave Net (10.32.0.0/12<->10.47.255.255)
# - Flannel (10.244.0.0/16<->10.244.255.255)
.\hyperv.sh net

#
.\hyperv.sh hosts

#
.\hyperv.sh macs

# launch the nodes
.\hyperv.sh master
.\hyperv.sh node1
.\hyperv.sh nodeN...
# ---- or -----
.\hyperv.sh master node1 node2 nodeN...

# ssh to the nodes and install basic Kubernetes cluster here.
# IPs can be found in `etc/hosts`
# by default, your `.ssh/id_rsa.pub` key was copied into the VMs' ~/.ssh/authorized_keys
# (note: this works only after `.\hyperv.sh hosts`, otherwise use IP addresses)
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
.\hyperv.sh info # TODO

NAME    PID    %CPU  %MEM  RSS   STARTED  TIME     DISK  SPARSE  STATUS
master  36399  0.4   2.1   341M  3:51AM   0:26.30  40G   3.1G    RUNNING
node1   36418  0.3   2.1   341M  3:51AM   0:25.59  40G   3.1G    RUNNING
node2   37799  0.4   2.0   333M  3:56AM   0:16.78  40G   3.1G    RUNNING

# (optional) checkpoint the VMs at any time
.\hyperv.sh save # TODO

# stop all nodes
.\hyperv.sh stop # TODO

# delete all nodes' data (will not delete image templates)
.\hyperv.sh delete # TODO

# delete the network
.\hyperv.sh delete-net

```

#### License: https://www.apache.org/licenses/LICENSE-2.0
