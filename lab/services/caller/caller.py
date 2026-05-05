"""
Shared caller script for Service_A and Service_C.
Signs a GET request with SigV4 (service: vpc-lattice-svcs) and sends it
to the VPC Lattice endpoint. The IAM task role determines whether the
request is allowed (200) or denied (403).
"""

import os
import sys
import requests
from botocore.session import Session
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest


def main():
    # Read configuration from environment variables
    endpoint = os.environ.get("LATTICE_ENDPOINT")
    if not endpoint:
        print("ERROR: LATTICE_ENDPOINT environment variable is not set")
        sys.exit(1)

    region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")

    # Get credentials from the ECS task role (automatic via botocore)
    session = Session()
    credentials = session.get_credentials().get_frozen_credentials()

    # Build the request URL and required headers
    url = f"http://{endpoint}"
    headers = {"x-amz-content-sha256": "UNSIGNED-PAYLOAD"}
    aws_request = AWSRequest(method="GET", url=url, headers=headers)

    # Sign the request with SigV4 using vpc-lattice-svcs as the service name
    SigV4Auth(credentials, "vpc-lattice-svcs", region).add_auth(aws_request)

    # Send the signed request
    try:
        response = requests.get(url, headers=dict(aws_request.headers), timeout=30)
        print(f"Response status: {response.status_code}")
        print(f"Response body: {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"ERROR: Request failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
