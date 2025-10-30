import os
import json
from flask import Flask, render_template, jsonify
from collections import deque
import threading
import time
import logging

# Suppress Flask's default logging
logging.getLogger('werkzeug').setLevel(logging.ERROR)

app = Flask(__name__)
log_buffer = deque(maxlen=100)

LOG_FILE = os.getenv('LOG_FILE', '/var/log/containers/frontend-logs.log')

def parse_log(line):
	"""Parse OpenTelemetry JSON log format"""
	try:
		data = json.loads(line)
		for rl in data.get('resourceLogs', []):
			for sl in rl.get('scopeLogs', []):
				for record in sl.get('logRecords', []):
					body_str = record.get('body', {}).get('stringValue', '')
					body = json.loads(body_str)
					return body
		return {'message': line.strip()}
	except:
		return {'message': line.strip()}


def tail_log_file():
	"""Tail the log file and add new lines to buffer"""
	def follow(file):
		file.seek(0, 2)
		while True:
			line = file.readline()
			if not line:
				time.sleep(0.1)
				continue
			yield line

	while True:
		try:
			if os.path.exists(LOG_FILE):
				with open(LOG_FILE, 'r') as f:
					for line in follow(f):
						line = line.strip()
						if line:
							parsed_log = parse_log(line)
							log_buffer.append(parsed_log)
			else:
				time.sleep(5)
		except Exception:
			time.sleep(5)

threading.Thread(target=tail_log_file, daemon=True).start()

@app.route('/')
def index():
	return render_template('viewer.html')

@app.route('/api/logs')
def api_logs():
	return jsonify(list(log_buffer))

@app.route('/health')
def health():
	return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
	app.run(host='0.0.0.0', port=8081, debug=False)
