#!/usr/bin/env python3
"""
IPMI Sidecar API - A lightweight HTTP API for controlling servers via IPMI.

This service provides a simple REST API for Home Assistant to control
SuperMicro servers using ipmitool without needing to install it in the
Home Assistant container.
"""

import os
import subprocess
import logging
from functools import wraps
from flask import Flask, request, jsonify

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration from environment variables
API_KEY = os.environ.get('API_KEY', '')
BMC_HOST = os.environ.get('BMC_HOST', '')
BMC_USER = os.environ.get('BMC_USER', '')
BMC_PASSWORD = os.environ.get('BMC_PASSWORD', '')
BMC_CIPHER_SUITE = os.environ.get('BMC_CIPHER_SUITE', '3')

# Validate required configuration
if not all([API_KEY, BMC_HOST, BMC_USER, BMC_PASSWORD]):
    logger.error("Missing required environment variables: API_KEY, BMC_HOST, BMC_USER, BMC_PASSWORD")


def require_api_key(f):
    """Decorator to require API key authentication."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        provided_key = request.headers.get('X-API-Key')
        if not provided_key or provided_key != API_KEY:
            logger.warning(f"Unauthorized access attempt from {request.remote_addr}")
            return jsonify({
                'success': False,
                'error': 'Invalid or missing API key'
            }), 401
        return f(*args, **kwargs)
    return decorated_function


def run_ipmi_command(command):
    """
    Execute an IPMI command and return the result.
    
    Args:
        command: The IPMI command to execute (e.g., 'power on', 'power status')
    
    Returns:
        dict: Result containing success status and output/error message
    """
    try:
        # Build the ipmitool command
        cmd = [
            'ipmitool',
            '-I', 'lanplus',
            '-H', BMC_HOST,
            '-U', BMC_USER,
            '-P', BMC_PASSWORD,
            '-C', BMC_CIPHER_SUITE
        ] + command.split()
        
        logger.info(f"Executing IPMI command: {' '.join(cmd[:7])} [credentials hidden]")
        
        # Execute the command
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            logger.info(f"IPMI command successful: {result.stdout.strip()}")
            return {
                'success': True,
                'output': result.stdout.strip(),
                'command': command
            }
        else:
            logger.error(f"IPMI command failed: {result.stderr.strip()}")
            return {
                'success': False,
                'error': result.stderr.strip(),
                'command': command
            }
            
    except subprocess.TimeoutExpired:
        logger.error(f"IPMI command timed out: {command}")
        return {
            'success': False,
            'error': 'Command timed out after 10 seconds',
            'command': command
        }
    except Exception as e:
        logger.error(f"Error executing IPMI command: {str(e)}")
        return {
            'success': False,
            'error': str(e),
            'command': command
        }


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'service': 'ipmi-sidecar'
    }), 200


@app.route('/power/status', methods=['GET'])
@require_api_key
def power_status():
    """Get the current power status of the server."""
    result = run_ipmi_command('power status')
    
    if result['success']:
        # Parse the output to determine if power is on or off
        output = result['output'].lower()
        if 'on' in output:
            state = 'on'
        elif 'off' in output:
            state = 'off'
        else:
            state = 'unknown'
        
        return jsonify({
            'success': True,
            'power_state': state,
            'raw_output': result['output']
        }), 200
    else:
        return jsonify(result), 500


@app.route('/power/on', methods=['POST'])
@require_api_key
def power_on():
    """Turn on the server."""
    result = run_ipmi_command('power on')
    
    if result['success']:
        return jsonify(result), 200
    else:
        return jsonify(result), 500


@app.route('/power/off', methods=['POST'])
@require_api_key
def power_off():
    """Turn off the server (graceful shutdown)."""
    result = run_ipmi_command('power soft')
    
    if result['success']:
        return jsonify(result), 200
    else:
        return jsonify(result), 500


@app.route('/power/force-off', methods=['POST'])
@require_api_key
def power_force_off():
    """Force power off the server (hard shutdown)."""
    result = run_ipmi_command('power off')
    
    if result['success']:
        return jsonify(result), 200
    else:
        return jsonify(result), 500


@app.route('/power/cycle', methods=['POST'])
@require_api_key
def power_cycle():
    """Power cycle the server."""
    result = run_ipmi_command('power cycle')
    
    if result['success']:
        return jsonify(result), 200
    else:
        return jsonify(result), 500


@app.route('/power/reset', methods=['POST'])
@require_api_key
def power_reset():
    """Reset the server."""
    result = run_ipmi_command('power reset')
    
    if result['success']:
        return jsonify(result), 200
    else:
        return jsonify(result), 500


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return jsonify({
        'success': False,
        'error': 'Endpoint not found'
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors."""
    return jsonify({
        'success': False,
        'error': 'Internal server error'
    }), 500


if __name__ == '__main__':
    # Run with gunicorn in production, or Flask dev server for local testing
    if os.environ.get('FLASK_ENV') == 'development':
        app.run(host='0.0.0.0', port=8080, debug=True)
    else:
        # For production, use gunicorn
        from gunicorn.app.base import BaseApplication
        
        class StandaloneApplication(BaseApplication):
            def __init__(self, app, options=None):
                self.options = options or {}
                self.application = app
                super().__init__()
            
            def load_config(self):
                for key, value in self.options.items():
                    self.cfg.set(key.lower(), value)
            
            def load(self):
                return self.application
        
        options = {
            'bind': '0.0.0.0:8080',
            'workers': 2,
            'loglevel': 'info',
            'accesslog': '-',
            'errorlog': '-',
        }
        
        logger.info("Starting IPMI Sidecar API with Gunicorn")
        StandaloneApplication(app, options).run()
