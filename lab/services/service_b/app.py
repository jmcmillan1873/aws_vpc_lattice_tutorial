"""Service_B: A simple Flask app fronted by VPC Lattice.

This service does NOT inspect or enforce caller identity -
VPC Lattice handles auth before requests reach this container.
"""

import datetime
from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def hello():
    """Return a greeting with the current timestamp."""
    return jsonify(
        message="Hello from Service_B!",
        timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
