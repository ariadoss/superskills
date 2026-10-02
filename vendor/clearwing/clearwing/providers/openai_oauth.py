"""OpenAI ChatGPT/Codex OAuth support.

This mirrors the ChatGPT subscription OAuth flow used by the Codex CLI:
browser PKCE login on localhost, refresh-token persistence under
``~/.clearwing/auth/``, and authenticated calls to the ChatGPT backend API.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import queue
import secrets
import socket
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from collections.abc import Generator
from contextlib import contextmanager
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from socketserver import TCPServer
from typing import Any

try:
    import fcntl
except ImportError:  # pragma: no cover - non-Unix fallback
    fcntl = None  # type: ignore[assignment]


OPENAI_CODEX_CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"
OPENAI_CODEX_AUTHORIZE_URL = "https://auth.openai.com/oauth/authorize"
OPENAI_CODEX_TOKEN_URL = "https://auth.openai.com/oauth/token"  # noqa: S105
OPENAI_CODEX_REDIRECT_URI = "http://localhost:1455/auth/callback"
OPENAI_CODEX_CALLBACK_PORT = 1455
OPENAI_CODEX_CALLBACK_PATH = "/auth/callback"
OPENAI_CODEX_SCOPE = "openid profile email offline_access"
OPENAI_CODEX_ORIGINATOR = "pi"
OPENAI_CODEX_DEFAULT_BASE_URL = "https://chatgpt.com/backend-api"
OPENAI_CODEX_DEFAULT_MODEL = "gpt-5.2"
OPENAI_CODEX_OAUTH_CONFIG_KEY = "oauth.openai_codex"
OPENAI_AUTH_JWT_CLAIM_PATH = "https://api.openai.com/auth"

from clearwing.core.config import clearwing_home

AUTH_DIR = clearwing_home() / "auth"


@dataclass(frozen=True)
class OpenAIOAuthCredentials:
    access: str
    refresh: str
    expires_ms: int
    account_id: str


def _b64url_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64url_decode(raw: str) -> bytes:
    s = (raw or "").strip()
    if not s:
        return b""
    pad = "=" * ((4 - (len(s) % 4)) % 4)
    return base64.urlsafe_b64decode(s + pad)


def generate_pkce() -> tuple[str, str]:
    verifier = _b64url_encode(secrets.token_bytes(32))
    challenge = _b64url_encode(hashlib.sha256(verifier.encode("utf-8")).digest())
    return verifier, challenge


def create_state() -> str:
    return secrets.token_hex(16)


def build_authorize_url(
    *,
    challenge: str,
    state: str,
    redirect_uri: str = OPENAI_CODEX_REDIRECT_URI,
    originator: str = OPENAI_CODEX_ORIGINATOR,
) -> str:
    params = {
        "response_type": "code",
        "client_id": OPENAI_CODEX_CLIENT_ID,
        "redirect_uri": redirect_uri,
        "scope": OPENAI_CODEX_SCOPE,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        "state": state,
        "id_token_add_organizations": "true",
        "codex_cli_simplified_flow": "true",
        "originator": originator,
    }
    return f"{OPENAI_CODEX_AUTHORIZE_URL}?{urllib.parse.urlencode(params)}"


def parse_authorization_input(value: str) -> tuple[str | None, str | None]:
    """Accept a full callback URL, ``code#state``, query string, or raw code."""
    v = (value or "").strip()
    if not v:
        return None, None

    parsed = urllib.parse.urlparse(v)
    if parsed.scheme and parsed.netloc:
        qs = urllib.parse.parse_qs(parsed.query)
        return (qs.get("code") or [None])[0], (qs.get("state") or [None])[0]

    if "#" in v:
        code, st = v.split("#", 1)
        return code or None, st or None

    if "code=" in v:
        qs = urllib.parse.parse_qs(v)
        return (qs.get("code") or [None])[0], (qs.get("state") or [None])[0]

    return v, None


def decode_jwt_payload(token: str) -> dict[str, Any] | None:
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None
        return json.loads(_b64url_decode(parts[1]).decode("utf-8"))
    except Exception:
        return None


def extract_account_id(access_token: str) -> str | None:
    payload = decode_jwt_payload(access_token)
    auth = payload.get(OPENAI_AUTH_JWT_CLAIM_PATH) if isinstance(payload, dict) else None
    account_id = auth.get("chatgpt_account_id") if isinstance(auth, dict) else None
    return account_id if isinstance(account_id, str) and account_id else None


def _post_form(url: str, data: dict[str, str]) -> dict[str, Any]:
    body = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenAI OAuth token request failed: HTTP {exc.code}: {detail}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"OpenAI OAuth token request failed: {exc}") from exc
    return json.loads(raw)


def exchange_authorization_code(
    *,
    code: str,
    verifier: str,
    redirect_uri: str = OPENAI_CODEX_REDIRECT_URI,
) -> OpenAIOAuthCredentials:
    data = _post_form(
        OPENAI_CODEX_TOKEN_URL,
        {
            "grant_type": "authorization_code",
            "client_id": OPENAI_CODEX_CLIENT_ID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": redirect_uri,
        },
    )
    return _credentials_from_token_response(data, "exchange")


def refresh_openai_oauth_token(refresh_token: str) -> OpenAIOAuthCredentials:
    data = _post_form(
        OPENAI_CODEX_TOKEN_URL,
        {
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "client_id": OPENAI_CODEX_CLIENT_ID,
        },
    )
    return _credentials_from_token_response(data, "refresh")


def _credentials_from_token_response(data: dict[str, Any], label: str) -> OpenAIOAuthCredentials:
    access = data.get("access_token")
    refresh = data.get("refresh_token")
    expires_in = data.get("expires_in")
    if not isinstance(access, str) or not isinstance(refresh, str):
        raise RuntimeError(f"OpenAI OAuth token {label} failed: missing access/refresh token.")
    if not isinstance(expires_in, int | float):
        raise RuntimeError(f"OpenAI OAuth token {label} failed: missing expires_in.")

    account_id = extract_account_id(access)
    if not account_id:
        raise RuntimeError(f"OpenAI OAuth token {label} failed: missing ChatGPT account id.")

    return OpenAIOAuthCredentials(
        access=access,
        refresh=refresh,
        expires_ms=int(time.time() * 1000) + int(expires_in * 1000),
        account_id=account_id,
    )


def credentials_to_dict(creds: OpenAIOAuthCredentials) -> dict[str, Any]:
    return {
        "access": creds.access,
        "refresh": creds.refresh,
        "expires_ms": int(creds.expires_ms),
        "account_id": creds.account_id,
    }


def credentials_from_value(value: Any) -> OpenAIOAuthCredentials | None:
    if value is None:
        return None
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except Exception:
            return None
    if not isinstance(value, dict):
        return None

    access = value.get("access")
    refresh = value.get("refresh")
    expires_ms = value.get("expires_ms") or value.get("expires")
    account_id = value.get("account_id") or value.get("accountId")
    if not isinstance(access, str) or not isinstance(refresh, str):
        return None
    if not isinstance(expires_ms, int | float):
        return None
    if not isinstance(account_id, str) or not account_id:
        account_id = extract_account_id(access) or ""
    if not account_id:
        return None
    return OpenAIOAuthCredentials(
        access=access,
        refresh=refresh,
        expires_ms=int(expires_ms),
        account_id=account_id,
    )


def _auth_file(key: str = OPENAI_CODEX_OAUTH_CONFIG_KEY) -> Path:
    return AUTH_DIR / f"{key}.json"


def _ensure_auth_dir() -> None:
    AUTH_DIR.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(AUTH_DIR, 0o700)
    except OSError:
        pass


def load_openai_oauth_credentials() -> OpenAIOAuthCredentials | None:
    path = _auth_file()
    try:
        return credentials_from_value(json.loads(path.read_text(encoding="utf-8")))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return None


def save_openai_oauth_credentials(creds: OpenAIOAuthCredentials) -> None:
    _ensure_auth_dir()
    path = _auth_file()
    fd, tmp = tempfile.mkstemp(dir=AUTH_DIR, suffix=".tmp", prefix=f"{OPENAI_CODEX_OAUTH_CONFIG_KEY}.")
    try:
        os.write(fd, json.dumps(credentials_to_dict(creds), indent=2).encode("utf-8"))
        os.fsync(fd)
        os.close(fd)
        os.replace(tmp, path)
        os.chmod(path, 0o600)
    except BaseException:
        try:
            os.close(fd)
        except OSError:
            pass
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def delete_openai_oauth_credentials() -> None:
    try:
        _auth_file().unlink()
    except FileNotFoundError:
        pass


@contextmanager
def _auth_lock(key: str = OPENAI_CODEX_OAUTH_CONFIG_KEY) -> Generator[None, None, None]:
    _ensure_auth_dir()
    lock_path = AUTH_DIR / f"{key}.lock"
    fd = os.open(lock_path, os.O_CREAT | os.O_RDWR)
    try:
        if fcntl is not None:
            fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        if fcntl is not None:
            fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def ensure_fresh_openai_oauth_credentials(
    *,
    skew_seconds: int = 300,
) -> OpenAIOAuthCredentials:
    with _auth_lock():
        creds = load_openai_oauth_credentials()
        if not creds:
            raise RuntimeError("OpenAI OAuth is not configured. Run: `clearwing setup --provider openai-oauth`")

        now_ms = int(time.time() * 1000)
        if creds.expires_ms > now_ms + skew_seconds * 1000:
            return creds

        refreshed = refresh_openai_oauth_token(creds.refresh)
        save_openai_oauth_credentials(refreshed)
        return refreshed


def run_callback_server(
    *,
    port: int = OPENAI_CODEX_CALLBACK_PORT,
    callback_path: str = OPENAI_CODEX_CALLBACK_PATH,
    timeout_seconds: int = 60,
    expected_state: str | None = None,
) -> dict[str, str] | None:
    result_queue: queue.Queue[dict[str, str]] = queue.Queue(maxsize=1)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args: Any, **_kwargs: Any) -> None:
            return

        def do_GET(self) -> None:  # noqa: N802
            parsed = urllib.parse.urlparse(self.path or "")
            if parsed.path != callback_path:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"Not found")
                return

            qs = urllib.parse.parse_qs(parsed.query)
            code = (qs.get("code") or [""])[0]
            state = (qs.get("state") or [""])[0]
            if expected_state is not None and state != expected_state:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"State mismatch")
                return
            if not code:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"Missing authorization code")
                return

            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(
                b"<!doctype html><html><body>"
                b"<p>Authentication successful. Return to your terminal.</p>"
                b"</body></html>"
            )
            try:
                result_queue.put_nowait({"code": code, "state": state})
            except Exception:
                pass

    server: TCPServer | None = None
    try:
        server = TCPServer(("127.0.0.1", port), Handler)
    except OSError:
        return None

    def _serve() -> None:
        assert server is not None
        with server:
            server.serve_forever(poll_interval=0.1)

    thread = threading.Thread(target=_serve, daemon=True)
    thread.start()
    try:
        return result_queue.get(timeout=max(5, timeout_seconds))
    except Exception:
        return None
    finally:
        try:
            server.shutdown()
        except Exception:
            pass
        thread.join(timeout=1.0)


def is_callback_port_available() -> bool:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.bind(("127.0.0.1", OPENAI_CODEX_CALLBACK_PORT))
        return True
    except OSError:
        return False


def login_openai_oauth(
    *,
    no_open: bool = False,
    timeout_seconds: int = 60,
    allow_manual_fallback: bool = True,
    input_fn=input,
    print_fn=print,
) -> OpenAIOAuthCredentials:
    """Run the browser OAuth flow and persist credentials."""
    if not is_callback_port_available():
        raise RuntimeError("Port 1455 is required for OpenAI OAuth but is already in use.")

    verifier, challenge = generate_pkce()
    state = create_state()
    auth_url = build_authorize_url(challenge=challenge, state=state)

    print_fn("OpenAI OAuth")
    print_fn("1. A browser window should open. Sign in to ChatGPT and approve.")
    print_fn("2. If the callback page fails to load, paste the browser URL here.")
    print_fn(auth_url)

    if not no_open:
        try:
            webbrowser.open(auth_url)
        except Exception:
            pass

    result = run_callback_server(timeout_seconds=timeout_seconds, expected_state=state)
    code: str | None = result.get("code") if result else None

    if not code and not allow_manual_fallback:
        raise RuntimeError("Authorization callback not received.")

    if not code:
        pasted = input_fn("Paste the authorization code (or full redirect URL): ").strip()
        parsed_code, parsed_state = parse_authorization_input(pasted)
        if parsed_state and parsed_state != state:
            raise RuntimeError("State mismatch. Paste the redirect URL from this login attempt.")
        code = parsed_code

    if not code:
        raise RuntimeError("Missing authorization code.")

    creds = exchange_authorization_code(code=code, verifier=verifier)
    save_openai_oauth_credentials(creds)
    return ensure_fresh_openai_oauth_credentials(skew_seconds=0)


__all__ = [
    "OPENAI_AUTH_JWT_CLAIM_PATH",
    "OPENAI_CODEX_DEFAULT_BASE_URL",
    "OPENAI_CODEX_DEFAULT_MODEL",
    "OPENAI_CODEX_OAUTH_CONFIG_KEY",
    "OpenAIOAuthCredentials",
    "build_authorize_url",
    "create_state",
    "credentials_from_value",
    "credentials_to_dict",
    "decode_jwt_payload",
    "delete_openai_oauth_credentials",
    "ensure_fresh_openai_oauth_credentials",
    "exchange_authorization_code",
    "extract_account_id",
    "generate_pkce",
    "load_openai_oauth_credentials",
    "login_openai_oauth",
    "parse_authorization_input",
    "refresh_openai_oauth_token",
    "save_openai_oauth_credentials",
]
