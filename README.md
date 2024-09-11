# Remote Decryption of LUKS Encrypted Device

## Root FileSystem Unlock

***Note that here, we aer talking about non-root filesystem*** to decrypt a root file system (used during boot) requires a different approach. 

See this [page for info on boot process](boot.md) and [this one on initramfs](initramfs.md). Lastly, see the [dropbear](dropbear.md) page.


## Non root FS

When dealing with a LUKS-encrypted drive, there are several methods to decrypt it remotely, though each method carries different levels of complexity and security considerations. 



Here are some common approaches, for non-root fs:


### 1. **SSH with Keyfile**
   - **Setup**: Store the LUKS keyfile on a remote server. After SSH-ing into the server, use the keyfile to decrypt the drive.
   - **Steps**:
     1. SSH into the remote machine.
     2. Use the `cryptsetup` command with the keyfile to unlock the encrypted drive:
        ```bash
        sudo cryptsetup luksOpen /dev/sdX encrypted_drive --key-file /path/to/keyfile
        ```
   - **Security**: Ensure secure SSH access and keep the keyfile on a secure remote server. The keyfile can be protected by additional encryption or access controls.

### 2. **Dropbear (SSH in Initramfs)**
   - **Setup**: Use Dropbear to access an encrypted system during the initramfs stage. This method is useful if the drive contains the root partition.
   - **Steps**:
     1. Install Dropbear and configure it to start during the initramfs phase.
     2. When the system is booting, Dropbear will provide SSH access before the root filesystem is mounted.
     3. SSH into the system and provide the LUKS passphrase manually or with a keyfile to decrypt the drive:
        ```bash
        cryptroot-unlock
        ```
   - **Security**: Since this allows remote unlocking during boot, strong SSH keys and network security practices are essential.

### 3. **Systemd-Ask-Pass via SSH**
   - **Setup**: Configure `systemd-ask-password` to accept a passphrase remotely when prompted during boot.
   - **Steps**:
     1. Enable SSH access and ensure the LUKS decryption prompt is set to accept passphrases from SSH sessions.
     2. After SSH-ing in, the system will prompt you for the LUKS passphrase using `systemd-ask-password`.
   - **Security**: You need a secure connection and system configuration, ensuring no unauthorized access to the decryption process.

### 4. **Custom Remote Unlock Daemon (via HTTP/SSH)**
   - **Setup**: Develop a custom service that listens for an encrypted passphrase via HTTP or another secure protocol (e.g., using a REST API).
   - **Steps**:
     1. Run a daemon on the remote system that listens for a passphrase submission.
     2. Upon receiving the passphrase, the daemon uses it to unlock the LUKS-encrypted drive:
        ```bash
        echo "passphrase" | sudo cryptsetup luksOpen /dev/sdX encrypted_drive
        ```
   - **Security**: This is custom-built and highly risky unless secured using proper encryption (SSL/TLS) and authentication mechanisms.

### 5. **Use Network-Attached Key Services**
   - **Setup**: Leverage solutions like **Tang** or **Clevis** that provide network-bound disk encryption (NBDE).
   - **Steps**:
     1. Setup a Tang server or any network-based key service.
     2. When the machine starts, it queries the Tang server for the decryption key to unlock the LUKS volume automatically.
   - **Security**: Tang and Clevis are built with security in mind, but the network must be secured to prevent unauthorized decryption.

After having installed Clevis, you can use [this script](scripts/clevis-luks-unlock.sh) to decrypt a device.

Each method requires careful consideration of security risks, especially when dealing with remote access and decryption over potentially insecure networks. 

Also, when dealing with a **ROOT FileSystem** device, it's not the same that with another device not relevant to booting the machine.


## Custom Remote Unlock Daemon

Creating a **Custom Remote Unlock Daemon** for decrypting LUKS-encrypted drives involves setting up a system service that listens for input (such as a passphrase) over a network and uses it to unlock the encrypted drive. This can be useful in scenarios where you want the decryption process to be triggered remotely, possibly with some automation, but it must be carefully secured to avoid unauthorized access.

Here's a breakdown of how this method works and how you can implement it securely:

### 1. **How it Works**
   - The daemon runs on the server, typically as a background process or systemd service.
   - It listens for a decryption passphrase or keyfile submission through a secure network protocol like HTTP, HTTPS, or SSH.
   - When the passphrase or keyfile is received, the daemon uses `cryptsetup` to unlock the LUKS-encrypted volume.
   - Once the drive is decrypted, it can be mounted and accessed normally by the operating system.

### 2. **Components of the Custom Daemon**
   - **Networking Component**: This can be a lightweight web server (like Flask, Node.js, or Nginx) or a custom SSH-based script that listens for incoming passphrases or keyfiles.
   - **Cryptsetup Command**: The core function of the daemon is to run the `cryptsetup luksOpen` command with the received passphrase or keyfile to unlock the LUKS drive.
   - **Security Features**: Ensuring the decryption process is secure requires SSL/TLS for HTTP-based services and strong authentication mechanisms for SSH. Additionally, firewalls and VPNs should be used to limit who can connect to the daemon.

### 3. **Implementation Example**

#### Using an HTTPS Server with Python Flask <a name="FlaskDeamon"></a>

Here’s an example of implementing the daemon using Flask with HTTPS:

```python
from flask import Flask, request
import subprocess
import os

app = Flask(__name__)

# Route to handle passphrase submission
@app.route('/unlock', methods=['POST'])
def unlock_drive():
    passphrase = request.form.get('passphrase')
    if passphrase:
        try:
            # Command to unlock LUKS drive
            cmd = ['sudo', 'cryptsetup', 'luksOpen', '/dev/sdX', 'encrypted_drive']
            process = subprocess.run(cmd, input=passphrase.encode(), check=True)
            return "Drive unlocked successfully!", 200
        except subprocess.CalledProcessError:
            return "Failed to unlock the drive", 500
    return "Passphrase missing", 400

# Running Flask server
if __name__ == '__main__':
    # Use SSL/TLS for security
    app.run(host='0.0.0.0', port=8007, ssl_context=('cert.pem', 'key.pem'))
```

Here's another example, [this script](scripts/unlock_daemon.py) to decrypt a device, hardcoded in the script.



#### Steps to Set It Up:
1. **Install Dependencies**:
   - You’ll need to install Python and Flask:
     ```bash
     sudo apt install python3 python3-pip
     pip3 install flask
     ```
   - Additionally, you'll need `cryptsetup` (already included in most Linux distributions).

2. **Generate SSL Certificates**:
   - You can generate self-signed SSL certificates (or use Let's Encrypt for production):
     ```bash
     openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout key.pem -out cert.pem
     ```
   - This ensures the connection is encrypted.

3. **Run the Daemon**:
   - Start the Python Flask app:
     ```bash
     sudo python3 unlock_daemon.py
     ```
   - This will run the Flask server, listening on port 8007 (leet for boot), and serve it over HTTPS.

4. **Submit Passphrase Remotely**:
   - On the client side, you can send the passphrase using a POST request:
     ```bash
     curl -k -X POST https://your-server-ip:8007/unlock -d "passphrase=yourLUKSpassword"
     ```
   - The server will receive the passphrase and attempt to unlock the LUKS drive.

#### Notes:
   - Replace `/dev/sdX` with the actual device name of your LUKS-encrypted drive.
   - For real-world usage, configure Flask to run behind a reverse proxy like Nginx or Apache, which can provide extra security.


### 4. **SSH-Based Approach**
If you prefer using SSH instead of HTTP, you could implement a custom unlock script that runs on the remote server, listening for a specific SSH command:

1. **Create an SSH Unlock Script**:
   ```bash
   #!/bin/bash
   read -s -p "Enter LUKS passphrase: " passphrase
   echo "$passphrase" | sudo cryptsetup luksOpen /dev/sdX encrypted_drive
   ```
   - Save this script as `unlock_drive.sh` on the remote server.
   
2. **Allow Remote Execution**:
   - You can set up SSH with public/private key authentication and restrict which commands can be run. For example, in the `.ssh/authorized_keys` file of the server, you can specify that this key can only run the unlock script:
     ```
     command="/path/to/unlock_drive.sh" ssh-rsa AAA... user@remote
     ```
   - This ensures the SSH key can only be used to unlock the drive and not for general access.

3. **Run the SSH Command**:
   - From a remote machine, you would run:
     ```bash
     ssh user@server_ip
     ```
   - The unlock script would prompt you for the LUKS passphrase, which will be used to decrypt the drive.

### 5. **Security Considerations**
   - **Encryption**: Always use HTTPS with SSL/TLS certificates for web-based solutions. If using SSH, ensure it is properly secured with key-based authentication.
   - **Access Control**: Limit the access to this service by IP whitelisting, VPNs, or firewall rules. Only trusted sources should be able to send decryption requests.
   - **Authentication**: For HTTP-based solutions, consider implementing additional authentication mechanisms such as API tokens or OAuth.
   - **Logs**: Do not log sensitive information like the passphrase. Ensure the logs are securely stored and accessible only to authorized personnel.
   - **Monitoring**: Regularly monitor the service for suspicious activity, and implement rate-limiting to prevent brute-force attacks.

### 6. **Benefits and Use Cases**
   - **Remote Unlocking**: Useful in cases where a remote server or system is rebooted and needs to be unlocked without physical access.
   - **Automation**: Can be integrated with larger systems that automate infrastructure management, especially in environments where encrypted volumes are frequently mounted or unmounted.

### 7. **Limitations**
   - **Security Risks**: Exposing a service that can decrypt sensitive data over a network can introduce significant risks, so this method should be used with caution.
   - **Complexity**: The daemon has to be properly secured and maintained to prevent unauthorized access.

This approach is flexible but requires careful planning around security to ensure the LUKS encryption is not easily compromised by external attackers.

## Running a Python Script as a Service - Systemd Service Creation

You can [create a service](Service.md) to handle the decryption of devices remotely. If you never created a systemd service, please read [this page](Service.md)

Creating a `systemd` service involves writing a service unit file and configuring it so that `systemd` can manage your service. Here's how you can create a custom service in Linux using `systemd`.

Here is an example of a `systemd` service for an HTTPS server that listens for a decryption passphrase. This server will run a Python Flask application, which listens on port 5000 and expects a decryption passphrase to unlock a LUKS-encrypted drive. 

Assume that you already have the [Flask app](#FlaskDeamon) (`/path/to/unlock_daemon.py`) with HTTPS set up.

### 1. **Create the Flask Service Unit File**

Create a `systemd` service file to manage the Flask HTTPS server.

1. Open a terminal and create a new service file:

   ```bash
   sudo nano /etc/systemd/system/flask-decrypt.service
   ```

2. Add the following content to the file, adjusting the paths as necessary for your Flask script and environment:

```ini
[Unit]
Description=Flask HTTPS Decryption Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /path/to/unlock_daemon.py
Restart=on-failure
User=youruser
WorkingDirectory=/path/to
Environment="FLASK_ENV=production"
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
```

#### Explanation of the Sections:
- **[Unit]**:
  - `Description`: Describes the service as a Flask HTTPS Decryption Service.
  - `After=network.target`: Ensures that the service starts after the network is up.

- **[Service]**:
  - `ExecStart`: Runs the Python Flask script (`unlock_daemon.py`).
  - `Restart=on-failure`: Automatically restarts the service if it crashes.
  - `User=youruser`: Runs the service as a specific user (replace `youruser` with the actual username you want to run the service as).
  - `WorkingDirectory`: Specifies the directory where the Flask script is located.
  - `Environment="FLASK_ENV=production"`: Sets the environment variable to run Flask in production mode.
  - `ExecReload`: Allows the service to reload gracefully when reloading the configuration.

- **[Install]**:
  - `WantedBy=multi-user.target`: This ensures that the service will run in multi-user mode (the typical mode for non-graphical servers).

### 2. **Reload `systemd` to Apply the New Service**

After creating the service file, reload the `systemd` configuration to make it aware of the new service:

```bash
sudo systemctl daemon-reload
```

### 3. **Start the Flask Decryption Service**

You can now start the service using the following command:

```bash
sudo systemctl start flask-decrypt
```

### 4. **Enable the Service to Start on Boot**

To ensure the service starts automatically on boot:

```bash
sudo systemctl enable flask-decrypt
```

### 5. **Check the Status of the Service**

To verify that the service is running:

```bash
systemctl status flask-decrypt
```

You should see output showing that the Flask HTTPS server is running and listening on the specified port (e.g., 5000).

### 6. **Logging and Troubleshooting**

To view logs for the service (in case of errors or issues):

```bash
journalctl -u flask-decrypt
```

This will show you the logs, including any issues the Flask app encounters while running.

### Flask Application Reminder
Ensure that your Flask app (`unlock_daemon.py`) is correctly configured to run as an HTTPS server. The Flask app should be something similar to this:

```python
from flask import Flask, request
import subprocess

app = Flask(__name__)

@app.route('/unlock', methods=['POST'])
def unlock():
    passphrase = request.form.get('passphrase')
    if passphrase:
        try:
            # Command to unlock the LUKS-encrypted drive
            cmd = ['sudo', 'cryptsetup', 'luksOpen', '/dev/sdX', 'encrypted_drive']
            subprocess.run(cmd, input=passphrase.encode(), check=True)
            return "Drive unlocked successfully!", 200
        except subprocess.CalledProcessError:
            return "Failed to unlock the drive", 500
    return "Passphrase missing", 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8007, ssl_context=('cert.pem', 'key.pem'))
```

Make sure your Flask application includes the correct SSL certificates (`cert.pem` and `key.pem`) for running the HTTPS server.

This example sets up a `systemd` service for an HTTPS Flask server that listens for a passphrase to decrypt a LUKS-encrypted drive and manages it just like any other service on the system.