# Dropbear - Set Up Remote Unlocking of LUKS Root Filesystem

To decrypt a LUKS-encrypted root filesystem remotely, you need to provide a passphrase or keyfile during the early boot phase before the root filesystem is mounted. Since traditional SSH access is not available at this stage, you need to set up an environment that allows remote access to the boot process within the initramfs. This is typically done using a minimal SSH server (like **Dropbear**) or similar mechanisms within the initramfs environment.

Here's how you can set this up:

### Steps to Set Up Remote Unlocking of LUKS Root Filesystem

#### Network during boot

**Static IP**

If your server gets the IP address automatically (DHCP) ignore this step, otherwise you have to specify the IP configuration at the Kernel boot line. To do this edit the file */etc/default/grub* and define the line:

```bash
GRUB_CMDLINE_LINUX="ip=<client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>"
```


Using the format specified in the file Documentation/nfsroot.txt of the Linux kernel documentation. For example:

```bash
GRUB_CMDLINE_LINUX="ip=192.168.122.192::192.168.122.1:255.255.255.0::eth0:none"
```

Reload the grub configuration

```bash
update-grub
```


**For DHCP - Make Sure the DHCP server reserved an ip for yuor mac address**

You need to get the same address always if using DHCP, **because else, how are you going to know where to connect to decrypt the drive ?**

Most routers can reserve a specific IP for the mac address of your server.

To do this edit the file */etc/default/grub* and define the line:

```bash
GRUB_CMDLINE_LINUX="ip=dhcp"
```

Reload the grub configuration

```bash
update-grub
```

After reboot, wai until you get an ip, look on your router, you will see the request and the mac address, then reserve the IP

#### Install and Configure Dropbear (SSH in Initramfs)

`Dropbear` is a lightweight SSH server that can be included in the initramfs, allowing you to remotely access the system during the early boot phase (before the root filesystem is mounted).

**Install Dropbear for Initramfs**:

You can install Dropbear specifically for the initramfs using `initramfs-tools`:

```bash
sudo apt install openssh-server busybox dropbear-initramfs
```

##### Set dropbear to start

```bash
sudo nano /etc/default/dropbear
```


*Change NO_START=1 to NO_START=0*


For remote unlocking to work, the following packages have to be installed before building the initramfs: dropbear busybox

The file */etc/initramfs-tools/initramfs.conf* holds the configuration options
used when building the initramfs. It should contain **BUSYBOX=y** (this is set as the default when the busybox package is installed) to have busybox installed into the initramfs, also you shoud add **DROPBEAR=y**

It should **not** contain DROPBEAR=n, which would disable installation of dropbear to initramfs. If set to **DROPBEAR=y**, dropbear will be installed in any case; if DROPBEAR isn't set at all, then dropbear will only be installed in case of an existing cryptroot setup.


### Keys

theres is the keys used during boot (initramfs) and keys used after unlock

To create a key (in dropbear format):

```bash
dropbearkey -t rsa -f /etc/initramfs-tools/root/.ssh/id_rsa.dropbear
```
To convert the key from dropbear format to openssh format:

```bash
/usr/lib/dropbear/dropbearconvert dropbear openssh /etc/initramfs-tools/root/.ssh/id_rsa.dropbear /etc/initramfs-tools/root/.ssh/id_rsa
```

To extract the public key:

```bash
dropbearkey -y -f /etc/initramfs-tools/root/.ssh/id_rsa.dropbear | grep "^ssh-rsa " > /etc/initramfs-tools/root/.ssh/id_rsa.pub
```
To add the public key to the authorized_keys file:

```bash
cat /etc/initramfs-tools/root/.ssh/id_rsa.pub >> /etc/initramfs-tools/root/.ssh/authorized_keys
```

The host keys used for the initramfs are dropbear_dss_host_key and dropbear_rsa_host_key, both located in /etc/dropbear/initramfs-tools
If they do not exist when the initramfs is compiled, they will be created automatically when you run dropbear with the **-R** option. 

To create the hostkeys as required, run this:


```bash
sudo dropbear -F -R -p 2222
```

Keys will be located in */etc/dropbear/initramfs-tools*

```bash
dss /etc/dropbear/dropbear_dss_host_key
rsa /etc/dropbear/dropbear_rsa_host_key
ecdsa /etc/dropbear/dropbear_ecdsa_host_key
ed25519 /etc/dropbear/dropbear_ed25519_host_key
```


Following are the commands to create them manually (not recommended):

```bash
dropbearkey -t dss -f /etc/dropbear/initramfs-tools/dropbear_dss_host_key
dropbearkey -t rsa -f /etc/dropbear/initramfs-tools/dropbear_rsa_host_key
```


The Dropbear configuration file for initramfs is located at `/etc/dropbear-initramfs/config`. You can configure options such as the SSH port, root login, or key-based authentication here.

Edit the configuration file to enable passwordless login using SSH keys (highly recommended):

```bash
sudo nano /etc/dropbear-initramfs/config
   ```

Enable root login and force key creation

```bash
DROPBEAR_OPTIONS="-p 2222 -R"
```

   - `-p 2222`: This tells Dropbear to listen on port 2222 (you can use any port that works for your environment).
   - `-s`: This option disables password logins and enforces key-based authentication.

**Add Your SSH Public Key**:

Add your public SSH key to the initramfs Dropbear configuration so that you can log in remotely. Place your SSH public key in `/etc/dropbear-initramfs/authorized_keys`:

```bash
   sudo nano /etc/dropbear-initramfs/authorized_keys
```

Paste your public SSH key (e.g., from `~/.ssh/id_rsa.pub`) into the file.

**Update Initramfs**:

After configuring Dropbear and adding your SSH key, regenerate the initramfs image to include these changes:

```bash
sudo update-initramfs -u
```

This will include Dropbear and your configuration in the initramfs image.


### Copy the private key to the machine you use to decrypt

Copy the SSH key that has been generated automatically

```bash
scp root@my.server.ip.addr:/etc/initramfs-tools/root/.ssh/id_rsa ~/id_rsa.initramfs
```


### **Unlocking procedure**


To unlock from remote, you could do something like this:

```bash
# ssh -o "UserKnownHostsFile=~/.ssh/known_hosts.initramfs" -i "~/id_rsa.initramfs" root@myserver.com "echo -ne \"secret\" >/lib/cryptsetup/passfifo"
```

This example assumes that you have an extra known_hosts file "~/.ssh/known_hosts.initramfs" which holds the cryptroot system's host-key, that you have a file "~/id_rsa.initramfs" which holds the authorized-key for the cryptroot system, that the cryptroot system's name is "myserver.com", and that the cryptroot passphrase is "secret"

#### Using ssh config file

I recommend using ssh config to manage these connection options. Add this to *~/.ssh/config*

```bash
Host mini
    HostName 10.3.1.33
    User gp
    Port 2222
    UserKnownHostsFile ~/.ssh/known_hosts

Host miniboot
    HostName 10.3.1.111
    User root
    Port 2222
    UserKnownHostsFile ~/.ssh/known_hosts.initramfs
```

**Automating with Remote Key Management (Optional)**

If you want to automate the unlocking process, you can use network-bound disk encryption (NBDE) tools like **Tang** and **Clevis**, or you can set up a custom remote key management system where the passphrase or keyfile is retrieved from a remote server.

- **Tang and Clevis**: These tools allow a system to be automatically unlocked if it is connected to a trusted network. Tang acts as a key server, and Clevis handles the client-side integration to unlock the LUKS volume.
  - Install Tang on a remote server and Clevis on the client.
  - Configure Clevis to request a key from Tang during the initramfs stage, automatically decrypting the root filesystem if the Tang server is accessible.


#### **Securing the Remote Access (Important)**

Since you're exposing SSH access to the initramfs environment, security is critical. Here are some important security measures:

1. **Use SSH Key Authentication**: Only allow SSH login with public/private key pairs, and disable password-based authentication.

2. **Restrict Access by IP**: Use firewall rules to allow access only from trusted IP addresses.

3. **Use a VPN**: If possible, set up a VPN between your machine and the server, so that SSH connections to Dropbear are protected by an additional layer of security.

4. **Change Default Ports**: Use non-standard ports for SSH to minimize the risk of unauthorized access.


By following these steps, you can set up remote decryption of your LUKS-encrypted root filesystem, allowing you to unlock your server during boot without needing physical access.