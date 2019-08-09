
# Kubernetes Cluster on Hyper-V
# ---------------------------------
# Practice real Kubernetes configurations on a local multi-node cluster.
# Tested on: PowerShell 5.1 on Windows 10 Pro 1903, guest images Ubuntu 18.04 and 19.04.
# Note: DHCP/public-net not tested yet.

# PREPARATION
# 1. copy this script to your working directory, VMs/images will be stored to ./tmp
#
#    cd your-vm-work-dir
#    invoke-webrequest https://raw.githubusercontent.com/youurayy/k8s-hyperv/master/hyper-v.ps1 -usebasicparsing -outfile k8s-hyperv.ps1
#    -or-
#    git clone git@github.com:youurayy/k8s-hyperv.git
#    cd k8s-hyperv
#
# 2. uninstall Docker for Windows (if you plan to manage the k8s from your localhost)
#
# 3. choco install kubernetes-cli kubernetes-helm qemu-img
#
# 4. if you have cygwin: cyg-get mkisofs
#    (if you have cygwin but not cyg-get: choco install cyg-get)
$mkisofs = 'C:\tools\cygwin\bin\genisoimage.exe'
#
# 4. otherwise: `choco install cdrtfe`, and:
#
#    $cdrtfe = 'C:\Program Files (x86)\cdrtfe\tools'
#    new-item -itemtype symboliclink -path "$cdrtfe\cdrtools" -name "cygwin1.dll" -value "$cdrtfe\cygwin\cygwin1.dll"
#    $mkisofs = "$cdrtfe\cdrtools\mkisofs.exe"

# USAGE
# 1. load this script in (Admin) PowerShell ISE, and review/edit it (---> see bottom of this file "START HERE")
#
# 2. exec in the ISE console: Set-ExecutionPolicy RemoteSigned  # click [Only Next]
#
# 3. run the script (F5), it will download and prepare the selected image
#
# 4. create public or private network
#
# 5. create the machines
#
# 6. setup kubernetes
#    master:# sudo kubeadm init
#    workers:# sudo kubeadm join .....
#    host:# scp ubuntu@master:/etc/kubernetes/admin.conf ~/.kube/config
#    host:# kubectl ...
#
# 7. use k8s
#
# 8. use the delete-* functions to delete the VMs and the network when not needed anymore

# NOTES:
# - if you change the code, hit "Run (F5)" in the PowerShell ISE to save & reload
# - your ssh auth key is taken from your $HOME\.ssh\id_rsa.pub -- edit below if necessary

# NOTE: Default CIDRs to avoid in host networking:
# - Calico (192.168.0.0/16<->192.168.255.255)
# - Weave Net (10.32.0.0/12<->10.47.255.255)
# - Flannel (10.244.0.0/16<->10.244.255.255)
#
# ... so we default to 10.10.0.0/24<->10.10.0.255 for convenience


# switch to the script directory
cd $PSScriptRoot | out-null

# stop on any error
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'

# create ./tmp in the current directory
$tmp = 'tmp'
if (!(test-path $tmp)) {mkdir $tmp}




# note: network configs version 1 an 2 didn't work
function get-metadata($vmname, $cblock, $ip) {
if(!$cblock) {
return @"
instance-id: id-$($vmname)
local-hostname: $($vmname)

"@
} else {
return @"
instance-id: id-$vmname
network-interfaces: |
  iface eth0 inet static
  address $($cblock).$($ip)
  network $($cblock).0
  netmask 255.255.255.0
  broadcast $($cblock).255
  gateway $($cblock).1
local-hostname: $vmname

"@
}
}

# note: resolv.conf hard-set is a workaround for intial setup
function get-userdata($vmname) {
return @"
#cloud-config

mounts:
  - [ swap ]

groups:
  - docker

users:
  - name: $user
    ssh_authorized_keys:
      - $(cat $HOME\.ssh\id_rsa.pub)
    sudo: [ 'ALL=(ALL) NOPASSWD:ALL' ]
    groups: [ sudo, docker ]
    shell: /bin/bash

write_files:
  - path: /etc/resolv.conf
    content: |
      nameserver 8.8.4.4
      nameserver 8.8.8.8
  - path: /etc/systemd/resolved.conf
    content: |
      [Resolve]
      DNS=8.8.4.4
      FallbackDNS=8.8.8.8
  - path: /etc/modules-load.d/bridge.conf
    content: |
      br_netfilter
  - path: /etc/sysctl.d/bridge.conf
    content: |
      net.bridge.bridge-nf-call-ip6tables = 1
      net.bridge.bridge-nf-call-iptables = 1
      net.bridge.bridge-nf-call-arptables = 1

apt:
  sources:
    kubernetes:
      source: "deb http://apt.kubernetes.io/ kubernetes-xenial main"
      keyserver: "hkp://keyserver.ubuntu.com:80"
      keyid: BA07F4FB
      file: kubernetes.list

package_upgrade: true

packages:
  - linux-tools-virtual
  - linux-cloud-tools-virtual
  - docker.io
  - kubelet
  - kubectl
  - kubeadm

runcmd:
  # https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1766857
  - mkdir -p /usr/libexec/hypervkvpd && ln -s /usr/sbin/hv_get_dns_info /usr/sbin/hv_get_dhcp_info /usr/libexec/hypervkvpd
  - systemctl enable docker
  - systemctl enable kubelet

power_state:
  timeout: 10
  mode: poweroff

"@
}


# write_files:
#   - path: /etc/apt/preferences.d/docker-pin
#     content: |
#       Package: *
#       Pin: origin download.docker.com
#       Pin-Priority: 600
# apt:
#   sources:
#     docker.list:
#       arches: amd64
#       source: "deb https://download.docker.com/linux/ubuntu bionic stable"
#       keyserver: "hkp://keyserver.ubuntu.com:80"
#       keyid: 0EBFCD88
# packages:
#  - docker-ce
#  - docker-ce-cli
#  - containerd.io


function create-public-net($switch, $adapter) {
  new-vmswitch -name $switch -allowmanagementos $true -netadaptername $adapter
}

function create-private-net($natnet, $switch, $cblock) {
  new-vmswitch -name $switch -switchtype internal
  new-netipaddress -ipaddress "$($cblock).1" -prefixlength 24 -interfacealias "vEthernet ($switch)"
  new-netnat -name $natnet -internalipinterfaceaddressprefix "$($cblock).0/24"
}

function create-machine($switch, $vmname, $cpus, $mem, $hdd, $vhdxtmpl, $cblock, $ip, $mac) {
  $vmdir = "$tmp\$vmname"
  $vhdx = "$tmp\$vmname\$vmname.vhdx"
  new-item -itemtype directory -force -path $vmdir | out-null
  copy-item -path $vhdxtmpl -destination $vhdx -force
  resize-vhd -path $vhdx -sizebytes $hdd

  set-content $tmp\$vmname\meta-data ([byte[]][char[]] "$(get-metadata -vmname $vmname -cblock $cblock -ip $ip)") -encoding byte
  set-content $tmp\$vmname\user-data ([byte[]][char[]] "$(get-userdata -vmname $vmname)") -encoding byte

  & $mkisofs -volid cidata -joliet -rock -input-charset utf8 -quiet -o $tmp/$vmname/$vmname.iso $tmp/$vmname/user-data $tmp/$vmname/meta-data

  $vm = new-vm -name $vmname -memorystartupbytes $mem -generation 2 -switchname $switch -vhdpath $vhdx -path $tmp
  set-vmfirmware -vm $vm -enablesecureboot off
  set-vmprocessor -vm $vm -count $cpus
  add-vmdvddrive -vmname $vmname -path $tmp/$vmname/$vmname.iso

  if(!$mac) { $mac = create-mac-address }
  get-vmnetworkadapter -vm $vm | set-vmnetworkadapter -staticmacaddress $mac

  set-vmcomport -vmname $vmname -number 2 -path \\.\pipe\dbg1

  start-vm -name $vmname
}

function delete-machine($name) {
  stop-vm $name -turnoff -confirm:$false -ErrorAction SilentlyContinue
  remove-vm $name -force  -ErrorAction SilentlyContinue
  remove-item -recurse -force $tmp/$name
}

function delete-public-net($switch) {
  remove-vmswitch -name $switch -confirm $false
}

function delete-private-net($switch, $natnet) {
  remove-vmswitch -name $switch -confirm $false
  remove-netnat -name $natnet -confirm $false
}

function create-mac-address() {
  return "02$((1..5 | %{ '{0:X2}' -f (Get-Random -Max 256) }) -join '')"
}

function basename($path) {
  return $path.substring(0, $path.lastindexof('.'))
}

function prepare-vhdx-tmpl($url, $srcimg, $vhdxtmpl) {
  if (!(test-path $srcimg)) {
    invoke-webrequest $url -usebasicparsing -outfile $srcimg
  }
  if (!(test-path $vhdxtmpl)) {
    qemu-img.exe convert $srcimg -O vhdx -o subformat=dynamic $vhdxtmpl
  }
}

function update-etc-hosts($cblock) {
@"

$($cblock).10 master
$($cblock).11 node1
$($cblock).12 node2
$($cblock).13 node3
$($cblock).14 node4
$($cblock).15 node5
$($cblock).16 node6
$($cblock).17 node7
$($cblock).18 node8
$($cblock).19 node9


"@ | out-file -encoding utf8 -append "$env:windir\System32\drivers\etc\hosts"

}

function create-nodes($num, $cblock) {
  1..$num | %{
    echo creating node $_
    create-machine -switch 'switch' -vmname "node$_" -cpus 4 -mem 4GB -hdd 40GB -vhdxtmpl $vhdxtmpl -cblock $cblock -ip $(10+$_)
  }
}

function delete-nodes($num) {
  1..$num | %{
    echo deleting node $_
    delete-machine -name "node$_"
  }
}


# ****************************************************************
#
#                          START HERE
#
# ****************************************************************


# EDIT HERE 1.
# which user name to create on the VMs
# defaults to current user name (i.e. you)
$user = $env:USERNAME



# EDIT HERE 2.
# download and prepare the disk template
# (caching is used; will only download & process new files)
# NOTE: the package config above targets ubuntu distros, you will need to update it for other distros

# kernel 4.15
# https://wiki.ubuntu.com/BionicBeaver/ReleaseNotes
# $imageurl = 'http://cloud-images.ubuntu.com/releases/server/18.04/release/ubuntu-18.04-server-cloudimg-amd64.img'

# kernel 5.0
# https://wiki.ubuntu.com/DiscoDingo/ReleaseNotes
$imageurl = 'http://cloud-images.ubuntu.com/releases/server/19.04/release/ubuntu-19.04-server-cloudimg-amd64.img'



$srcimg = "$tmp\$(split-path $imageurl -leaf)"
$vhdxtmpl = "$(basename $srcimg).vhdx"
#write-host "`r`n Using user: $user `r`n  and image: $vhdxtmpl `r`n"

$cidr = '10.10.0'

# EDITR HERE 3.
# copy and paste the following commands as necessary (easier when this script is loaded into the "PowerShell ISE")
# choose either public or private net
#      (public: VMs will be accessible on your Wi-Fi; will get IPs from DHCP)
#      (private: VMs will need port fwd to be accessible from other than your local machine; will need IP assign)

$macs = @(
  '0225EA2C9AE7', # master
  '02A254C4612F', # node1
  '02FBB5136210', # node2
  '02FE66735ED6', # node3
  '021349558DC7', # node4
  '0288F589DCC3', # node5
  '02EF3D3E1283', # node6
  '0225849ADCBB', # node7
  '02E0B0026505', # node8
  '02069FBFC2B0', # node9
  '02F7E0C904D0' # node10
)

if($args.count -eq 0) {
  $args = @( 'help' )
}

echo ''

$nettype = 'private' # private/public
$switch = 'switch' # private or public switch name
$natnet = 'natnet' # private net nat net name
$adapter = 'Wi-Fi' # public net adapter name

$cpus = 4
$ram = 4GB
$hdd = 40GB

switch -regex ($args) {
  # set-executionpolicy remotesigned -scope process
  help {
    echo "help"
  }
  config {
    echo " user:  $user"
    echo " image: $vhdxtmpl"
    echo " cidr:  $cidr.0/24"
  }
  install {
  }
  info {
    # show nodes info
  }
  image {
    prepare-vhdx-tmpl -url $imageurl -srcimg $srcimg -vhdxtmpl $vhdxtmpl
  }
  net {
    switch ($nettype) {
      'private' { create-private-net -natnet $natnet -switch $switch -cblock $cidr }
      'public' { create-public-net -switch $switch -adapter $adapter }
    }
  }
  hosts {
    # optionally, update /etc/hosts so you can e.g. `ssh user@master`
    update-etc-hosts -cblock $cidr
  }
  macs {
    $cnt = 10
    0..$cnt | %{
      $comment = switch ($_) {0 {'master'} default {"node$_"}}
      $comma = if($_ -eq $cnt) { '' } else { ',' }
      echo "  '$(create-mac-address)'$comma # $comment"
    }
  }
  master {
    # use -cblock $null for DHCP
    create-machine -switch $switch -vmname 'master' -cpus $cpus -mem $ram -hdd $hdd `
      -vhdxtmpl $vhdxtmpl -cblock $cidr -ip '10' -mac $macs[0]
  }
  # node1, node2, ...
  '(^node(?<number>\d+)$)' {
    # use -cblock $null for DHCP
    $num = [int]$matches.number
    $name = "node$($num)"
    create-machine -switch $switch -vmname $name -cpus $cpus -mem $ram -hdd $hdd `
      -vhdxtmpl $vhdxtmpl -cblock $cidr -ip "$($num + 10)" -mac $macs[$num]
  }
  save {
    #get-vm
    #checkpoint-vm
  }
  stop {
  }
  delete {
    get-vm
    #delete-machine -name 'node2'
    #delete-machine -name 'master'
  }
  delete-net {
    switch ($nettype) {
      'private' { delete-private-net -switch $switch -natnet $natnet }
      'public' { delete-public-net -switch $switch }
    }
  }
}

echo ''

# License: https://www.apache.org/licenses/LICENSE-2.0

