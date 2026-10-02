from __future__ import annotations

import base64
import json

from clearwing.providers.openai_oauth import (
    OPENAI_AUTH_JWT_CLAIM_PATH,
    build_authorize_url,
    credentials_from_value,
    extract_account_id,
    generate_pkce,
    parse_authorization_input,
)


def _b64url(obj) -> str:
    raw = json.dumps(obj, separators=(",", ":"), sort_keys=True).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _fake_jwt(payload: dict) -> str:
    header = {"alg": "none", "typ": "JWT"}
    return f"{_b64url(header)}.{_b64url(payload)}.sig"


def test_generate_pkce_lengths():
    verifier, challenge = generate_pkce()
    assert 43 <= len(verifier) <= 128
    assert challenge


def test_build_authorize_url_contains_expected_params():
    url = build_authorize_url(challenge="CHALLENGE", state="STATE")
    assert "auth.openai.com/oauth/authorize" in url
    assert "code_challenge=CHALLENGE" in url
    assert "state=STATE" in url
    assert "codex_cli_simplified_flow=true" in url


def test_parse_authorization_input_url():
    code, state = parse_authorization_input("http://localhost:1455/auth/callback?code=abc&state=xyz")
    assert code == "abc"
    assert state == "xyz"


def test_parse_authorization_input_hash():
    code, state = parse_authorization_input("abc#xyz")
    assert code == "abc"
    assert state == "xyz"


def test_parse_authorization_input_querystring():
    code, state = parse_authorization_input("code=abc&state=xyz")
    assert code == "abc"
    assert state == "xyz"


def test_parse_authorization_input_raw_code():
    code, state = parse_authorization_input("abc")
    assert code == "abc"
    assert state is None


def test_extract_account_id_from_jwt():
    token = _fake_jwt({OPENAI_AUTH_JWT_CLAIM_PATH: {"chatgpt_account_id": "acct_123"}})
    assert extract_account_id(token) == "acct_123"


def test_credentials_from_legacy_shape_accepts_account_id():
    token = _fake_jwt({OPENAI_AUTH_JWT_CLAIM_PATH: {"chatgpt_account_id": "acct_123"}})
    creds = credentials_from_value(
        {
            "access": token,
            "refresh": "r",
            "expires": 123,
            "accountId": "acct_123",
        }
    )
    assert creds is not None
    assert creds.account_id == "acct_123"
