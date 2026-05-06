"""Service_B: Flask app with JWT validation. Verifies HS256 signature,
issuer, audience, expiry, and subject against an allowed list."""
import os, datetime
from flask import Flask, request, jsonify
import jwt

app = Flask(__name__)
SECRET = os.environ.get("JWT_SECRET", "")
ALLOWED = os.environ.get("ALLOWED_SUBJECTS", "").split(",")
ISSUER = os.environ.get("EXPECTED_ISSUER", "mock-idp")

@app.route("/")
def handle():
    # Extract token from Authorization: Bearer <token> header
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        print("DENIED: no auth header")
        return jsonify(error="missing authorization header"), 401
    token = auth.split(" ", 1)[1]
    # Verify HS256 signature, expiry, issuer, and audience claims
    try:
        payload = jwt.decode(token, SECRET, algorithms=["HS256"],
                             audience="service-b", issuer=ISSUER)
    except jwt.InvalidAlgorithmError:
        print("DENIED: invalid algorithm")
        return jsonify(error="invalid algorithm"), 401
    except jwt.InvalidSignatureError:
        print("DENIED: invalid signature")
        return jsonify(error="invalid signature"), 401
    except jwt.ExpiredSignatureError:
        print("DENIED: token expired")
        return jsonify(error="token expired"), 401
    except jwt.InvalidIssuerError:
        print("DENIED: invalid issuer")
        return jsonify(error="invalid issuer"), 401
    except jwt.InvalidAudienceError:
        print("DENIED: invalid audience")
        return jsonify(error="invalid audience"), 403
    # Check subject is in the allowed list
    sub = payload.get("sub", "")
    if sub not in ALLOWED:
        print(f"DENIED: unauthorised subject={sub}")
        return jsonify(error="unauthorised subject", subject=sub), 403
    # Success — return greeting with subject and timestamp
    print(f"ACCEPTED: subject={sub}")
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    return jsonify(message="Hello from Service_B!", subject=sub, timestamp=now)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
