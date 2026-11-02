"""Export Ash Meridian AI face meshes to runtime JSON.

Usage (from this folder):  python3 export_mesh.py ../../assets/ai_face
Writes alien_face.json (chosen: holographic alien) and human_face.json (alternate),
plus alien_face_small.json: a lightweight line-only face for small in-game screens
(the FEB AI). Small-face points carry their own pose weights: [x, y, jaw_w, upper_w].
"""
import json, sys, os
import numpy as np
import face as F

def export(kind, path):
    D = F.design(kind)
    V, T, E = F.build(D)
    jw, uw, hz = [], [], []
    for x, y in V:
        a, b = F.weights(D, x, y)
        jw.append(round(a, 4)); uw.append(round(b, 4)); hz.append(round(F.height(D, x, y), 4))
    feats = {k: [[round(float(x), 1), round(float(y), 1)] for x, y in pl] for k, pl in D["F"].items()}
    irises = [[round(float(c[0]), 1), round(float(c[1]), 1), float(r)] for c, r in D["irises"]]
    data = {
        "format": "ash_meridian_ai_face",
        "version": 1,
        "kind": kind,
        "canvas": 1000,
        "rest_focus": [500, 490],
        "mouth_y": D["mouth_y"],
        "mouth_hw": D.get("mouth_hw", 85.0),
        "jaw_drop": D["drop"],
        "upper_lift": 22.0,
        "corner_push": 12.0,
        "mouth_hole": ["in_up", "in_lo"],
        "verts": [[round(float(x), 1), round(float(y), 1)] for x, y in V],
        "jaw_w": jw,
        "upper_w": uw,
        "height": hz,
        "tris": [[int(i) for i in t] for t in T],
        "edges": [[int(a), int(b)] for a, b in E],
        "features": feats,
        "bold_features": ["contour", "lip_up", "lip_lo", "eye_r", "eye_l"],
        "irises": irises,
    }
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    print(kind, path, "verts", len(V), "tris", len(T), "edges", len(E), "features", len(feats))

def simplify(pl, step):
    if len(pl) <= 4: return list(pl)
    out = list(pl[::step])
    if out[-1] != pl[-1]: out.append(pl[-1])
    return out

def export_small(kind, path, step=3):
    D = F.design(kind)
    feats = {}
    segs = 0
    for k, pl in D["F"].items():
        pts = simplify(pl, 1 if k in ("in_up", "in_lo", "lip_up", "lip_lo") else step)
        row = []
        for x, y in pts:
            a, b = F.weights(D, x, y)
            row.append([round(float(x), 1), round(float(y), 1), round(a, 3), round(b, 3)])
        feats[k] = row
        segs += len(row) - 1
    data = {
        "format": "ash_meridian_ai_face_small",
        "version": 1,
        "kind": kind,
        "canvas": 1000,
        "rest_focus": [500, 490],
        "mouth_y": D["mouth_y"],
        "jaw_drop": D["drop"],
        "upper_lift": 22.0,
        "corner_push": 12.0,
        "mouth_hole": ["in_up", "in_lo"],
        "features": feats,
        "bold_features": ["contour", "lip_up", "lip_lo", "eye_r", "eye_l"],
        "irises": [[round(float(c[0]), 1), round(float(c[1]), 1), float(r)] for c, r in D["irises"]],
    }
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    print(kind, path, "small features", len(feats), "segments", segs)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    export("alien", os.path.join(out, "alien_face.json"))
    export("human", os.path.join(out, "human_face.json"))
    export_small("alien", os.path.join(out, "alien_face_small.json"))
