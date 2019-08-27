### Project has moved to: https://github.com/youurayy/hyperctl

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

# display short synopsis for the available commands
.\hyperv.ps1 help
'
  Usage: .\hyperv.ps1 command+

  Commands:

     install - install basic chocolatey packages
      config - show script config vars
       print - print etc/hosts, network interfaces and mac addresses
         net - install private or public host network
       hosts - append private network node names to etc/hosts
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

# print relevant configuration - etc/hosts, mac addresses, network interfaces
.\hyperv.ps1 print

# create a private network for the VMs, as set by the `cidr` variable
.\hyperv.ps1 net

# appends IP/hostname pairs to the /etc/hosts.
# (the same hosts entries will also be installed into every node)
.\hyperv.ps1 hosts

# download, prepare and cache the VM image templates
.\hyperv.ps1 image

# create/launch the nodes
.\hyperv.ps1 master
.\hyperv.ps1 node1
.\hyperv.ps1 nodeN...
# ---- or -----
.\hyperv.ps1 master node1 node2 nodeN...

# ssh to the nodes if necessary (e.g. for manual k8s init)
# by default, your `.ssh/id_rsa.pub` key was copied into the VMs' ~/.ssh/authorized_keys
# uses your host username (which is the default), e.g.:
ssh master
ssh node1
ssh node2
...

# perform automated k8s init (will wait for VMs to finish init first)
# (this will checkpoint the nodes just before `kubeadm init`)
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

# checkpoint the VMs
.\hyperv.ps1 save

# restore the VMs from the lastest snapshot
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
# C:\WINDOWS\System32\vmcompute.exe -> Edit-> Code flow guard (CFG) -> uncheck Override system settings -> # net stop vmcompute -> net start vmcompute

```

#### License: https://www.apache.org/licenses/LICENSE-2.0
