#!/usr/bin/env python3
"""Autoriza Google Drive por FLUJO DE DISPOSITIVO (sin navegador aqui).

Requiere un cliente OAuth de tipo "TV and Limited Input" (Google Cloud).
  export GDRIVE_CLIENT_ID=... GDRIVE_CLIENT_SECRET=...
  python3 gdrive_auth.py

Imprime un codigo y una URL. Abre la URL en tu telefono/PC, pega el codigo,
acepta. Al terminar, este script imprime el REFRESH TOKEN: pasamelo (o guardalo
como secreto GDRIVE_REFRESH_TOKEN) y ya puedo leer/escribir tu Drive.
"""
import json, os, sys, time, urllib.parse, urllib.request

CID = os.environ.get("GDRIVE_CLIENT_ID")
CSEC = os.environ.get("GDRIVE_CLIENT_SECRET")
if not CID or not CSEC:
    sys.exit("Define GDRIVE_CLIENT_ID y GDRIVE_CLIENT_SECRET.")


def post(url, data):
    req = urllib.request.Request(url, data=urllib.parse.urlencode(data).encode())
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


d = post("https://oauth2.googleapis.com/device/code", {
    "client_id": CID,
    "scope": "https://www.googleapis.com/auth/drive",
})
print(f"\n1) Abre:  {d['verification_url']}")
print(f"2) Codigo: {d['user_code']}\n")

interval = int(d.get("interval", 5))
deadline = time.time() + int(d.get("expires_in", 1800))
while time.time() < deadline:
    time.sleep(interval)
    try:
        t = post("https://oauth2.googleapis.com/token", {
            "client_id": CID, "client_secret": CSEC,
            "device_code": d["device_code"],
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        })
    except urllib.error.HTTPError as e:
        body = json.loads(e.read())
        err = body.get("error")
        if err == "authorization_pending":
            continue
        if err == "slow_down":
            interval += 5
            continue
        sys.exit(f"Error de autorizacion: {body}")
    print("LISTO. Guarda esto como secreto GDRIVE_REFRESH_TOKEN:\n")
    print(t.get("refresh_token") or "(sin refresh_token; ya habias autorizado)")
    break
else:
    sys.exit("Caduco el codigo. Vuelve a intentarlo.")
