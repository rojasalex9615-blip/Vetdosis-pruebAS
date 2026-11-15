#!/usr/bin/env python3
"""Autoriza Google Drive con un cliente OAuth de escritorio, en dos pasos.

  python3 gdrive_login.py url                 # imprime la URL de autorizacion
  python3 gdrive_login.py code "<code|URL>"   # canjea el code y guarda el token

Lee la credencial de cliente de ~/.config/gdrive/client_secret.json (o de
$GDRIVE_CLIENT_SECRET_FILE) y guarda el token en ~/.config/gdrive/token.json
(chmod 600). No imprime nunca el client_secret ni el refresh token.
"""
import json, os, sys, urllib.parse, urllib.request

SECRET_FILE = os.environ.get(
    "GDRIVE_CLIENT_SECRET_FILE",
    os.path.expanduser("~/.config/gdrive/client_secret.json"),
)
TOKEN_FILE = os.environ.get(
    "GDRIVE_TOKEN_FILE", os.path.expanduser("~/.config/gdrive/token.json")
)
REDIRECT = "http://localhost"
SCOPE = "https://www.googleapis.com/auth/drive"


def _client():
    with open(SECRET_FILE) as fh:
        return json.load(fh)["installed"]


def cmd_url():
    c = _client()
    params = {
        "client_id": c["client_id"],
        "redirect_uri": REDIRECT,
        "response_type": "code",
        "scope": SCOPE,
        "access_type": "offline",
        "prompt": "consent",
    }
    print(c["auth_uri"] + "?" + urllib.parse.urlencode(params))


def cmd_code(raw):
    c = _client()
    code = raw
    if "code=" in raw:
        q = urllib.parse.urlparse(raw).query or raw.split("?", 1)[-1]
        code = urllib.parse.parse_qs(q).get("code", [""])[0]
    if not code:
        sys.exit("No he encontrado un code en lo que pegaste.")
    data = urllib.parse.urlencode({
        "code": code,
        "client_id": c["client_id"],
        "client_secret": c["client_secret"],
        "redirect_uri": REDIRECT,
        "grant_type": "authorization_code",
    }).encode()
    try:
        with urllib.request.urlopen(
            urllib.request.Request(c["token_uri"], data=data), timeout=30
        ) as r:
            t = json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit("Fallo al canjear el code: " + e.read().decode()[:300])
    if not t.get("refresh_token"):
        sys.exit(
            "Google no devolvio refresh_token (suele pasar si ya autorizaste antes). "
            "Retira el acceso en https://myaccount.google.com/permissions y repite."
        )
    os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
    with open(TOKEN_FILE, "w") as fh:
        json.dump(
            {
                "refresh_token": t["refresh_token"],
                "client_id": c["client_id"],
                "client_secret": c["client_secret"],
            },
            fh,
        )
    os.chmod(TOKEN_FILE, 0o600)
    print("LISTO. Token guardado (valor no mostrado).")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "url":
        cmd_url()
    elif len(sys.argv) >= 3 and sys.argv[1] == "code":
        cmd_code(sys.argv[2])
    else:
        sys.exit(__doc__)
