import os
import hmac
import base64
import hashlib
from datetime import datetime
from flask import Flask, request

app = Flask(__name__)

MAX_AGE_SECONDS = int(os.getenv("MAX_REQUEST_AGE_SECONDS", 500))
BASE64_KEY = os.getenv("WEBHOOK_B64KEY")
PORT = int(os.getenv("PORT", 8000))


@app.route("/", methods=["POST"])
def webhook():
    signature = request.headers.get("webhook-signature")
    timestamp = request.headers.get("webhook-request-timestamp")
    if not signature or not timestamp:
        return "", 400
    if not verify_signature(
        signature, timestamp, request.get_data(), BASE64_KEY, MAX_AGE_SECONDS
    ):
        return "", 401
    return ""


def verify_signature(signatures, timestamp, payload, base64_key, max_age_seconds):
    try:
        age_seconds = (
            datetime.now().timestamp() - datetime.fromisoformat(timestamp).timestamp()
        )
    except:
        return False
    if age_seconds > max_age_seconds:
        return False

    key = base64.b64decode(base64_key)
    calculatedSignature = hmac.new(
        key, payload + ("." + timestamp).encode("utf-8"), hashlib.sha256
    ).digest()

    for signature in signatures.split(","):
        try:
            if hmac.compare_digest(calculatedSignature, bytes.fromhex(signature)):
                return True
        except:
            continue
    return False


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)
