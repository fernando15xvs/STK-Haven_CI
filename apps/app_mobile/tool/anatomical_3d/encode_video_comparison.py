#!/usr/bin/env python3
"""Encode video comparison from real Flutter GLB frames; no GIF, no catalog use.

Generated videos are PRE-RENDERED from experimental GLBs, NOT the separately
licensed CC0 53-bone human (which still needs animation retargeting).
"""
import argparse
import hashlib
import json
import pathlib
import subprocess

IDS = ("ex_bench_press","ex_barbell_row","ex_squat")
FPS = 16
FRAME_COUNT = FPS * 4

def command(args):
    run = subprocess.run(args, capture_output=True, text=True, check=False)
    if run.returncode:
        raise RuntimeError(f"Command failed ({run.returncode}): {' '.join(args)}\n{run.stderr[-1800:]}")
    return run.stdout

def encode(input_dir, output_dir, glb_dir, crf=24):
    source = pathlib.Path(input_dir)
    out = pathlib.Path(output_dir)
    glbs = pathlib.Path(glb_dir)
    out.mkdir(parents=True,exist_ok=True)
    report = {"status":"experimental_comparison_only",
              "source":"existing_v3_2_procedural_glb_not_cc0_human",
              "fps":FPS,"seconds":4,"dimensions":[320,320],
              "theme":"dark_blue_baked_in_video",
              "colorVariation":"GLB runtime supports dynamic accents; MP4 does NOT",
              "androidCompatibility":"H264 decoder requires on-device API23 verification",
              "approved":False,"enabled":False,"catalogCount":229,"pilots":[]}
    for exercise in IDS:
        folder=source/exercise
        frames=sorted(folder.glob("frame_*.png"))
        if len(frames)!=FRAME_COUNT or [p.name for p in frames] != [
            f"frame_{n:03d}.png" for n in range(FRAME_COUNT)]:
            raise ValueError(f"Missing/duplicated real Flutter frames for {exercise}")
        original=glbs/(exercise+".glb")
        if not original.is_file():
            raise FileNotFoundError(original)
        mp4=out/(exercise+".mp4")
        command(["ffmpeg","-hide_banner","-loglevel","error","-y",
            "-framerate",str(FPS),"-i",str(folder/"frame_%03d.png"),
            "-an","-c:v","libx264","-profile:v","baseline",
            "-level","3.0","-preset","fast","-crf",str(crf),
            "-pix_fmt","yuv420p","-movflags","+faststart",str(mp4)])
        meta=json.loads(command(["ffprobe","-v","error",
            "-select_streams","v:0","-show_entries",
            "stream=codec_name,profile,width,height,avg_frame_rate,pix_fmt,nb_frames:"
            "format=duration,size","-of","json",str(mp4)]))
        stream=meta["streams"][0]
        duration=float(meta["format"]["duration"])
        if (stream["codec_name"]!="h264" or stream["width"]!=320 or
            stream["height"]!=320 or abs(duration-4)>.15 or
            stream["pix_fmt"]!="yuv420p"):
            raise ValueError(f"Unexpected video format for {exercise}: {meta}")
        report["pilots"].append({
            "id":exercise,"glbBytes":original.stat().st_size,
            "videoBytes":mp4.stat().st_size,
            "videoToGlbRatio":round(mp4.stat().st_size/original.stat().st_size,3),
            "videoSha256":hashlib.sha256(mp4.read_bytes()).hexdigest(),
            "durationSeconds":duration,"codec":"h264","profile":stream["profile"],
            "frameRate":stream["avg_frame_rate"],
            "frameCount":int(stream.get("nb_frames",FRAME_COUNT)),
            "approved":False,"enabled":False})
    (out/"video_comparison_report.json").write_text(
        json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
    return report

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--frames",type=pathlib.Path,required=True)
    p.add_argument("--glb",type=pathlib.Path,required=True)
    p.add_argument("--output",type=pathlib.Path,required=True)
    args=p.parse_args()
    print(json.dumps(encode(args.frames,args.output,args.glb),indent=2))
