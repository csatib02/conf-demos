import json
import logging
import random
from datetime import datetime, timezone
from flask import Flask, render_template, jsonify, request
from prometheus_client import Counter, CollectorRegistry, generate_latest, CONTENT_TYPE_LATEST

# Suppress Flask's default logging
logging.getLogger('werkzeug').setLevel(logging.ERROR)

logging.basicConfig(
	level=logging.INFO,
	format='%(message)s'
)
logger = logging.getLogger(__name__)


app = Flask(__name__)

MALFUNCTION_RATE = 0.1

registry = CollectorRegistry()

button_clicks_total = Counter(
	'button_clicks_total',
	'Total number of all button clicks',
	registry=registry,
)

green_button_clicks_total = Counter(
	'green_button_clicks_total',
	'Total number of green button clicks',
	registry=registry,
)

blue_button_clicks_total = Counter(
	'blue_button_clicks_total',
	'Total number of blue button clicks',
	registry=registry,
)

MALFUNCTION_MESSAGES = [
	"Error 418: I'm a teapot, not a button! 🫖",
	"The button got stage fright 😰",
	"Button.exe has stopped working 🤖",
	"This button is currently napping 💤",
	"Cosmic rays interfered with the button! 🌟",
	"The button is experiencing an existential crisis 🤔"
]

def log(variant, status_code, message=""):
	"""Create a structured JSON log entry"""
	log_entry = {
		"timestamp": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
		"level": "INFO" if status_code == 200 else "ERROR",
		"event": "button_click",
		"variant": variant,
		"status_code": status_code,
		"client_ip": request.remote_addr,
		"user_agent": request.headers.get('User-Agent', 'Unknown'),
		"message": message
	}
	logger.info(json.dumps(log_entry))
	return log_entry

@app.route('/')
def index():
	return render_template('index.html')

@app.route('/api/click/<variant>')
def handle_click(variant):
	button_clicks_total.inc()

	if variant not in ['green', 'blue']:
		return jsonify({"error": "Invalid variant"}), 400

	if random.random() < MALFUNCTION_RATE:
		malfunction_message = random.choice(MALFUNCTION_MESSAGES)
		log(variant, 500, f"Malfunction: {malfunction_message}")
		return jsonify({
			"success": False,
			"malfunction": True,
			"message": malfunction_message
		}), 500
	log(variant, 200, f"Successful {variant} button click")

	if variant == 'green':
		green_button_clicks_total.inc()
	elif variant == 'blue':
		blue_button_clicks_total.inc()

	return jsonify({
		"success": True,
		"variant": variant,
		"message": f"You clicked the {variant} button!"
	}), 200

@app.route('/health')
def health():
	return jsonify({"status": "healthy"}), 200

@app.route('/metrics')
def metrics():
	return generate_latest(registry), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
	app.run(host='0.0.0.0', port=8080, debug=False)
