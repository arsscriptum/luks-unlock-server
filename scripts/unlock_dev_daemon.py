from flask import Flask, request, jsonify
import subprocess

app = Flask(__name__)

@app.route('/unlock', methods=['POST'])
def unlock():
    # Get the device path and passphrase from the request
    device_path = request.form.get('device_path')
    passphrase = request.form.get('passphrase')

    # You can also accept JSON payloads like this:
    # data = request.get_json()
    # device_path = data.get('device_path')
    # passphrase = data.get('passphrase')

    if not device_path or not passphrase:
        return jsonify({"error": "Device path and passphrase are required"}), 400

    try:
        # Command to unlock the LUKS-encrypted device
        cmd = ['sudo', 'cryptsetup', 'luksOpen', device_path, 'encrypted_device']
        subprocess.run(cmd, input=passphrase.encode(), check=True)
        return jsonify({"message": f"Device {device_path} unlocked successfully!"}), 200
    except subprocess.CalledProcessError as e:
        return jsonify({"error": str(e), "message": "Failed to unlock the device"}), 500

if __name__ == '__main__':
     app.run(host='0.0.0.0', port=8007, ssl_context=('/srv/scripts/certs/cert.pem', '/srv/scripts/certs/key.pem'))
