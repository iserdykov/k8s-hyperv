#!/usr/bin/env powershell
# SPDX-License-Identifier: Apache-2.0
# For usage overview, read the readme.md at https://github.com/youurayy/k8s-hyperv

# ---------------------------SETTINGS------------------------------------

$workdir = '.\tmp'
$guestuser = $env:USERNAME
$sshpath = "$HOME\.ssh\id_rsa.pub"
if (!(test-path $sshpath)) {
  write-host "`n please configure `$sshpath or place a pubkey at $sshpath `n"
  exit
}
$sshpub = get-content $sshpath -raw

$config = $(get-content -path .\.distro -ea silentlycontinue | out-string).trim()
if(!$config) {
  $config = 'centos'
}

switch ($config) {
  'bionic' {
    $distro = 'ubuntu'
    $generation = 2
    $version="18.04"
    $imagebase = "https://cloud-images.ubuntu.com/releases/server/$version/release"
    $sha256file = 'SHA256SUMS'
    $image = "ubuntu-$version-server-cloudimg-amd64.img"
    $archive = ""
  }
  'disco' {
    $distro = 'ubuntu'
    $generation = 2
    $version="19.04"
    $imagebase = "https://cloud-images.ubuntu.com/releases/server/$version/release"
    $sha256file = 'SHA256SUMS'
    $image = "ubuntu-$version-server-cloudimg-amd64.img"
    $archive = ""
  }
  'centos' {
    $distro = 'centos'
    $generation = 1
    $imagebase = "https://cloud.centos.org/centos/7/images"
    $sha256file = 'sha256sum.txt'
    $version = "1907"
    $image = "CentOS-7-x86_64-GenericCloud-$version.raw"
    $archive = ".tar.gz"
  }
}

$nettype = 'private' # private/public
$zwitch = 'switch' # private or public switch name
$natnet = 'natnet' # private net nat net name (privnet only)
$adapter = 'Wi-Fi' # public net adapter name (pubnet only)

$cpus = 4
$ram = '4GB'
$hdd = '40GB'

$cidr = switch ($nettype) {
  'private' { '10.10.0' }
  'public' { $null }
}

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

$cni = 'flannel'

switch ($cni) {
  'flannel' {
    $cniyaml = 'https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml'
    $cninet = '10.244.0.0/16'
  }
  'weave' {
    $cniyaml = 'https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d "\n")'
    $cninet = '10.32.0.0/12'
  }
  'calico' {
    $cniyaml = 'https://docs.projectcalico.org/v3.7/manifests/calico.yaml'
    $cninet = '192.168.0.0/16'
  }
}

$sshopts = @('-o LogLevel=ERROR', '-o StrictHostKeyChecking=no', '-o UserKnownHostsFile=/dev/null')

$dockercli = 'https://github.com/StefanScherer/docker-cli-builder/releases/download/19.03.1/docker.exe'

# ----------------------------------------------------------------------

$imageurl = "$imagebase/$image$archive"
$srcimg = "$workdir\$image"
$vhdxtmpl = "$workdir\$($image -replace '^(.+)\.[^.]+$', '$1').vhdx"


# switch to the script directory
cd $PSScriptRoot | out-null

# stop on any error
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'

$etchosts = "$env:windir\System32\drivers\etc\hosts"

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
  auto eth0
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

function get-userdata-shared($cblock) {
return @"
#cloud-config

mounts:
  - [ swap ]

groups:
  - docker

users:
  - name: $guestuser
    ssh_authorized_keys:
      - $($sshpub)
    sudo: [ 'ALL=(ALL) NOPASSWD:ALL' ]
    groups: [ sudo, docker ]
    shell: /bin/bash
    # lock_passwd: false # passwd won't work without this
    # passwd: '`$6`$rounds=4096`$byY3nxArmvpvOrpV`$2M4C8fh3ZXx10v91yzipFRng1EFXTRNDE3q9PvxiPc3kC7N/NHG8HiwAvhd7QjMgZAXOsuBD5nOs0AJkByYmf/' # 'test'

write_files:
  # resolv.conf hard-set is a workaround for intial setup
  - path: /etc/resolv.conf
    content: |
      nameserver 8.8.4.4
      nameserver 8.8.8.8
  - path: /etc/systemd/resolved.conf
    content: |
      [Resolve]
      DNS=8.8.4.4
      FallbackDNS=8.8.8.8
  - path: /tmp/append-etc-hosts
    content: |
      $(produce-etc-hosts -cblock $cblock -prefix '      ')
  - path: /etc/modules-load.d/k8s.conf
    content: |
      br_netfilter
  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-ip6tables = 1
      net.bridge.bridge-nf-call-iptables = 1
      net.bridge.bridge-nf-call-arptables = 1
      net.ipv4.ip_forward = 1
  - path: /etc/docker/daemon.json
    content: |
      {
        "exec-opts": ["native.cgroupdriver=systemd"],
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "100m"
        },
        "storage-driver": "overlay2",
        "storage-opts": [
          "overlay2.override_kernel_check=true"
        ]
      }
"@
}

function get-userdata-centos($cblock) {
return @"
$(get-userdata-shared -cblock $cblock)
  # https://github.com/kubernetes/kubernetes/issues/56850
  - path: /usr/lib/systemd/system/kubelet.service.d/12-after-docker.conf
    content: |
      [Unit]
      After=docker.service
  # https://github.com/clearlinux/distribution/issues/39
  - path: /etc/chrony.conf
    content: |
      refclock PHC /dev/ptp0 trust poll 2
      makestep 1 -1
      maxdistance 16.0
      #pool pool.ntp.org iburst
      driftfile /var/lib/chrony/drift
      logdir /var/log/chrony

package_upgrade: true

yum_repos:
  docker-ce-stable:
    name: Docker CE Stable - `$basearch
    baseurl: https://download.docker.com/linux/centos/7/`$basearch/stable
    enabled: 1
    gpgcheck: 1
    gpgkey: https://download.docker.com/linux/centos/gpg
    priority: 1
  kubernetes:
    name: Kubernetes
    baseurl: https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
    enabled: 1
    gpgcheck: 1
    repo_gpgcheck: 1
    gpgkey: https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
    priority: 1

packages:
  - hyperv-daemons
  - yum-utils
  - device-mapper-persistent-data
  - lvm2
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - kubelet
  - kubeadm
  - kubectl

runcmd:
  - echo "sudo tail -f /var/log/messages" > /home/$guestuser/log
  - systemctl restart chronyd
  - cat /tmp/append-etc-hosts >> /etc/hosts
  # https://docs.docker.com/install/linux/docker-ce/centos/
  - setenforce 0
  - sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  - mkdir -p /etc/systemd/system/docker.service.d
  - systemctl mask --now firewalld
  - systemctl daemon-reload
  - systemctl enable docker
  - systemctl enable kubelet
  # https://github.com/kubernetes/kubeadm/issues/954
  - echo "exclude=kube*" >> /etc/yum.repos.d/kubernetes.repo
  # https://github.com/kubernetes/kubernetes/issues/76531
  - curl -L 'https://github.com/youurayy/runc/releases/download/v1.0.0-rc8-slice-fix-2/runc-centos.tgz' | tar --backup=numbered -xzf - -C `$(dirname `$(which runc))
  - systemctl start docker
  - touch /home/$guestuser/.init-completed
"@
}

function get-userdata-ubuntu($cblock) {
return @"
$(get-userdata-shared -cblock $cblock)
  # https://github.com/kubernetes/kubernetes/issues/56850
  - path: /etc/systemd/system/kubelet.service.d/12-after-docker.conf
    content: |
      [Unit]
      After=docker.service
  - path: /etc/apt/preferences.d/docker-pin
    content: |
      Package: *
      Pin: origin download.docker.com
      Pin-Priority: 600
  - path: /etc/systemd/network/99-default.link
    content: |
      [Match]
      Path=/devices/virtual/net/*
      [Link]
      NamePolicy=kernel database onboard slot path
      MACAddressPolicy=none
  # https://github.com/clearlinux/distribution/issues/39
  - path: /etc/chrony/chrony.conf
    content: |
      refclock PHC /dev/ptp0 trust poll 2
      makestep 1 -1
      maxdistance 16.0
      #pool pool.ntp.org iburst
      driftfile /var/lib/chrony/chrony.drift
      logdir /var/log/chrony
apt:
  sources:
    kubernetes:
      source: "deb http://apt.kubernetes.io/ kubernetes-xenial main"
      keyserver: "hkp://keyserver.ubuntu.com:80"
      keyid: BA07F4FB
    docker:
      arches: amd64
      source: "deb https://download.docker.com/linux/ubuntu bionic stable"
      keyserver: "hkp://keyserver.ubuntu.com:80"
      keyid: 0EBFCD88

package_upgrade: true

packages:
  - linux-tools-virtual
  - linux-cloud-tools-virtual
  - chrony
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - kubelet
  - kubectl
  - kubeadm

runcmd:
  - echo "sudo tail -f /var/log/syslog" > /home/$guestuser/log
  - systemctl mask --now systemd-timesyncd
  - systemctl enable --now chrony
  - systemctl stop kubelet
  - cat /tmp/append-etc-hosts >> /etc/hosts
  - mkdir -p /usr/libexec/hypervkvpd && ln -s /usr/sbin/hv_get_dns_info /usr/sbin/hv_get_dhcp_info /usr/libexec/hypervkvpd
  - chmod o+r /lib/systemd/system/kubelet.service
  - chmod o+r /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
  # https://github.com/kubernetes/kubeadm/issues/954
  - apt-mark hold kubeadm kubelet
  # https://github.com/kubernetes/kubernetes/issues/76531
  - curl -L 'https://github.com/youurayy/runc/releases/download/v1.0.0-rc8-slice-fix-2/runc-ubuntu.tbz' | tar --backup=numbered -xjf - -C `$(dirname `$(which runc))
  - touch /home/$guestuser/.init-completed
"@
}

function create-public-net($zwitch, $adapter) {
  new-vmswitch -name $zwitch -allowmanagementos $true -netadaptername $adapter | format-list
}

function create-private-net($natnet, $zwitch, $cblock) {
  new-vmswitch -name $zwitch -switchtype internal | format-list
  new-netipaddress -ipaddress "$($cblock).1" -prefixlength 24 -interfacealias "vEthernet ($zwitch)" | format-list
  new-netnat -name $natnet -internalipinterfaceaddressprefix "$($cblock).0/24" | format-list
}

function produce-yaml-contents($path, $cblock) {
  set-content $path ([byte[]][char[]] `
    "$(&"get-userdata-$distro" -cblock $cblock)`n") -encoding byte
}

function produce-iso-contents($vmname, $cblock, $ip) {
  md $workdir\$vmname\cidata -ea 0 | out-null
  set-content $workdir\$vmname\cidata\meta-data ([byte[]][char[]] `
    "$(get-metadata -vmname $vmname -cblock $cblock -ip $ip)") -encoding byte
  produce-yaml-contents -path $workdir\$vmname\cidata\user-data -cblock $cblock
}

function make-iso($vmname) {
  $fsi = new-object -ComObject IMAPI2FS.MsftFileSystemImage
  $fsi.FileSystemsToCreate = 3
  $fsi.VolumeName = 'cidata'
  $vmdir = (resolve-path -path "$workdir\$vmname").path
  $path = "$vmdir\cidata"
  $fsi.Root.AddTreeWithNamedStreams($path, $false)
  $isopath = "$vmdir\$vmname.iso"
  $res = $fsi.CreateResultImage()
  $cp = New-Object CodeDom.Compiler.CompilerParameters
  $cp.CompilerOptions = "/unsafe"
  if (!('ISOFile' -as [type])) {
    Add-Type -CompilerParameters $cp -TypeDefinition @"
      public class ISOFile {
        public unsafe static void Create(string iso, object stream, int blkSz, int blkCnt) {
          int bytes = 0; byte[] buf = new byte[blkSz];
          var ptr = (System.IntPtr)(&bytes); var o = System.IO.File.OpenWrite(iso);
          var i = stream as System.Runtime.InteropServices.ComTypes.IStream;
          if (o != null) { while (blkCnt-- > 0) { i.Read(buf, blkSz, ptr); o.Write(buf, 0, bytes); }
            o.Flush(); o.Close(); }}}
"@ }
  [ISOFile]::Create($isopath, $res.ImageStream, $res.BlockSize, $res.TotalBlocks)
}

function create-machine($zwitch, $vmname, $cpus, $mem, $hdd, $vhdxtmpl, $cblock, $ip, $mac) {
  $vmdir = "$workdir\$vmname"
  $vhdx = "$workdir\$vmname\$vmname.vhdx"

  new-item -itemtype directory -force -path $vmdir | out-null

  if (!(test-path $vhdx)) {
    copy-item -path $vhdxtmpl -destination $vhdx -force
    resize-vhd -path $vhdx -sizebytes $hdd

    produce-iso-contents -vmname $vmname -cblock $cblock -ip $ip
    make-iso -vmname $vmname

    $vm = new-vm -name $vmname -memorystartupbytes $mem -generation $generation `
      -switchname $zwitch -vhdpath $vhdx -path $workdir

    if($generation -eq 2) {
      set-vmfirmware -vm $vm -enablesecureboot off
    }

    set-vmprocessor -vm $vm -count $cpus
    add-vmdvddrive -vmname $vmname -path $workdir\$vmname\$vmname.iso

    if(!$mac) { $mac = create-mac-address }

    get-vmnetworkadapter -vm $vm | set-vmnetworkadapter -staticmacaddress $mac
    set-vmcomport -vmname $vmname -number 2 -path \\.\pipe\$vmname
  }
  start-vm -name $vmname
}

function delete-machine($name) {
  stop-vm $name -turnoff -confirm:$false -ea silentlycontinue
  remove-vm $name -force -ea silentlycontinue
  remove-item -recurse -force $workdir\$name
}

function delete-public-net($zwitch) {
  remove-vmswitch -name $zwitch -force -confirm:$false
}

function delete-private-net($zwitch, $natnet) {
  remove-vmswitch -name $zwitch -force -confirm:$false
  remove-netnat -name $natnet -confirm:$false
}

function create-mac-address() {
  return "02$((1..5 | %{ '{0:X2}' -f (get-random -max 256) }) -join '')"
}

function basename($path) {
  return $path.substring(0, $path.lastindexof('.'))
}

function prepare-vhdx-tmpl($imageurl, $srcimg, $vhdxtmpl) {
  if (!(test-path $workdir)) {
    mkdir $workdir | out-null
  }
  if (!(test-path $srcimg$archive)) {
    download-file -url $imageurl -saveto $srcimg$archive
  }

  get-item -path $srcimg$archive | %{ write-host 'srcimg:', $_.name, ([math]::round($_.length/1MB, 2)), 'MB' }

  if($sha256file) {
    $hash = shasum256 -shaurl "$imagebase/$sha256file" -diskitem $srcimg$archive -item $image$archive
    echo "checksum: $hash"
  }
  else {
    echo "no sha256file specified, skipping integrity ckeck"
  }

  if(($archive -eq '.tar.gz') -and (!(test-path $srcimg))) {
    tar xzf $srcimg$archive -C $workdir
  }
  elseif(($archive -eq '.xz') -and (!(test-path $srcimg))) {
    7z e $srcimg$archive "-o$workdir"
  }
  elseif(($archive -eq '.bz2') -and (!(test-path $srcimg))) {
    7z e $srcimg$archive "-o$workdir"
  }

  if (!(test-path $vhdxtmpl)) {
    qemu-img.exe convert $srcimg -O vhdx -o subformat=dynamic $vhdxtmpl
  }

  echo ''
  get-item -path $vhdxtmpl | %{ write-host 'vhxdtmpl:', $_.name, ([math]::round($_.length/1MB, 2)), 'MB' }
  return
}

function download-file($url, $saveto) {
  echo "downloading $url to $saveto"
  $progresspreference = 'silentlycontinue'
  invoke-webrequest $url -usebasicparsing -outfile $saveto # too slow w/ indicator
  $progresspreference = 'continue'
}

function produce-etc-hosts($cblock, $prefix) {
  $ret = switch ($nettype) {
    'private' {
@"
#
$prefix#
$prefix$($cblock).10 master
$prefix$($cblock).11 node1
$prefix$($cblock).12 node2
$prefix$($cblock).13 node3
$prefix$($cblock).14 node4
$prefix$($cblock).15 node5
$prefix$($cblock).16 node6
$prefix$($cblock).17 node7
$prefix$($cblock).18 node8
$prefix$($cblock).19 node9
$prefix#
$prefix#
"@
    }
    'public' {
      ''
    }
  }
  return $ret
}

function update-etc-hosts($cblock) {
  produce-etc-hosts -cblock $cblock -prefix '' | out-file -encoding utf8 -append $etchosts
  get-content $etchosts
}

function create-nodes($num, $cblock) {
  1..$num | %{
    echo creating node $_
    create-machine -zwitch $zwitch -vmname "node$_" -cpus 4 -mem 4GB -hdd 40GB `
      -vhdxtmpl $vhdxtmpl -cblock $cblock -ip $(10+$_)
  }
}

function delete-nodes($num) {
  1..$num | %{
    echo deleting node $_
    delete-machine -name "node$_"
  }
}

function get-our-vms() {
  return get-vm | where-object { ($_.name -match 'master|node.*') }
}

function get-our-running-vms() {
  return get-vm | where-object { ($_.state -eq 'running') -and ($_.name -match 'master|node.*') }
}

function shasum256($shaurl, $diskitem, $item) {
  $pat = "^(\S+)\s+\*?$([regex]::escape($item))$"

  $hash = get-filehash -algo sha256 -path $diskitem | %{ $_.hash}

  $webhash = ( invoke-webrequest $shaurl -usebasicparsing ).tostring().split("`n") | `
    select-string $pat | %{ $_.matches.groups[1].value }

  if(!($hash -ieq $webhash)) {
    throw @"
    SHA256 MISMATCH:
       shaurl: $shaurl
         item: $item
     diskitem: $diskitem
     diskhash: $hash
      webhash: $webhash
"@
  }

  return $hash
}

function got-ctrlc() {
  if ([console]::KeyAvailable) {
    $key = [system.console]::readkey($true)
    if (($key.modifiers -band [consolemodifiers]"control") -and ($key.key -eq "C")) {
      return $true
    }
  }
  return $false;
}

function wait-for-node-init($opts, $name) {
  while ( ! $(ssh $opts master 'ls ~/.init-completed 2> /dev/null') ) {
    echo "waiting for $name to init..."
    start-sleep -seconds 5
    if( got-ctrlc ) { exit 1 }
  }
}

function hyperctl() {
  kubectl --kubeconfig=$HOME/.kube/config.hyperv $args
}

echo ''

if($args.count -eq 0) {
  $args = @( 'help' )
}

switch -regex ($args) {
  ^help$ {
    echo @"
  Practice real Kubernetes configurations on a local multi-node cluster.
  Inspect and optionally customize this script before use.

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

  For more info, see: https://github.com/youurayy/k8s-hyperv
"@
  }
  ^install$ {
    choco install 7zip.commandline qemu-img kubernetes-cli kubernetes-helm
  }
  ^config$ {
    echo "    config: $config"
    echo "    distro: $distro"
    echo "   workdir: $workdir"
    echo " guestuser: $guestuser"
    echo "   sshpath: $sshpath"
    echo "  imageurl: $imageurl"
    echo "  vhdxtmpl: $vhdxtmpl"
    echo "      cidr: $cidr.0/24"
    echo "    switch: $zwitch"
    echo "   nettype: $nettype"
    switch ($nettype) {
      'private' { echo "    natnet: $natnet" }
      'public'  { echo "   adapter: $adapter" }
    }
    echo "      cpus: $cpus"
    echo "       ram: $ram"
    echo "       hdd: $hdd"
    echo "       cni: $cni"
    echo "    cninet: $cninet"
    echo "   cniyaml: $cniyaml"
  }
  ^print$ {
    echo "***** $etchosts *****"
    get-content $etchosts | select-string -pattern '^#|^\s*$' -notmatch

    echo "`n***** configured mac addresses *****`n"
    echo $macs

    echo "`n***** network interfaces *****`n"
    (get-vmswitch 'switch' -ea:silent | `
      format-list -property name, id, netadapterinterfacedescription | out-string).trim()

    if ($nettype -eq 'private') {
      echo ''
      (get-netipaddress -interfacealias 'vEthernet (switch)' -ea:silent | `
        format-list -property ipaddress, interfacealias | out-string).trim()
      echo ''
      (get-netnat 'natnet' -ea:silent | format-list -property name, internalipinterfaceaddressprefix | out-string).trim()
    }
  }
  ^net$ {
    switch ($nettype) {
      'private' { create-private-net -natnet $natnet -zwitch $zwitch -cblock $cidr }
      'public' { create-public-net -zwitch $zwitch -adapter $adapter }
    }
  }
  ^hosts$ {
    switch ($nettype) {
      'private' { update-etc-hosts -cblock $cidr }
      'public' { echo "not supported for public net - use dhcp"  }
    }
  }
  ^macs$ {
    $cnt = 10
    0..$cnt | %{
      $comment = switch ($_) {0 {'master'} default {"node$_"}}
      $comma = if($_ -eq $cnt) { '' } else { ',' }
      echo "  '$(create-mac-address)'$comma # $comment"
    }
  }
  ^image$ {
    prepare-vhdx-tmpl -imageurl $imageurl -srcimg $srcimg -vhdxtmpl $vhdxtmpl
  }
  ^master$ {
    create-machine -zwitch $zwitch -vmname 'master' -cpus $cpus `
      -mem $(Invoke-Expression $ram) -hdd $(Invoke-Expression $hdd) `
      -vhdxtmpl $vhdxtmpl -cblock $cidr -ip '10' -mac $macs[0]
  }
  '(^node(?<number>\d+)$)' {
    $num = [int]$matches.number
    $name = "node$($num)"
    create-machine -zwitch $zwitch -vmname $name -cpus $cpus `
      -mem $(Invoke-Expression $ram) -hdd $(Invoke-Expression $hdd) `
      -vhdxtmpl $vhdxtmpl -cblock $cidr -ip "$($num + 10)" -mac $macs[$num]
  }
  ^info$ {
    get-our-vms
  }
  ^init$ {

    get-our-vms | %{ wait-for-node-init -opts $sshopts -name $_.name }

    echo "all nodes are pre-initialized, making VM snapshots before k8s init..."

    get-our-vms | checkpoint-vm

    $init = "sudo kubeadm init --pod-network-cidr=$cninet && \
      mkdir -p `$HOME/.kube && \
      sudo cp /etc/kubernetes/admin.conf `$HOME/.kube/config && \
      sudo chown `$(id -u):`$(id -g) `$HOME/.kube/config && \
      kubectl apply -f `$(eval echo $cniyaml)"

    echo "executing on master: $init"

    if ( ! (ssh $sshopts master $init)) {
      echo "master init has failed, aborting"
      exit 1
    }

    $joincmd = $(ssh $sshopts master 'sudo kubeadm token create --print-join-command')

    get-our-vms | where { $_.name -match "node.+" } |
      %{
        $node = $_.name
        echo "executing on $node`: $joincmd"

        if ( ! (ssh $sshopts $node sudo $joincmd)) {
          echo "$node init has failed, aborting"
          exit 1
        }
      }

    new-item -itemtype directory -force -path $HOME\.kube | out-null
    scp $sshopts master:.kube/config $HOME\.kube\config.hyperv

    $pwsalias = 'function hyperctl() { kubectl --kubeconfig=$HOME\.kube\config.hyperv $args }'
    $bashalias = "alias hyperctl='kubectl --kubeconfig=$HOME\.kube\config.hyperv'"

    echo "hyperctl get pods --all-namespaces`n"
    hyperctl get pods --all-namespaces
    echo ""
    echo "hyperctl get nodes`n"
    hyperctl get nodes

    echo ""
    echo "powershell alias:"
    echo "  write-output '$pwsalias' | out-file -encoding utf8 -append `$profile"
    echo ""
    echo "bash alias:"
    echo "  write-output `"``n$($bashalias.replace('\', '\\'))``n`" | out-file -encoding utf8 -append -nonewline ~\.profile"
    echo ""
  }
  ^reboot$ {
    get-our-vms | %{ $(ssh $sshopts $_.name 'sudo reboot') }
  }
  ^shutdown$ {
    get-our-vms | %{ $(ssh $sshopts $_.name 'sudo shutdown -h now') }
  }
  ^save$ {
    get-our-vms | checkpoint-vm
  }
  ^restore$ {
    get-our-vms | foreach-object { $_ | get-vmsnapshot | sort creationtime | `
      select -last 1 | restore-vmsnapshot -confirm:$false }
  }
  ^stop$ {
    get-our-vms | stop-vm
  }
  ^start$ {
    get-our-vms | start-vm
  }
  ^delete$ {
    get-our-vms | %{ delete-machine -name $_.name }
  }
  ^delnet$ {
    switch ($nettype) {
      'private' { delete-private-net -zwitch $zwitch -natnet $natnet }
      'public' { delete-public-net -zwitch $zwitch }
    }
  }
  ^time$ {
    echo "local: $(date)"
    get-our-vms | %{
      $node = $_.name
      echo ---------------------$node
      # ssh $sshopts $node "date ; if which chronyc > /dev/null; then sudo chronyc makestep ; date; fi"
      ssh $sshopts $node "date"
    }
  }
  ^track$ {
    get-our-vms | %{
      $node = $_.name
      echo ---------------------$node
      ssh $sshopts $node "date ; sudo chronyc tracking"
    }
  }
  ^docker$ {
    $saveto = "C:\ProgramData\chocolatey\bin\docker.exe"
    if (!(test-path $saveto)) {
      echo "installing docker cli..."
      download-file -url $dockercli -saveto $saveto
    }
    echo ""
    echo "powershell:"
    echo "  write-output '`$env:DOCKER_HOST = `"ssh://master`"' | out-file -encoding utf8 -append `$profile"
    echo ""
    echo "bash:"
    echo "  write-output `"``nexport DOCKER_HOST='ssh://master'``n`" | out-file -encoding utf8 -append -nonewline ~\.profile"
    echo ""
  }
  ^iso$ {
    produce-yaml-contents -path "$($distro).yaml" -cblock $cidr
  }
  default {
    echo 'invalid command; try: ./hyperv.ps1 help'
  }
}

echo ''
