"""
Shared caller for Service_A and Service_C.
Generates a JWT with configurable subject and calls Service_B.
CALLER_SUBJECT env var determines identity (service-a or service-c).
"""
import os, sys, time
import jwt, requests

def main():
    # Validate required environment variables
    secret = os.environ.get("JWT_SECRET")
    if not secret:
        print("ERROR: JWT_SECRET not set"); sys.exit(1)
    subject = os.environ.get("CALLER_SUBJECT")
    if not subject:
        print("ERROR: CALLER_SUBJECT not set"); sys.exit(1)
    url = os.environ.get("SERVICE_B_URL")
    if not url:
        print("ERROR: SERVICE_B_URL not set"); sys.exit(1)

    # Generate JWT: iss=mock-idp, sub=<caller>, aud=service-b, exp=now+5min
    token = jwt.encode(
        {"iss": "mock-idp", "sub": subject, "aud": "service-b",
         "exp": int(time.time()) + 300},
        secret, algorithm="HS256"
    )

    # Send GET request to Service_B with Bearer token
    try:
        resp = requests.get(url, headers={"Authorization": f"Bearer {token}"}, timeout=5)
    except requests.exceptions.Timeout:
        print("NETWORK ERROR: Connection timed out"); sys.exit(1)
    except requests.exceptions.ConnectionError as e:
        msg = "Connection refused" if "refused" in str(e).lower() else str(e)
        print(f"NETWORK ERROR: {msg}"); sys.exit(1)

    # Log result — distinguish auth success from denial
    if resp.status_code == 200:
        print(f"AUTH SUCCESS: status=200 body={resp.text}")
    else:
        print(f"AUTH DENIED: status={resp.status_code} body={resp.text}")

if __name__ == "__main__":
    main()
