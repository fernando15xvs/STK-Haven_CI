#!/usr/bin/env python3
"""Stage a separately licensed CC0 humanoid GLB for REVIEW, never for release.

A remote CC0 claim does not imply that the downloaded bytes are already
verified. Each accepted download is hashed and its provenance persisted.
Only the chosen explicit allowlisted URL may be downloaded.
"""
import argparse
import hashlib
import json
import pathlib
import shutil
import struct
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
REGISTRY = ROOT / "model_license_registry.json"
SELECTED = "innerscene_cc0_rig53"
MAX_BYTES = 15 * 1024 * 1024

class StageError(ValueError):
    pass

def selected():
    registry = json.loads(REGISTRY.read_text(encoding="utf8"))
    asset = next(x for x in registry["candidates"] if x["id"] == SELECTED)
    if (asset["license"] != "CC0-1.0" or not asset["commercial_allowed"] or
            not asset["redistribution_allowed"] or asset["attribution_required"] or
            asset["sha256"] is not None and len(asset["sha256"]) != 64):
        raise StageError("CC0 source policy not satisfied")
    return asset

def inspect_glb(data):
    if len(data) < 28 or len(data) > MAX_BYTES:
        raise StageError("Source file outside GLB budget")
    magic, version, declared = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or declared != len(data):
        raise StageError("Invalid glTF header")
    jlen, jtype = struct.unpack_from("<I4s", data, 12)
    if jtype != b"JSON" or jlen < 2 or jlen % 4 or 20+jlen+8 > len(data):
        raise StageError("Invalid JSON chunk")
    bsize, btype = struct.unpack_from("<I4s", data, 20+jlen)
    if btype != b"BIN\x00" or 28+jlen+bsize != len(data):
        raise StageError("Expected one embedded BIN chunk")
    try:
        doc = json.loads(data[20:20+jlen])
    except (ValueError, UnicodeDecodeError) as exc:
        raise StageError("Malformed GLB JSON") from exc
    if doc.get("asset", {}).get("version") != "2.0":
        raise StageError("Not glTF 2.0")
    if len(doc.get("meshes", [])) < 1 or len(doc.get("nodes", [])) < 45:
        raise StageError("Missing professional body topology or rig")
    skins = doc.get("skins", [])
    if not skins:
        raise StageError("No skinned humanoid armature")
    joint_count = max(len(s.get("joints", [])) for s in skins)
    if not 45 <= joint_count <= 120:
        raise StageError(f"Expected full-body rig, got {joint_count} joints")
    buffers = doc.get("buffers", [])
    if len(buffers) != 1 or "uri" in buffers[0] or buffers[0]["byteLength"] > bsize:
        raise StageError("External or invalid GLB geometry")
    for item in doc.get("images", []):
        if "uri" in item:
            raise StageError("External texture dependency")
    return {"jointCount": joint_count, "meshCount": len(doc["meshes"]),
            "materialCount": len(doc.get("materials", [])),
            "animationCount": len(doc.get("animations", [])),
            "bodyRigAvailable": True,
            "movementRetargeted": False,
            "anatomicalMuscleMasksReady": False}

def fetch_model(asset, timeout=25):
    request = urllib.request.Request(
        asset["download_url"],
        headers={"User-Agent": "STK-Haven-CC0-asset-audit/1.0",
                 "Accept": "application/octet-stream"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = response.read(MAX_BYTES+1)
    return data

def stage(data, output, asset=None):
    asset = asset or selected()
    geometry = inspect_glb(data)
    digest = hashlib.sha256(data).hexdigest()
    if asset["sha256"] and asset["sha256"] != digest:
        raise StageError("Downloaded model hash changed; human re-review required")
    output = pathlib.Path(output)
    output.mkdir(parents=True, exist_ok=True)
    (output / "human-base-rigged-cc0.glb").write_bytes(data)
    record = {"status": "source_staged_not_approved",
              "sourceId":asset["id"],"license":asset["license"],
              "sourceUrl":asset["source_page"],
              "licenseEvidence":asset["license_evidence_url"],
              "sha256":digest,"bytes":len(data),"approved":False,"enabled":False,
              "publicReleaseAllowedByCC0":True,
              "sourceReviewRequired":True,
              "notProfessionalEcorche":True,**geometry}
    (output/"source_provenance.json").write_text(
        json.dumps(record, indent=2,sort_keys=True)+"\n", encoding="utf8")
    return record

def main():
    p = argparse.ArgumentParser()
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--input",type=pathlib.Path,help="Existing downloaded CC0 GLB")
    src.add_argument("--download",action="store_true",
                     help="Try only the verified source host URL")
    p.add_argument("--output",type=pathlib.Path,required=True)
    p.add_argument("--optional",action="store_true",
                   help="On remote network error, write unavailable status, not a fake asset")
    args = p.parse_args()
    asset = selected()
    try:
        data = args.input.read_bytes() if args.input else fetch_model(asset)
        result = stage(data, args.output,asset)
    except (OSError,StageError,ValueError) as error:
        if not args.optional:
            raise
        args.output.mkdir(parents=True,exist_ok=True)
        result = {"status":"source_unavailable","approved":False,"enabled":False,
                  "sourceId":asset["id"],"error":str(error),
                  "downloadVerified":False}
        (args.output/"source_provenance.json").write_text(json.dumps(
            result,indent=2)+"\n",encoding="utf8")
    print(json.dumps(result,indent=2))
if __name__=="__main__":
    main()
