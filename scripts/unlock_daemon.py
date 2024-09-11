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
            cmd = ['cryptsetup', 'luksOpen', '/dev/sda3', 'encrypted_drive']
            process = subprocess.run(cmd, input=passphrase.encode(), check=True)
            return "Drive unlocked successfully!", 200
        except subprocess.CalledProcessError:
            return "Failed to unlock the drive", 500
    return "Passphrase missing", 400

# Running Flask server
if __name__ == '__main__':
    # Use SSL/TLS for security
    app.run(host='0.0.0.0', port=5000, ssl_context=('/srv/scripts/certs/cert.pem', '/srv/scripts/certs/key.pem'))
