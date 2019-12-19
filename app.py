"""
Tiny hello world service example
"""

import os
from flask import Flask

APP = Flask(__name__)  # Standard Flask app


@APP.route("/")
def hello():
    """
    Hello world on root path
    """
    return os.environ.get("MESSAGE", "Hello world!")


if __name__ == "__main__":
    APP.run(host='0.0.0.0', port=os.environ.get('listenport', 8080))
