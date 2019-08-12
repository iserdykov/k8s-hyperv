# Kubernetes Cluster on Hyper-V

Practice real Kubernetes configurations on a local multi-node cluster.

Tested on: PowerShell 5.1 on Windows 10 Pro 1903, guest images Ubuntu 18.04 and 19.04.

<sub>For Hyperkit on macOS see [here](https://github.com/youurayy/k8s-hyperkit)</sub>

## Changelog

Current state: pre-release; TODO: k8s helm setup

## Example usage:

```powershell

# note: admin access is necessary for access to Windows Hyper-V framework, and etc/hosts config

# open PowerShell (Admin) prompt
cd $HOME\your-workdir

# INSTALL A) download the script
curl https://raw.githubusercontent.com/youurayy/k8s-hyperv/master/hyperv.ps1 -outfile hyperv.ps1
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

# display short synopsis for the available commands
.\hyperv.ps1 help

# performs `choco install kubernetes-cli kubernetes-helm qemu-img`.
# you may instead perform these manually / selectively instead.
.\hyperv.ps1 install

# display configured variables (edit the script to change them)
.\hyperv.ps1 config
'
  workdir: .\tmp
     user: name
  sshpath: C:\Users\name\.ssh\id_rsa.pub
 imageurl: http://cloud-images.ubuntu.com/releases/server/19.04/release/ubuntu-19.04-server-cloudimg-amd64.img
 vhdxtmpl: tmp\ubuntu-19.04-server-cloudimg-amd64.vhdx
     cidr: 10.10.0.0/24
   switch: switch
  nettype: private
   natnet: natnet
     cpus: 4
      ram: 4GB
      hdd: 40GB
'

# print the current etc/hosts file
.\hyperv.ps1 print

# create a network switch - depending on the config setting (see `.\hyperv.ps1 config`),
# it will be either private or public network:
# - private: VMs will be on its own NAT-ed network (will need port fwd for access from outside); IPs are pre-set
# - public: VMs will be accessible on your LAN (default: `Wi-Fi` adapter); will get IPs from DHCP
#
# the default CIDR (10.10.0.0/24) is configured to avoid colliding with the
# default CIDRs of Kubernetes Pod networking plugins (Calico etc.).
# default CIDRs to avoid:
# - Calico (192.168.0.0/16<->192.168.255.255)
# - Weave Net (10.32.0.0/12<->10.47.255.255)
# - Flannel (10.244.0.0/16<->10.244.255.255)
.\hyperv.ps1 net

# update etc/hosts so you can access the VMs by name e.g. `ssh master`
# (the VMs are created with your username, so no need for `user@`)
# if you want to repeat this action, you'll first need to remove the previous
# entries from the etc/hosts file manually
.\hyperv.ps1 hosts

# generate a new set of MAC addresses in a format directly insertable into the `hyperv.ps1` script.
# the script already contains a default set of MAC addresses.
.\hyperv.ps1 macs

# download, prepare and cache the VM image templates
.\hyperv.ps1 image

# launch the nodes (will create the node if it doesn't exist yet)
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
.\hyperv.ps1 info
'
Name   State   CPUUsage(%) MemoryAssigned(M) Uptime             Status             Version
----   -----   ----------- ----------------- ------             ------             -------
master Running 0           1370              4.00:04:10.4700000 Operating normally 9.0
'

# setup kubernetes
#    master:# sudo kubeadm init
#    nodeN:# sudo kubeadm join .....
#    host:# scp ubuntu@master:/etc/kubernetes/admin.conf ~/.kube/config
#    host:# kubectl ...

# (optional) checkpoint the VMs
.\hyperv.ps1 save

# (optional) restore the VMs from the lastest snapshot
.\hyperv.ps1 restore

# stop all nodes
.\hyperv.ps1 stop

# start all nodes
.\hyperv.ps1 start

# delete all nodes' data (will not delete image templates)
.\hyperv.ps1 delete

# delete the network
.\hyperv.ps1 delnet

```

#### License: https://www.apache.org/licenses/LICENSE-2.0
