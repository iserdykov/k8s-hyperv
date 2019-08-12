#!/usr/bin/env powershell
# For usage overview, read the readme.md at https://github.com/youurayy/k8s-hyperv
# License: https://www.apache.org/licenses/LICENSE-2.0

# ---------------------------SETTINGS------------------------------------

$workdir = '.\tmp'
$guestuser = $env:USERNAME
$sshpath = "$HOME\.ssh\id_rsa.pub"
if (!(test-path $sshpath)) {
  write-host "`n please configure `$sshpath or place a pubkey at $sshpath `n"
  exit
}
$sshpub = get-content $sshpath -raw

# kernel 4.15
# https://wiki.ubuntu.com/BionicBeaver/ReleaseNotes
# $imageurl = 'http://cloud-images.ubuntu.com/releases/server/18.04/release/ubuntu-18.04-server-cloudimg-amd64.img'

# kernel 5.0
# https://wiki.ubuntu.com/DiscoDingo/ReleaseNotes
$imageurl = 'http://cloud-images.ubuntu.com/releases/server/19.04/release/ubuntu-19.04-server-cloudimg-amd64.img'

$nettype = 'private' # private/public
$zwitch = 'switch' # private or public switch name
$natnet = 'natnet' # private net nat net name
$adapter = 'Wi-Fi' # public net adapter name

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

# ----------------------------------------------------------------------

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
  - name: $guestuser
    ssh_authorized_keys:
      - $($sshpub)
    sudo: [ 'ALL=(ALL) NOPASSWD:ALL' ]
    groups: [ sudo, docker ]
    shell: /bin/bash
    # lock_passwd: false
    # passwd: '`$6`$rounds=4096`$byY3nxArmvpvOrpV`$2M4C8fh3ZXx10v91yzipFRng1EFXTRNDE3q9PvxiPc3kC7N/NHG8HiwAvhd7QjMgZAXOsuBD5nOs0AJkByYmf/' # 'test'

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

function create-public-net($zwitch, $adapter) {
  new-vmswitch -name $zwitch -allowmanagementos $true -netadaptername $adapter | format-list
}

function create-private-net($natnet, $zwitch, $cblock) {
  new-vmswitch -name $zwitch -switchtype internal | format-list
  new-netipaddress -ipaddress "$($cblock).1" -prefixlength 24 -interfacealias "vEthernet ($zwitch)" | format-list
  new-netnat -name $natnet -internalipinterfaceaddressprefix "$($cblock).0/24" | format-list
}

function produce-iso-contents($vmname, $cblock, $ip) {
  md $workdir\$vmname\cidata -ea 0 | out-null
  set-content $workdir\$vmname\cidata\meta-data ([byte[]][char[]] `
    "$(get-metadata -vmname $vmname -cblock $cblock -ip $ip)") -encoding byte
  set-content $workdir\$vmname\cidata\user-data ([byte[]][char[]] `
    "$(get-userdata -vmname $vmname)") -encoding byte
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

    $vm = new-vm -name $vmname -memorystartupbytes $mem -generation 2 `
      -switchname $zwitch -vhdpath $vhdx -path $workdir
    set-vmfirmware -vm $vm -enablesecureboot off
    set-vmprocessor -vm $vm -count $cpus
    add-vmdvddrive -vmname $vmname -path $workdir\$vmname\$vmname.iso

    if(!$mac) { $mac = create-mac-address }
    get-vmnetworkadapter -vm $vm | set-vmnetworkadapter -staticmacaddress $mac

    set-vmcomport -vmname $vmname -number 2 -path \\.\pipe\dbg1
  }
  start-vm -name $vmname
}

function delete-machine($name) {
  stop-vm $name -turnoff -confirm:$false -ErrorAction SilentlyContinue
  remove-vm $name -force  -ErrorAction SilentlyContinue
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
  return "02$((1..5 | %{ '{0:X2}' -f (Get-Random -Max 256) }) -join '')"
}

function basename($path) {
  return $path.substring(0, $path.lastindexof('.'))
}

function prepare-vhdx-tmpl($url, $srcimg, $vhdxtmpl) {
  if (!(test-path $workdir)) {
    mkdir $workdir | out-null
  }
  if (!(test-path $srcimg)) {
    invoke-webrequest $url -usebasicparsing -outfile $srcimg
  }
  if (!(test-path $vhdxtmpl)) {
    qemu-img.exe convert $srcimg -O vhdx -o subformat=dynamic $vhdxtmpl
  }
  return
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

"@ | out-file -encoding utf8 -append $etchosts

get-content $etchosts
}

function create-nodes($num, $cblock) {
  1..$num | %{
    echo creating node $_
    create-machine -zwitch $zwitch -vmname "node$_" -cpus 4 -mem 4GB -hdd 40GB -vhdxtmpl $vhdxtmpl -cblock $cblock -ip $(10+$_)
  }
}

function delete-nodes($num) {
  1..$num | %{
    echo deleting node $_
    delete-machine -name "node$_"
  }
}

function get-image-vars($imageurl) {
  $srcimg = "$workdir\$(split-path $imageurl -leaf)"
  $vhdxtmpl = "$(basename $srcimg).vhdx"
  return $srcimg, $vhdxtmpl

}

function get-our-vms() {
  return get-vm | where-object { ($_.name -match 'master|node.*') }
}

function get-our-running-vms() {
  return get-vm | where-object { ($_.state -eq 'running') -and ($_.name -match 'master|node.*') }
}

echo ''

$srcimg, $vhdxtmpl = get-image-vars($imageurl)

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

     install - install basic homebrew packages
      config - show script config vars
       print - print etc/hosts, network interfaces and mac addresses
         net - install private or public network
       hosts - append node names to etc/hosts
        macs - generate new set of MAC addresses
       image - download the VM image
      master - create and launch master node
       nodeN - create and launch worker node (node1, node2, ...)
        info - display info about nodes
        save - snapshot the VMs
     restore - restore VMs from latest snapshots
        stop - stop the VMs
       start - start the VMs
      delete - stop VMs and delete the VMs files
      delnet - delete the network

  For more info, see: https://github.com/youurayy/k8s-hyperv
"@
  }
  ^install$ {
    choco install kubernetes-cli kubernetes-helm qemu-img
  }
  ^config$ {
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
    prepare-vhdx-tmpl -url $imageurl -srcimg $srcimg -vhdxtmpl $vhdxtmpl
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
  default {
    echo 'invalid command; try: ./hyperv.ps1 help'
  }
}

echo ''

# License: https://www.apache.org/licenses/LICENSE-2.0

