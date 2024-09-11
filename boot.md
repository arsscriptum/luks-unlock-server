# Unlocking the Root Filesystem

The service that handles unlocking the root filesystem on Linux systems when it is encrypted (typically with LUKS) is integrated into the **initramfs** system. Specifically, the relevant components and processes are:

### 1. **`cryptsetup` Integration in Initramfs**
When the root filesystem is encrypted using LUKS, the boot process involves an early userspace environment called **initramfs** (initial RAM filesystem). Inside this environment, the system uses **`cryptsetup`** (or related utilities) to unlock the encrypted root partition before transitioning to the actual root filesystem.

The service or process that manages unlocking the root filesystem in this early stage is typically integrated into the initramfs and doesn't rely on traditional `systemd` services at that point because `systemd` has not yet fully started.

### 2. **Key Components for Unlocking Root Filesystem**

- **`cryptsetup`**: This tool is responsible for unlocking the LUKS-encrypted partition.
- **`/etc/crypttab`**: This file defines encrypted block devices that need to be unlocked. It can specify which device to unlock and how to unlock it (e.g., using a passphrase, keyfile, or hardware security module).
- **`dracut` or `initramfs-tools`**: These tools generate the initramfs image, which contains `cryptsetup` and other necessary utilities for unlocking the root filesystem during early boot.
- **`systemd-cryptsetup`**: In `systemd`-based systems, once `systemd` starts during the boot process, it might manage the encrypted partitions using `systemd-cryptsetup` service for non-root encrypted filesystems. However, the root filesystem is generally handled within the initramfs.

### 3. **Unlocking Process During Boot**
The process typically follows these steps:

1. **Kernel Loads Initramfs**: When the system boots, the Linux kernel loads the initramfs image into memory, which contains a minimal environment needed to mount the root filesystem.

2. **`cryptsetup` in Initramfs**: Inside this environment, `cryptsetup` is used to prompt for a passphrase or retrieve a key to unlock the encrypted root partition.

3. **Mounting the Root Filesystem**: After successfully unlocking the root partition, it is mounted, and the boot process proceeds to transition to the full root filesystem.

4. **Handing Off to `systemd`**: Once the root filesystem is unlocked and mounted, the system hands control over to `systemd`, which continues booting the rest of the system.

### 4. **Configuring the Unlocking Process**

- **`/etc/crypttab`**: This file can be used to specify the encrypted partitions that need to be unlocked during boot. For the root partition, this is typically handled by the initramfs, but for other encrypted partitions, it might look something like this:

  ```ini
  root_encrypted UUID=your-root-partition-uuid none luks
  ```

  - `root_encrypted`: The name of the mapping (used by `cryptsetup`).
  - `UUID=your-root-partition-uuid`: The UUID of the encrypted device.
  - `none`: Indicates that no keyfile is being used (a passphrase will be prompted for).
  - `luks`: Specifies that LUKS encryption is being used.

- **Initramfs Configuration**: Depending on your distribution, the process of configuring initramfs to unlock the root partition is handled by tools like `initramfs-tools` (on Debian/Ubuntu) or `dracut` (on Fedora/Red Hat/CentOS). These tools ensure that `cryptsetup` is included in the initramfs image and can prompt for the passphrase during boot.

### 5. **Remote Unlocking of Root Filesystem**

In systems where remote unlocking of the root filesystem is needed (such as headless servers), a service like **Dropbear** or a similar SSH server is embedded into the initramfs. This allows you to SSH into the early boot environment and provide the LUKS passphrase remotely.

The process typically involves:
- Embedding a minimal SSH server (like Dropbear) in the initramfs.
- SSH-ing into the system during boot and providing the passphrase to unlock the root filesystem.

### 6. **`systemd` Services Related to Cryptsetup**
Once the root filesystem is unlocked and the system has fully booted, `systemd` manages other encrypted partitions using the `systemd-cryptsetup@.service`. This service is responsible for managing LUKS devices that are defined in `/etc/crypttab`.

For example, if you have additional encrypted filesystems (besides the root filesystem), `systemd` will manage them via this service:

```bash
systemctl status systemd-cryptsetup@<device-name>
```

### Summary
The service that unlocks the **root filesystem** is generally not a traditional `systemd` service but part of the **initramfs** process. The unlocking is handled by `cryptsetup` and integrated into the boot process via initramfs, where it prompts for a passphrase or retrieves a key to unlock the root partition before handing control over to `systemd`.