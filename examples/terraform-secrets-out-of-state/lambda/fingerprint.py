"""Consume a secret by ARN and prove which value is current, without ever revealing it.

The function reads the secret at runtime through SECRET_ARN. Terraform never handles
the value: it only wires the ARN. What comes back is a fingerprint - enough to see a
rotation happen, useless to anyone who intercepts it.

Two sinks, so the demo never depends on a third party being reachable:

- `stdout` (default) returns the fingerprint and the message it would have sent.
- `twitch` exchanges the refresh token for an access token and posts to a chat.
  This is the realistic shape: what rests in the vault is the durable refresh
  token, and the short-lived access token is derived at each call and kept nowhere.
"""

import hashlib
import json
import os
import urllib.parse
import urllib.request

import boto3

_secrets = boto3.client("secretsmanager")

_TOKEN_URL = "https://id.twitch.tv/oauth2/token"
_CHAT_URL = "https://api.twitch.tv/helix/chat/messages"


def _fingerprint(value: str) -> str:
    """First 8 hex chars of the SHA-256 digest. One-way, and short enough to read aloud."""
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:8]


def _post(url: str, data: bytes, headers: dict) -> dict:
    request = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(request, timeout=8) as response:
        return json.loads(response.read())


def _refresh_access_token(creds: dict) -> str:
    """Trade the durable refresh token for a short-lived access token, kept in memory only."""
    body = urllib.parse.urlencode(
        {
            "client_id": creds["client_id"],
            "client_secret": creds["client_secret"],
            "refresh_token": creds["refresh_token"],
            "grant_type": "refresh_token",
        }
    ).encode()
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    return _post(_TOKEN_URL, body, headers)["access_token"]


def _send_chat_message(creds: dict, user_id: str, message: str) -> None:
    access_token = _refresh_access_token(creds)
    body = json.dumps(
        {"broadcaster_id": user_id, "sender_id": user_id, "message": message}
    ).encode()
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Client-Id": creds["client_id"],
        "Content-Type": "application/json",
    }
    _post(_CHAT_URL, body, headers)


def handler(event, context):  # noqa: ARG001 - Lambda signature
    secret_arn = os.environ["SECRET_ARN"]
    sink = os.environ.get("SINK", "stdout")

    secret = _secrets.get_secret_value(SecretId=secret_arn)["SecretString"]

    # The secret is a JSON credential set. Only the refresh token is fingerprinted:
    # it is the field a rotation actually changes.
    try:
        creds = json.loads(secret)
        token = creds["refresh_token"]
    except (json.JSONDecodeError, KeyError):
        # A step-1 secret may still be a bare string. Fingerprint it as-is.
        creds, token = {}, secret

    label = (event or {}).get("label", "current secret")
    fingerprint = _fingerprint(token)
    message = f"{label} -> fingerprint {fingerprint}"

    if sink == "stdout":
        print(message)
        return {"sink": sink, "fingerprint": fingerprint, "message": message}

    if sink == "twitch":
        _send_chat_message(creds, os.environ["TWITCH_USER_ID"], message)
        return {"sink": sink, "fingerprint": fingerprint, "sent": True}

    raise ValueError(f"unknown SINK: {sink}")
