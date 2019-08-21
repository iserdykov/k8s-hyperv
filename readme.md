# Kubernetes Cluster on Hyper-V

Practice real Kubernetes configurations on a local multi-node cluster.

Tested on: PowerShell 5.1 on Windows 10 Pro 1903, guest images Centos 1907 and Ubuntu 18.04.

<sub>For Hyperkit on macOS see [here](https://github.com/youurayy/k8s-hyperkit).</sub>

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
'
  Usage: .\hyperv.ps1 command+

  Commands:

     install - install basic homebrew packages
      config - show script config vars
       print - print etc/hosts, network interfaces and mac addresses
         net - install private or public host network
       hosts - append private network node names to etc/hosts
        macs - generate new set of MAC addresses
       image - download the VM image
      master - create and launch master node
       nodeN - create and launch worker node (node1, node2, ...)
        info - display info about nodes
        init - initialize k8s and setup host kubectl
      reboot - soft-reboot the nodes
    shutdown - soft-shutdown the nodes
        save - snapshot the VMs
     restore - restore VMs from latest snapshots
        stop - stop the VMs
       start - start the VMs
      delete - stop VMs and delete the VM files
      delnet - delete the network
'

# performs `choco install 7zip.commandline qemu-img kubernetes-cli kubernetes-helm`.
# you may instead perform these manually / selectively instead.
# note: 7zip is needed to extract .xz archives
# note: qemu-img is needed convert images to vhdx
.\hyperv.ps1 install

# display configured variables (edit the script to change them)
.\hyperv.ps1 config
'
    config: bionic
    distro: ubuntu
   workdir: .\tmp
 guestuser: name
   sshpath: C:\Users\name\.ssh\id_rsa.pub
  imageurl: https://cloud-images.ubuntu.com/releases/server/18.04/release/ubuntu-18.04-server-cloudimg-amd64.img
  vhdxtmpl: .\tmp\ubuntu-18.04-server-cloudimg-amd64.vhdx
      cidr: 10.10.0.0/24
    switch: switch
   nettype: private
    natnet: natnet
      cpus: 4
       ram: 4GB
       hdd: 40GB
       cni: flannel
    cninet: 10.244.0.0/16
   cniyaml: https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
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

# ssh to the nodes if necessary (e.g. for manual k8s init)
# IPs can be found in `etc/hosts`
# by default, your `.ssh/id_rsa.pub` key was copied into the VMs' ~/.ssh/authorized_keys
# (note: this works only after `.\hyperv.ps1 hosts`, otherwise use IP addresses)
# use your host username (which is the default), e.g.:
ssh master
ssh node1
ssh node2
...

# perform automated k8s init (will wait for vm to finish init)
# note: this will checkpoint the nodes just before `kubeadm init`
# note: this requires your etc/hosts updated
.\hyperv.ps1 init

# after init, you can do e.g.:
hyperctl get pods --all-namespaces
'
NAMESPACE     NAME                             READY   STATUS    RESTARTS   AGE
kube-system   coredns-5c98db65d4-b92p9         1/1     Running   1          5m31s
kube-system   coredns-5c98db65d4-dvxvr         1/1     Running   1          5m31s
kube-system   etcd-master                      1/1     Running   1          4m36s
kube-system   kube-apiserver-master            1/1     Running   1          4m47s
kube-system   kube-controller-manager-master   1/1     Running   1          4m46s
kube-system   kube-flannel-ds-amd64-6kj9p      1/1     Running   1          5m32s
kube-system   kube-flannel-ds-amd64-r87qw      1/1     Running   1          5m7s
kube-system   kube-flannel-ds-amd64-wdmxs      1/1     Running   1          4m43s
kube-system   kube-proxy-2p2db                 1/1     Running   1          5m32s
kube-system   kube-proxy-fg8k2                 1/1     Running   1          5m7s
kube-system   kube-proxy-rtjqv                 1/1     Running   1          4m43s
kube-system   kube-scheduler-master            1/1     Running   1          4m38s
'

# reboot the nodes
.\hyperv.ps1 reboot

# show info about existing VMs (size, run state)
.\hyperv.ps1 info
'
Name   State   CPUUsage(%) MemoryAssigned(M) Uptime           Status             Version
----   -----   ----------- ----------------- ------           ------             -------
master Running 3           5908              00:02:25.5770000 Operating normally 9.0
node1  Running 8           4096              00:02:22.7680000 Operating normally 9.0
node2  Running 2           4096              00:02:20.1000000 Operating normally 9.0
'

# (optional) checkpoint the VMs
.\hyperv.ps1 save

# (optional) restore the VMs from the lastest snapshot
.\hyperv.ps1 restore

# shutdown all nodes thru ssh
.\hyperv.ps1 shutdown

# start all nodes
.\hyperv.ps1 start

# stop all nodes thru hyper-v
.\hyperv.ps1 stop

# delete all nodes' data (will not delete image templates)
.\hyperv.ps1 delete

# delete the network
.\hyperv.ps1 delnet

# NOTE if Hyper-V stops working after a Windows update, do:
# Windows Security -> App & Browser control -> Exploit protection settings -> Program settings ->
# C:\WINDOWS\System32\vmcompute.exe -> Edit-> Code flow guard (CFG) -> uncheck Override system settings ->
# net stop vmcompute -> net start vmcompute

```

#### License: https://www.apache.org/licenses/LICENSE-2.0
