#!/usr/bin/env python3
"""Show App Store Connect build + version state for markdownViewr.

Credential-free: the API Key ID is auto-discovered from the AuthKey_<id>.p8
filename in ~/.appstoreconnect/private_keys/, and the issuer id is read from
~/.appstoreconnect/issuer_id (or the ASC_ISSUER_ID env var). No secrets live in
this (public) repo. Stdlib only — ES256 JWT is signed via openssl.
"""
import json, base64, time, subprocess, urllib.request, urllib.error, os, glob, sys

BUNDLE_ID = "com.dkelkhoff.markdownViewr"
KEYS_DIR = os.path.expanduser("~/.appstoreconnect/private_keys")

key_files = glob.glob(os.path.join(KEYS_DIR, "AuthKey_*.p8"))
if not key_files:
    sys.exit(f"No AuthKey_*.p8 in {KEYS_DIR}")
KEY_PATH = key_files[0]
KEY_ID = os.path.basename(KEY_PATH)[len("AuthKey_"):-len(".p8")]
ISSUER = os.environ.get("ASC_ISSUER_ID") or \
    open(os.path.expanduser("~/.appstoreconnect/issuer_id")).read().strip()

def b64url(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=")

now = int(time.time())
seg = b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}, separators=(',', ':')).encode()) + b"." + \
      b64url(json.dumps({"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}, separators=(',', ':')).encode())
der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH], input=seg, capture_output=True).stdout
def read_int(d, i):
    ln = d[i+1]; return d[i+2:i+2+ln], i+2+ln
i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7f)
r, i = read_int(der, i); s, i = read_int(der, i)
pad = lambda v: b'\x00' * (32 - len(v.lstrip(b'\x00'))) + v.lstrip(b'\x00')
token = (seg + b"." + b64url(pad(r) + pad(s))).decode()

def get(url):
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    return json.load(urllib.request.urlopen(req))

try:
    apps = get(f"https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]={BUNDLE_ID}")
    if not apps["data"]:
        sys.exit(f"No App Store Connect app found for bundle id {BUNDLE_ID}")
    app_id = apps["data"][0]["id"]
    print(f"App: {BUNDLE_ID}  (id {app_id})\n")

    b = get(f"https://api.appstoreconnect.apple.com/v1/builds?filter[app]={app_id}"
            "&limit=5&sort=-uploadedDate&include=preReleaseVersion,appStoreVersion")
    inc = {(x["type"], x["id"]): x for x in b.get("included", [])}
    print("=== Builds ===")
    for bd in b["data"]:
        at, rels = bd["attributes"], bd.get("relationships", {})
        pv = rels.get("preReleaseVersion", {}).get("data")
        train = inc.get((pv["type"], pv["id"]), {}).get("attributes", {}).get("version", "?") if pv else "-"
        asv = rels.get("appStoreVersion", {}).get("data")
        att = "not attached to a version"
        if asv:
            a = inc.get((asv["type"], asv["id"]), {}).get("attributes", {})
            att = f"attached to {a.get('versionString')} [{a.get('appStoreState')}]"
        print(f"  build {at.get('version')}  train {train}  state={at.get('processingState')}  ({att})")

    print("\n=== App Store versions ===")
    v = get(f"https://api.appstoreconnect.apple.com/v1/apps/{app_id}/appStoreVersions?limit=10")
    for vv in v["data"]:
        a = vv["attributes"]
        print(f"  {a.get('versionString')}  {a.get('platform')}  [{a.get('appStoreState')}]")
except urllib.error.HTTPError as e:
    sys.exit(f"HTTP {e.code}\n{e.read().decode()[:800]}")
