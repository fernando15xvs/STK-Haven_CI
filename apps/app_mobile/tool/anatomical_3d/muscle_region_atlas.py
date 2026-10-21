"""Procedural REGION LABELS for an independently licensed CC0 body.

Not an anatomy reference atlas. Region assignments are approximate masks from
bind-pose coordinates, outward-facing normals and skeleton weights.  Keep
precise surface index groups, do not invent separately sculpted muscles.
"""
from collections import defaultdict

EXERCISE_ROLES = {
    "ex_bench_press": {
        "pectoralis_major": "primary",
        "anterior_deltoid": "secondary",
        "triceps_brachii": "secondary",
    },
    "ex_barbell_row": {
        "latissimus_dorsi": "primary",
        "rhomboids": "secondary",
        "posterior_deltoid": "secondary",
        "middle_trapezius": "secondary",
    },
    "ex_squat": {
        "quadriceps_femoris": "primary",
        "gluteus_maximus": "primary",
        "hamstrings": "secondary",
        "adductor_magnus": "secondary",
    },
}

def _influence(indices,weights,ids):
    return sum(w for i,w in zip(indices,weights) if int(i) in ids)

def region_for_face(centroid,normal,indices,weights,joints):
    x,y,z=centroid
    ax=abs(x)
    nz=normal[2]
    thigh=_influence(indices,weights,{joints["thigh_l"],joints["thigh_r"]})
    pelvis=_influence(indices,weights,{joints["pelvis"]})
    upperarm=_influence(indices,weights,{joints["upperarm_l"],joints["upperarm_r"]})
    torso=_influence(indices,weights,{joints["spine_02"],joints["spine_03"]})
    if thigh>=.42:
        if .49<y<.91 and .06<ax<.31 and z>.015 and nz>.26:
            return "quadriceps_femoris"
        if .52<y<.90 and ax<.32 and nz<-.42:
            return "hamstrings"
        if .72<y<.92 and .03<ax<.14 and abs(normal[0])>.42:
            return "adductor_magnus"
    if thigh+pelvis>.60 and .82<y<1.04 and .08<ax<.31 and nz<-.35:
        return "gluteus_maximus"
    if upperarm>.50 and .33<ax<.57 and 1.04<y<1.32 and nz<.28:
        return "triceps_brachii"
    if upperarm>.28 and .245<ax<.42 and 1.24<y<1.49:
        return "anterior_deltoid" if nz>.18 else "posterior_deltoid"
    if torso>.18:
        if .045<ax<.275 and 1.17<y<1.405 and z>.045 and nz>.43:
            return "pectoralis_major"
        if .12<ax<.31 and 1.385<y<1.53 and nz<-.28:
            return "middle_trapezius"
        if .035<ax<.18 and 1.32<y<1.47 and nz<-.42:
            return "rhomboids"
        if .09<ax<.34 and 1.035<y<1.35 and z<.045 and nz<-.44:
            return "latissimus_dorsi"
    return None

def classify_mesh(glb,exercise):
    """Return (named-region, role) => complete source-triangle index buffers."""
    roles=EXERCISE_ROLES[exercise]
    primitive=glb.doc["meshes"][0]["primitives"][0]
    attrs=primitive["attributes"]
    positions=glb.accessor(attrs["POSITION"])
    normals=glb.accessor(attrs["NORMAL"])
    joints_0=glb.accessor(attrs["JOINTS_0"])
    weights_0=glb.accessor(attrs["WEIGHTS_0"])
    faces=[int(index[0]) for index in glb.accessor(primitive["indices"])]
    joints={glb.doc["nodes"][node]["name"]:i
            for i,node in enumerate(glb.doc["skins"][0]["joints"])}
    groups=defaultdict(list)
    for face_start in range(0,len(faces),3):
        face=faces[face_start:face_start+3]
        center=tuple(sum(positions[v][axis] for v in face)/3 for axis in range(3))
        normal=tuple(sum(normals[v][axis] for v in face)/3 for axis in range(3))
        j=[value for v in face for value in joints_0[v]]
        w=[value/3 for v in face for value in weights_0[v]]
        label=region_for_face(center,normal,j,w,joints)
        key=(label,roles[label]) if label in roles else ("body","body")
        groups[key].extend(face)
    if not groups.get(("body","body")):
        raise ValueError("Gray body region absent")
    for region,role in roles.items():
        if len(groups.get((region,role),[]))<50*3:
            raise ValueError("Muscle label not visually represented: "+region)
    if sum(len(v) for v in groups.values())!=len(faces):
        raise AssertionError("Faces lost or duplicated in muscle atlas")
    return groups
