# Kubernetes Cluster on Hyper-V

Practice real Kubernetes configurations on a local multi-node cluster.

Tested on: PowerShell 5.1 on Windows 10 Pro 1903, guest images Ubuntu 18.04 and 19.04.

Start by reading the [hyper-v.ps1](hyper-v.ps1) script.

## Example usages:

```powershell

# Prepare the image
$vhdxtmpl = prepare-vhdx-tmpl -url `
  'http://cloud-images.ubuntu.com/releases/server/18.04/release/ubuntu-18.04-server-cloudimg-amd64.img'

# 1. create switch/network
create-public-net -switch 'switch' -adapter 'Wi-Fi'
# --or--
create-private-net -natnet 'natnet' -switch 'switch' -cblock '10.10.0'

# 2. create machines (for DHCP use -cblock $null -ip $null -mac your_saved_mac_address)
create-machine -switch 'switch' -vmname 'master' -cpus 4 -mem 4GB -hdd 40GB `
    -vhdxtmpl $vhdxtmpl -cblock '10.10.0' -ip '10' -mac '0225EA2C9AE7'
create-machine -switch 'switch' -vmname 'node1' -cpus 4 -mem 4GB -hdd 40GB `
    -vhdxtmpl $vhdxtmpl -cblock '10.10.0' -ip '11' -mac '02A254C4612F'
create-machine -switch 'switch' -vmname 'node2' -cpus 4 -mem 4GB -hdd 40GB `
    -vhdxtmpl $vhdxtmpl -cblock '10.10.0' -ip '12' -mac '02FBB5136210'

# 3. open Hyper-V manager, and wait until all VMs are auto-stopped,
#    then start them again (select "Continue"), and you can SSH into them

# 4. optionally, update /etc/hosts so you can e.g. `ssh user@master`
update-etc-hosts -cblock '10.10.0'

# 5. when done, delete machines
delete-machine -name 'node2'
delete-machine -name 'node1'
delete-machine -name 'master'

# 6. when done, delete switch/network
delete-public-net -switch 'switch'
# --or--
delete-private-net -switch 'switch' -natnet 'natnet'

# example scripting:
# (if w/o exclusive master: kubectl taint nodes node1 node-role.kubernetes.io/master-)
$num = 6
create-nodes($num, '10.10.0')
delete-nodes($num)

```

#### License: https://www.apache.org/licenses/LICENSE-2.0
