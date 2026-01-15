from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)

@app.route('/')
def home():
    """Ana sayfa - ortam bilgisi göster"""
    environment = os.getenv('ENVIRONMENT', 'unknown')
    hostname = socket.gethostname()

    return jsonify({
        'message': f'Merhaba! DevOps projene hoş geldin! 🚀',
        'environment': environment,
        'hostname': hostname,
        'status': 'healthy',
        'version': '1.0.0'
    })

@app.route('/health')
def health():
    """Kubernetes health check endpoint'i"""
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
