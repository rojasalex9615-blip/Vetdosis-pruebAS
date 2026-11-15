#!/usr/bin/env python3
"""Conector minimo a Google Drive. Dos modos de credencial:

  1) Cuenta de servicio:  GDRIVE_SA_JSON  (ruta o contenido del JSON)
  2) Token OAuth:         GDRIVE_CLIENT_ID / GDRIVE_CLIENT_SECRET / GDRIVE_REFRESH_TOKEN

Uso:
  python3 gdrive.py list  [FOLDER_ID]
  python3 gdrive.py put   ARCHIVO_LOCAL [FOLDER_ID]
  python3 gdrive.py get   FILE_ID DESTINO
"""
import io, json, os, sys

SCOPES = ["https://www.googleapis.com/auth/drive.file"]


def _svc():
    from google.oauth2 import service_account
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build

    tok_file = os.environ.get(
        "GDRIVE_TOKEN_FILE", os.path.expanduser("~/.config/gdrive/token.json")
    )
    raw = os.environ.get("GDRIVE_SA_JSON")
    if not raw and os.path.exists(tok_file):
        tok = json.load(open(tok_file))
        os.environ.setdefault("GDRIVE_CLIENT_ID", tok["client_id"])
        os.environ.setdefault("GDRIVE_CLIENT_SECRET", tok["client_secret"])
        os.environ.setdefault("GDRIVE_REFRESH_TOKEN", tok["refresh_token"])
    if raw:
        info = json.loads(raw) if raw.lstrip().startswith("{") else json.load(open(raw))
        creds = service_account.Credentials.from_service_account_info(info, scopes=SCOPES)
    else:
        creds = Credentials(
            None,
            refresh_token=os.environ["GDRIVE_REFRESH_TOKEN"],
            client_id=os.environ["GDRIVE_CLIENT_ID"],
            client_secret=os.environ["GDRIVE_CLIENT_SECRET"],
            token_uri="https://oauth2.googleapis.com/token",
            scopes=SCOPES,
        )
    return build("drive", "v3", credentials=creds, cache_discovery=False)


def cmd_list(folder=None):
    q = f"'{folder}' in parents and trashed=false" if folder else "trashed=false"
    r = _svc().files().list(q=q, fields="files(id,name,size,mimeType)", pageSize=50).execute()
    for f in r.get("files", []):
        print(f"{f['id']}  {f.get('size','-'):>10}  {f['name']}")


def cmd_put(local, folder=None):
    from googleapiclient.http import MediaFileUpload
    meta = {"name": os.path.basename(local)}
    if folder:
        meta["parents"] = [folder]
    media = MediaFileUpload(local, resumable=True)
    f = _svc().files().create(body=meta, media_body=media, fields="id,name").execute()
    print("SUBIDO", f["id"], f["name"])


def cmd_get(file_id, dest):
    from googleapiclient.http import MediaIoBaseDownload
    buf = io.FileIO(dest, "wb")
    req = _svc().files().get_media(fileId=file_id)
    dl = MediaIoBaseDownload(buf, req)
    done = False
    while not done:
        _, done = dl.next_chunk()
    print("BAJADO", dest)


def cmd_check(folder=None):
    svc = _svc()
    about = svc.about().get(fields="user(emailAddress,displayName)").execute()
    u = about.get("user", {})
    print("CUENTA:", u.get("emailAddress"), "|", u.get("displayName"))
    if folder:
        meta = svc.files().get(fileId=folder, fields="id,name,mimeType").execute()
        print("CARPETA:", meta["id"], meta["name"], meta["mimeType"])
    else:
        print("Acceso OK (sin carpeta indicada).")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    try:
        if sys.argv[1] == "list":
            cmd_list(*sys.argv[2:])
        elif sys.argv[1] == "put":
            cmd_put(*sys.argv[2:])
        elif sys.argv[1] == "check":
            cmd_check(*sys.argv[2:])
        elif sys.argv[1] == "get":
            cmd_get(*sys.argv[2:])
        else:
            sys.exit(__doc__)
    except KeyError as e:
        sys.exit(f"Falta la credencial: {e}. Define GDRIVE_SA_JSON o el trio GDRIVE_CLIENT_ID/SECRET/REFRESH_TOKEN.")
