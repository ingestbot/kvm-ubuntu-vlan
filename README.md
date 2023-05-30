github.com/ingestbot/kvm-ubuntu-vlan


# kvm-ubuntu-vlan

## Purpose

This isn't a code repository per-se but more of a guide to setting up KVM on Ubuntu with (or without)
VLANs. The inspiration for writing this was largely because of the lack of clear and detailed instructions available for this path. 
While excellent technical documentation exists for the various components used here ([kvm](https://www.linux-kvm.org), [qemu](https://www.qemu.org), [libvirt](https://libvirt.org)), there 
isn't much available offering a quick start for proof of concepts or evaluations. 

This work began as a need to replace [VirtualBox](https://www.virtualbox.org) virtualization in a small environment involving two hypervisors 
and 24 virtual machines. While VirtualBox is a very comprehensive and well supported solution, there were
issues of scale and performance which inspired a need to look elsewhere. 


## Terminology

Some terminology to consider. This writing may not be using all terms with intended accuracy. Virtual Machines (VM) are also referred to as *guests* or *domains*. The system hosting VMs is referred to as a *hypervisor*. Network interfaces may be referred to as *adapter*, *NIC*, or *interface*. 


## Requirements / Assumptions

The installation which follows was done on a newly built **Ubuntu 22.04.2 Server** (ubuntu-22.04.2-live-server-amd64.iso) with a minimal installation. The default networking on Ubuntu is via Netplan with systemd-networkd. If your environment is slightly different from this, it's unlikely significant
issues will surface. These points are noted less so as requirements as they are general guidelines.

A few steps involve forwarding X11 connections via ssh. If installing on a local desktop with X11 capability this may not be a concern. To avoid obstacles, be certain to have X11 capability functional from hypervisor to viewing client. 

* Ubuntu 22.04.2
* [Netplan](https://netplan.io) with [Systemd-networkd](https://manpages.ubuntu.com/manpages/bionic/man5/systemd.network.5.html) renderer
* `kvm-ok` shows `KVM acceleration can be used` (see: [https://ubuntu.com/blog/kvm-hyphervisor](https://ubuntu.com/blog/kvm-hyphervisor))
* [XQuartz](https://www.xquartz.org) or similar X11 emulator


## Installation

First, as an optional measure, and if working with a minimal installation, apply some packages that are typically available:

```
# apt install vim iputils-ping dnsutils ethtool
```

Now install the KVM/qemu/libvirt components:

```
# apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager libvirt-dev
```

Once the installation is complete, verify libvirtd is running.

```
# systemctl status libvirtd
```

List the default network.

```
# virsh net-list --all
 Name      State    Autostart   Persistent
--------------------------------------------
 default   active   yes         yes
```

Show details of the default network and make note of the `Bridge:` reference:

```
# virsh net-info default
Name:           default
UUID:           4f362d96-4c68-415d-bd5b-6afda75cc48e
Active:         yes
Persistent:     yes
Autostart:      yes
Bridge:         virbr0
```

Show the bridge interface as configured in the OS:

```
# ip a show virbr0
 virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 52:54:00:72:d8:34 brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
       valid_lft forever preferred_lft forever
```

The configuration and artifacts for network interfaces/bridges, DHCP, and machines are located here:

* `/etc/libvirt`
* `/etc/libvirt/qemu/networks/default.xml`
* `/var/lib/libvirt`


### virt-manager

[virt-manager](https://virt-manager.org) ([github](https://github.com/virt-manager/virt-manager)) offers a means of interfacing and managing 
vms. This was installed by the installation note above with `apt install virt-manager.` Start with:

* `export DISPLAY=<hostname>:0.0` (on hypervisor, if remote)
* `xhost +` (on client, if remote)
* `virt-manager`

### Sample VM

Obtain a copy of the Ubuntu installation medium in ISO form: [https://releases.ubuntu.com](https://ubuntu.com/blog/kvm-hyphervisor) and make it available on the hypervisor.

There are a couple of introductory methods for demonstrating the launch of a VM. One or both of these may be used, yet by using 
the virt-manager method, more functionality of libvirt can be seen. 

#### Autoinstall Quickstart (kvm QEMU emulator)

The [Automated Server install quickstart](https://ubuntu.com/server/docs/install/autoinstall-quickstart) page offers good 
instructions to demonstrate the functionality of a VM. A few things to note:

* If at the start of running the install, an error appears: `kvm: warning: host doesn't support requested feature: CPUID.80000001H:ECX.svm [bit 2]` try using 
`-cpu host` at the start of the installer:

```
kvm -no-reboot -m 2048 -cpu host \
```
* Don't forget to specify the location of the install medium:

```
-cdrom /root/ubuntu-22.04.2-live-server-amd64.iso \
```

* If `gtk initialization failed` use XQuartz (or other) with `export DISPLAY=<hostname>:0.0` and `xhost +`
* If the install presents a 'select your language' screen, be certain the web server (`python3 -m http.server 3003`) is running in the `~www` directory
* Verify the web server is functional with access to necessary install files with `curl localhost:3003/user-data`


#### virt-manager 

Alternatively, a machine can be created using virt-manager. Begin with `Create a new virtual machine` and follow the prompts. 

---
***After demonstrating a sample machine, discard of any artifacts before proceeding.***


## Configuration - Networking

What follows here will modify the default installation. If in doubt, create copies/backups of `/etc/libvirt` and `/var/lib/libvirt`

### libvirt networking 

The default bridge will be removed. Again, make note of the interface (`ip address`) and current configuration (`/etc/libvirt/qemu/networks/default.xml`).

```
# virsh net-destroy default
# virsh net-undefine default
```

Verify removal and restart/check libvirtd

```
# ip address 
# virsh net-list --all
# systemctl restart libvirtd
# systemctl status libvirtd
```

Now create one or more bridges. Shown here, one is to be used without VLAN support, the other to be configured with VLAN 25 (optional). Use the 
provided files `br0.xml` and `br25.xml`

```
# virsh net-define br0.xml
# virsh net-start br0
# virsh net-autostart br0
```

```
# virsh net-define br25.xml
# virsh net-start br25
# virsh net-autostart br25
```

Check that both bridges exist:

```
# virsh net-list --all
 Name   State      Autostart   Persistent
-------------------------------------------
 br0    active   yes         yes
 br25   active   yes         yes
```

### OS networking (Netplan)

Modifying and applying the netplan configuration will significantly alter the operating system's networking functionality. Be certain to 
have an alternate means of accessing the system if something goes wrong here. Networking, Netplan, and specifically bridging interfaces is 
well beyond the scope of this effort. Be aware that configuration beyond what is shown here can be complex.

* Make note of the current configuration: `ip address`, `ip route` 
* Make a copy (or move) the existing netplan configuration: `mv /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.ORIG`
* Using the provided netplan `netplan/00-netplan.yaml` be certain the interface reflected (eg, `eno1`) matches that on your system. 
* After modifying, if needed, move the netplan configuation into place `/etc/netplan/00-netplan.yaml` and check that it's the only configuration 
to be applied (eg, `ls /etc/netplan/*.yaml`), or the only configuration applied to the relevant interface(s). 
* Once in place, validate the configuration `netplan try` and if no issues, apply `netplan apply`
* The OS networking configuration should now reflect the newly created bridges:

`ip a show br0`   
`ip a show br25`

If the configuration is satisfactory, restart/reboot the system to ensure proper functionality.

## Configuration - Storage

change 'Storage Pool' (image directory, box location)https://serverfault.com/questions/840519/how-to-change-the-default-storage-pool-from-libvirt

default: /var/lib/libvirt/images

```
# virsh pool-list
 Name      State    Autostart
-------------------------------
 default   active   yes

```

Show details of the default storage pool making note of the default location: 

```
# virsh pool-dumpxml default
...
    <path>/var/lib/libvirt/images</path>
...
```

Remove the default storage pool:  

```
# virsh pool-destroy default
# virsh pool-undefine default
```

Replace with desired location and activate: 

```
# virsh pool-define-as --name default --type dir --target /vbox
# virsh pool-autostart default
# virsh pool-start default
```
Again, list the details of the storage pool and make note of the newly defined location:

```
# virsh pool-list 
...
# virsh pool-dumpxml default
...
    <path>/vbox</path>
...
```

## And Beyond

See the repository [https://github.com/ingestbot/hashivirt](https://github.com/ingestbot/hashivirt) for details on using Hashicorp's Packer and Vagrant for box building and provisioning. 

## Issues 

### Shared Folder (Filesystem Passthrough) 

Documentation on sharing data between host and guest is lacking. This [question on serverfault](https://serverfault.com/questions/178216/best-way-to-share-a-folder-between-kvm-host-and-guest) offers some initial
leads. This shows how to use [virt-manager](https://virt-manager.org) to best accomplish this. 

* virt-manager: shutdown and select VM -> `Show virtual hardware details` -> `Memory` -> `Enable shared memory` 
* virt-manager: `Add hardware` -> `Filesystem` 
 - `Driver: virtio-9p`
 - `Source path: /path/foo/bar`
 - `Target path: foobar`

* Source path may require specific ownership and mode depending on your installation. Try `chown root.root /path/foo/bar; chmod 777 /path/foo/bar` initially.
* On guest: `mount -t 9p foobar /mnt` 
 - If `bad option; for several filesystems (e.g. nfs, cifs) you might need a /sbin/mount.<type> helper program.` verify/change owner and mode of Source path and verify Driver is `virtio-9p`
 - If continued issues, verify 9p modules are present: `cat /proc/filesystems | grep 9p` should reflect `nodev 9p` and `lsmod | grep 9p` should list `9p, 9pnet_virtio, 9pnet`
* To mount at boot, update `/etc/fstab`:
 - `foobar /mnt 9p 0 0`
 - It may be necessary to add the [9p modules to initramfs](https://superuser.com/questions/502205/libvirt-9p-kvm-mount-in-fstab-fails-to-mount-at-boot-time) (add `9p, 9pnet_virtio, 9pnet` to `/etc/initramfs-tools/modules` 
and run `update-initramfs -u`


See also:

- https://www.linux-kvm.org/page/9p_virtio  
- https://wiki.qemu.org/Documentation/9psetup


### NIC Adapter Reset / e1000e Issue 

Significant modifications on network interfaces may bring some undesired results. Some have found that with heavy network traffic passing through the NIC, there are occasional interruptions in connectivity. If your experience this, check for something similar to the following:

```
# dmesg 
...
e1000e 0000:00:19.0 eth0: Reset adapter unexpectedly
```

Determine if the adapter is using e1000e:

```
# ethtool -i eno1
driver: e1000e
...
```

Try toggling `tcp-segmentation-offload` for improved effect:

```
ethtool -K eno1 tcp-segmentation-offload off
```

Use `iperf3` or similar network performance tool to produce/simulate large amounts of traffic. 

If the `tcp-segmentation-offload` adjustment had positive impact, make permanent by using the provided `/networkd-dispatcher/configured.d/01-tso-off.sh` 

https://superuser.com/questions/1270723/how-to-fix-eth0-detected-hardware-unit-hang-in-debian-9
https://serverfault.com/questions/616485/e1000e-reset-adapter-unexpectedly-detected-hardware-unit-hang




## Resources

- https://ostechnix.com/ubuntu-install-kvm
- https://phoenixnap.com/kb/ubuntu-install-kvm
- https://ubuntu.com/blog/kvm-hyphervisor
- https://vagrant-libvirt.github.io/vagrant-libvirt/
- https://jamielinux.com/docs/libvirt-networking-handbook/index.html
- https://fabianlee.org/2019/06/05/kvm-creating-a-guest-vm-on-a-network-in-routed-mode/
- https://ubuntu.com/server/docs/install/autoinstall
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/index
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/index
- https://blog.scottlowe.org/2012/11/07/using-vlans-with-ovs-and-libvirt/
- https://blog.scottlowe.org/2012/08/21/working-with-kvm-guests/
- https://blog.scottlowe.org/2016/02/09/using-kvm-libvirt-macvtap-interfaces/
- https://www.math.cmu.edu/~gautam/sj/blog/20140303-kvm-macvtap.html
- https://www.linuxtechi.com/how-to-install-kvm-on-ubuntu-22-04/
