"""Consume a secret by ARN and prove which value is current, without ever revealing it.

The function reads the secret at runtime through SECRET_ARN. Terraform never handles
the value: it only wires the ARN. What comes back is a fingerprint - enough to see a
rotation happen, useless to anyone who intercepts it.
"""

import hashlib
import json
import os

import boto3

_secrets = boto3.client("secretsmanager")


def _fingerprint(value: str) -> str:
    """First 8 hex chars of the SHA-256 digest. One-way, and short enough to read aloud."""
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:8]


def handler(event, context):  # noqa: ARG001 - Lambda signature
    secret_arn = os.environ["SECRET_ARN"]
    sink = os.environ.get("SINK", "stdout")

    secret = _secrets.get_secret_value(SecretId=secret_arn)["SecretString"]

    # The secret is a JSON blob in the shape of a chat-bot credential set. Only the
    # refresh token is fingerprinted: it is the field a rotation actually changes.
    try:
        token = json.loads(secret)["refresh_token"]
    except (json.JSONDecodeError, KeyError):
        # A step-1 secret is still a bare string. Fingerprint it as-is.
        token = secret

    message = f"token fingerprint: {_fingerprint(token)}"

    if sink == "stdout":
        print(message)
        return {"sink": sink, "fingerprint": _fingerprint(token)}

    raise ValueError(f"unknown SINK: {sink}")
