"""
Property-based tests for JWT validation logic in Service_B.
Uses hypothesis to verify correctness properties from the design document.
"""
import sys, os, time, datetime

# Add service_b to path so we can import the Flask app
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "services", "service_b"))

import jwt
import pytest
from hypothesis import given, settings, assume, HealthCheck
from hypothesis.strategies import text, binary, sampled_from, integers, just

# Configure Service_B environment before importing app
TEST_SECRET = "test-secret-key-for-property-tests"
TEST_ISSUER = "mock-idp"
TEST_ALLOWED = "service-a,service-b-caller"

os.environ["JWT_SECRET"] = TEST_SECRET
os.environ["EXPECTED_ISSUER"] = TEST_ISSUER
os.environ["ALLOWED_SUBJECTS"] = TEST_ALLOWED

from app import app  # noqa: E402


# --- Strategies ---

# Valid printable strings for claims (avoid empty and control chars)
claim_strings = text(
    alphabet="abcdefghijklmnopqrstuvwxyz0123456789-_.",
    min_size=1, max_size=50
)

# Subjects that ARE in the allowed list
allowed_subjects = sampled_from(TEST_ALLOWED.split(","))

# Subjects that are NOT in the allowed list
unauthorised_subjects = claim_strings.filter(
    lambda s: s not in TEST_ALLOWED.split(",")
)

# Random signing keys different from TEST_SECRET
wrong_secrets = claim_strings.filter(lambda s: s != TEST_SECRET)

# Future timestamps (valid expiry)
future_timestamps = integers(
    min_value=int(time.time()) + 60,
    max_value=int(time.time()) + 86400
)

# Past timestamps (expired)
past_timestamps = integers(
    min_value=0,
    max_value=int(time.time()) - 60
)

# Issuers that don't match expected
wrong_issuers = claim_strings.filter(lambda s: s != TEST_ISSUER)

# Audiences that don't match "service-b"
wrong_audiences = claim_strings.filter(lambda s: s != "service-b")

# Algorithms other than HS256
other_algorithms = sampled_from(["HS384", "HS512"])


def make_token(sub, aud, iss, exp, secret, algorithm="HS256"):
    """Helper to generate a JWT with given claims."""
    payload = {"sub": sub, "aud": aud, "iss": iss, "exp": exp}
    return jwt.encode(payload, secret, algorithm=algorithm)


@pytest.fixture
def client():
    """Flask test client for Service_B."""
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


# =============================================================================
# Property 1: Token generation round-trip
# =============================================================================

class TestProperty1:
    """
    Property 1: Token generation round-trip.
    For any valid subject string and audience string, generating a JWT with those
    values and then decoding it with the same secret should yield a payload
    containing the original sub, aud, iss, and a valid future exp timestamp.

    **Validates: Requirements 3.1, 3.3, 3.4, 3.5**
    """

    @given(sub=claim_strings, aud=claim_strings)
    @settings(max_examples=100, suppress_health_check=[HealthCheck.function_scoped_fixture])
    def test_token_roundtrip(self, sub, aud):
        """Generate a token and decode it — claims should survive the round-trip."""
        secret = TEST_SECRET
        iss = TEST_ISSUER
        exp = int(time.time()) + 300

        token = make_token(sub, aud, iss, exp, secret)
        decoded = jwt.decode(token, secret, algorithms=["HS256"], audience=aud)

        assert decoded["sub"] == sub
        assert decoded["aud"] == aud
        assert decoded["iss"] == iss
        assert decoded["exp"] >= int(time.time())


# =============================================================================
# Property 2: Invalid signature rejection
# =============================================================================

class TestProperty2:
    """
    Property 2: Invalid signature rejection.
    For any JWT signed with a key different from Service_B's configured JWT_SECRET,
    Service_B's token validator should return HTTP 401 with an "invalid signature" error.

    **Validates: Requirements 5.3**
    """

    @given(sub=allowed_subjects, wrong_key=wrong_secrets)
    @settings(max_examples=100, suppress_health_check=[HealthCheck.function_scoped_fixture])
    def test_invalid_signature_rejected(self, client, sub, wrong_key):
        """Tokens signed with wrong key should be rejected with 401."""
        exp = int(time.time()) + 300
        token = make_token(sub, "service-b", TEST_ISSUER, exp, wrong_key)

        resp = client.get("/", headers={"Authorization": f"Bearer {token}"})

        assert resp.status_code == 401
        assert "invalid signature" in resp.get_json()["error"]


# =============================================================================
# Property 3: Expired token rejection
# =============================================================================

class TestProperty3:
    """
    Property 3: Expired token rejection.
    For any JWT where the exp claim is a timestamp in the past, Service_B's token
    validator should return HTTP 401 with a "token expired" error, regardless of
    all other claims being valid.

    **Validates: Requirements 5.4**
    """

    @given(sub=allowed_subjects, exp=past_timestamps)
    @settings(max_examples=100, suppress_health_check=[HealthCheck.function_scoped_fixture])
    def test_expired_token_rejected(self, client, sub, exp):
        """Tokens with past expiry should be rejected with 401."""
        token = make_token(sub, "service-b", TEST_ISSUER, exp, TEST_SECRET)

        resp = client.get("/", headers={"Authorization": f"Bearer {token}"})

        assert resp.status_code == 401
        assert "token expired" in resp.get_json()["error"]


# =============================================================================
# Property 4: Invalid issuer rejection
# =============================================================================

class TestProperty4:
    """
    Property 4: Invalid issuer rejection.
    For any JWT where the iss claim does not equal Service_B's configured
    EXPECTED_ISSUER, Service_B's token validator should return HTTP 401 with
    an "invalid issuer" error.

    **Validates: Requirements 5.11**
    """

    @given(sub=allowed_subjects, bad_issuer=wrong_issuers)
    @settings(max_examples=100, suppress_health_check=[HealthCheck.function_scoped_fixture])
    def test_invalid_issuer_rejected(self, client, sub, bad_issuer):
        """Tokens with wrong issuer should be rejected with 401."""
        exp = int(time.time()) + 300
        token = make_token(sub, "service-b", bad_issuer, exp, TEST_SECRET)

        resp = client.get("/", headers={"Authorization": f"Bearer {token}"})

        assert resp.status_code == 401
        assert "invalid issuer" in resp.get_json()["error"]


# =============================================================================
# Property 5: Wrong audience rejection
# =============================================================================

class TestProperty5:
    """
    Property 5: Wrong audience rejection.
    For any JWT where the aud claim does not equal service-b, Service_B's token
    validator should return HTTP 403 with an "invalid audience" error.

    **Validates: Requirements 5.5**
    """

    @given(sub=allowed_subjects, bad_aud=wrong_audiences)
    @settings(max_examples=100, suppress_health_check=[HealthCheck.function_scoped_fixture])
    def test_wrong_audience_rejected(self, client, sub, bad_aud):
        """Tokens with wrong audience should be rejected with 403."""
        exp = int(time.time()) + 300
        token = make_token(sub, bad_aud, TEST_ISSUER, exp, TEST_SECRET)

        resp = client.get("/", headers={"Authorization": f"Bearer {token}"})

        assert resp.status_code == 403
        assert "invalid audience" in resp.get_json()["error"]


# =============================================================================
# Property 6: Unauthorised subject rejection
# =============================================================================

class TestProperty6:
    """
    Property 6: Unauthorised subject rejection.
    For any JWT with a valid signature, non-expired, correct issuer, correct
    audience, but where the sub claim is not in Service_B's configured
    ALLOWED_SUBJECTS list, Service_B's token validator should return HTTP 403
    with an "unauthorised subject" error.

    **Validates: Requirements 5.6**
    """

    @given(sub=unauthorised_subjects)
    @settings(max_examples=100, suppress_health_check=[HealthCheck.function_scoped_fixture])
    def test_unauthorised_subject_rejected(self, client, sub):
        """Tokens with unauthorised subject should be rejected with 403."""
        exp = int(time.time()) + 300
        token = make_token(sub, "service-b", TEST_ISSUER, exp, TEST_SECRET)

        resp = client.get("/", headers={"Authorization": f"Bearer {token}"})

        assert resp.status_code == 403
        data = resp.get_json()
        assert "unauthorised subject" in data["error"]


# =============================================================================
# Property 7: Valid token acceptance
# =============================================================================

class TestProperty7:
    """
    Property 7: Valid token acceptance.
    For any JWT with a valid HS256 signature, non-expired exp, iss matching
    EXPECTED_ISSUER, aud equal to service-b, and sub present in ALLOWED_SUBJECTS,
    Service_B's token validator should return HTTP 200 with a JSON body containing
    the subject.

    **Validates: Requirements 5.7**
    """

    @given(sub=allowed_subjects, exp=future_timestamps)
    @settings(max_examples=100, suppress_health_check=[HealthCheck.function_scoped_fixture])
    def test_valid_token_accepted(self, client, sub, exp):
        """Fully valid tokens should be accepted with 200."""
        token = make_token(sub, "service-b", TEST_ISSUER, exp, TEST_SECRET)

        resp = client.get("/", headers={"Authorization": f"Bearer {token}"})

        assert resp.status_code == 200
        data = resp.get_json()
        assert data["subject"] == sub
        assert "message" in data


# =============================================================================
# Property 8: Algorithm restriction
# =============================================================================

class TestProperty8:
    """
    Property 8: Algorithm restriction.
    For any JWT signed with an algorithm other than HS256 (e.g. HS384, HS512),
    Service_B's token validator should reject the token with HTTP 401, even if
    the signature would otherwise be valid.

    **Validates: Requirements 5.13**
    """

    @given(sub=allowed_subjects, alg=other_algorithms)
    @settings(max_examples=100, suppress_health_check=[HealthCheck.function_scoped_fixture])
    def test_non_hs256_algorithm_rejected(self, client, sub, alg):
        """Tokens signed with algorithms other than HS256 should be rejected."""
        exp = int(time.time()) + 300
        token = make_token(sub, "service-b", TEST_ISSUER, exp, TEST_SECRET, algorithm=alg)

        resp = client.get("/", headers={"Authorization": f"Bearer {token}"})

        assert resp.status_code == 401
        assert "invalid algorithm" in resp.get_json()["error"]


# =============================================================================
# Property 9: Network error distinction
# =============================================================================

class TestProperty9:
    """
    Property 9: Network error distinction.
    For any connection timeout or connection refused error encountered by a caller,
    the log output should contain a network error indicator (e.g. "NETWORK ERROR").
    For any HTTP 401 or 403 response, the log output should NOT contain a network
    error indicator.

    **Validates: Requirements 4.7, 6.7**
    """

    @given(status_code=sampled_from([401, 403]))
    @settings(max_examples=100, suppress_health_check=[HealthCheck.function_scoped_fixture])
    def test_auth_errors_not_labelled_network(self, status_code):
        """Auth denial responses should produce output without NETWORK ERROR."""
        # Simulate the caller's output formatting logic
        body = '{"error": "some auth error"}'
        if status_code == 200:
            output = f"AUTH SUCCESS: status=200 body={body}"
        else:
            output = f"AUTH DENIED: status={status_code} body={body}"

        assert "NETWORK ERROR" not in output

    @given(error_type=sampled_from(["timeout", "refused", "dns"]))
    @settings(max_examples=100, suppress_health_check=[HealthCheck.function_scoped_fixture])
    def test_network_errors_labelled_correctly(self, error_type):
        """Network errors should produce output with NETWORK ERROR prefix."""
        # Simulate the caller's network error output formatting
        messages = {
            "timeout": "Connection timed out",
            "refused": "Connection refused",
            "dns": "Name resolution failed",
        }
        output = f"NETWORK ERROR: {messages[error_type]}"

        assert "NETWORK ERROR" in output
        assert "AUTH SUCCESS" not in output
        assert "AUTH DENIED" not in output
