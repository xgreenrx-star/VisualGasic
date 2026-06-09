#!/usr/bin/env python3
"""
YouTube upload script for VisualGasic demoscene video.
Requires client_secrets.json in the same directory (one-time setup).

Usage:
    python tools/youtube_upload.py
"""

import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CLIENT_SECRETS = os.path.join(SCRIPT_DIR, "client_secrets.json")
VIDEO_FILE = os.path.join(SCRIPT_DIR, "..", "demoscene_intro.mp4")

VIDEO_TITLE = "VisualGasic v5.2 — Procedural Demoscene (100% VG, No Assets)"
VIDEO_DESCRIPTION = """\
A 165-second procedural demoscene written entirely in VisualGasic — \
zero external assets, one .vg file.

Five effects, live chiptune (In the Hall of the Mountain King), \
all rendered through VGVectorCanvas2D:

• Starfield — 600 perspective-projected star streaks, BPM-driven speed, \
warp-rush into the torus
• Torus — wireframe rotation with heartbeat kick-drum pulse; \
arrives from the starfield and explodes into plasma
• Plasma — 40×23 HSV colour-wave grid locked at 200 BPM
• Credits — helix-orbit logo + sine-wave text scroller
• Title card — wave title, border frame, corner accents

The Tweak Overlay (Ctrl+Shift+T) is shown live, adjusting plasma colours, \
torus wireframe, starfield tint, and credits logo in real time while \
the chiptune plays. The "→ Source" button patches the chosen colour \
directly back into the .vg source file.

VisualGasic: https://visualgasic.io
Source: https://github.com/visualgasic/visualgasic
Demo file: game_projects/demoscene_intro/demo.vg
"""
VIDEO_TAGS = [
    "VisualGasic", "BASIC", "demoscene", "procedural", "godot",
    "gamedev", "indiegame", "chiptune", "vector graphics", "tweak overlay"
]
VIDEO_CATEGORY = "28"   # Science & Technology
VIDEO_PRIVACY  = "public"

# ── OAuth scopes ──────────────────────────────────────────────────────────────
SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]

def get_credentials():
    from google_auth_oauthlib.flow import InstalledAppFlow
    import pickle, pathlib

    token_path = pathlib.Path(SCRIPT_DIR) / "yt_token.pickle"
    creds = None
    if token_path.exists():
        with open(token_path, "rb") as f:
            creds = pickle.load(f)

    if not creds or not creds.valid:
        from google.auth.transport.requests import Request
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRETS, SCOPES)
            creds = flow.run_local_server(port=0, open_browser=True)
        with open(token_path, "wb") as f:
            pickle.dump(creds, f)
    return creds


def upload(creds):
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload

    youtube = build("youtube", "v3", credentials=creds)

    body = {
        "snippet": {
            "title": VIDEO_TITLE,
            "description": VIDEO_DESCRIPTION,
            "tags": VIDEO_TAGS,
            "categoryId": VIDEO_CATEGORY,
        },
        "status": {
            "privacyStatus": VIDEO_PRIVACY,
        },
    }

    media = MediaFileUpload(
        VIDEO_FILE,
        chunksize=1024 * 1024,   # 1 MB chunks
        resumable=True,
        mimetype="video/mp4",
    )

    request = youtube.videos().insert(
        part=",".join(body.keys()),
        body=body,
        media_body=media,
    )

    print(f"Uploading: {os.path.basename(VIDEO_FILE)}")
    print(f"Title:     {VIDEO_TITLE}")
    print()

    response = None
    while response is None:
        status, response = request.next_chunk()
        if status:
            pct = int(status.progress() * 100)
            bar = "█" * (pct // 5) + "░" * (20 - pct // 5)
            print(f"\r  [{bar}] {pct}%", end="", flush=True)

    print(f"\n\nDone! Video ID: {response['id']}")
    print(f"URL: https://youtu.be/{response['id']}")
    return response["id"]


if __name__ == "__main__":
    if not os.path.exists(CLIENT_SECRETS):
        print("ERROR: client_secrets.json not found.")
        print(f"Expected at: {CLIENT_SECRETS}")
        print()
        print("Setup steps:")
        print("  1. Go to https://console.cloud.google.com/")
        print("  2. Create a project (or select existing)")
        print("  3. APIs & Services → Enable APIs → search 'YouTube Data API v3' → Enable")
        print("  4. APIs & Services → Credentials → Create Credentials → OAuth client ID")
        print("  5. Application type: Desktop app  →  Name: VG Upload  →  Create")
        print("  6. Download JSON → save as tools/client_secrets.json")
        print("  7. Run this script again")
        sys.exit(1)

    if not os.path.exists(VIDEO_FILE):
        print(f"ERROR: video file not found: {VIDEO_FILE}")
        sys.exit(1)

    creds = get_credentials()
    video_id = upload(creds)
    print()
    print("Paste this URL into RELEASE_NOTES_v5.2.0-Beta3.md:")
    print(f"  https://youtu.be/{video_id}")
