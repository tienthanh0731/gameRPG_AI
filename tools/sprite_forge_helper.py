"""
Sprite Forge Helper for Lam Tinh - Hoang Co Ky
Wraps agent-sprite-forge tools for slicing, inspecting, and QC-checking Godot 2D assets.
"""

import sys
import os
import argparse
from PIL import Image

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASF_PATH = os.path.join(REPO_ROOT, ".external_tools", "agent-sprite-forge")
QC_SCRIPT = os.path.join(ASF_PATH, "skills", "generate2dsprite", "scripts", "sheet_qc.py")

def cmd_info(args):
    img_path = args.path
    if not os.path.exists(img_path):
        print(f"Error: File not found: {img_path}")
        return 1
    im = Image.open(img_path)
    w, h = im.size
    colors = len(im.getcolors(maxcolors=100000) or [])
    print(f"Image: {os.path.basename(img_path)}")
    print(f"Resolution: {w}x{h} px")
    print(f"Mode: {im.mode}")
    print(f"Unique colors: {colors if colors else '>100,000'}")
    
    # Check possible horizontal frame divisions
    for frames in [3, 4, 5, 6, 8, 9, 10, 12, 16]:
        if w % frames == 0:
            print(f"  -> Could be {frames} horizontal frames of {w // frames}x{h} px")
    return 0

def cmd_slice(args):
    sheet_path = args.sheet
    frames_count = args.frames
    out_dir = args.out_dir or os.path.splitext(sheet_path)[0] + "_frames"
    os.makedirs(out_dir, exist_ok=True)
    
    im = Image.open(sheet_path)
    w, h = im.size
    frame_w = w // frames_count
    
    print(f"Slicing {sheet_path} into {frames_count} frames of {frame_w}x{h} px -> {out_dir}")
    for i in range(frames_count):
        box = (i * frame_w, 0, (i + 1) * frame_w, h)
        frame = im.crop(box)
        out_file = os.path.join(out_dir, f"frame_{i:02d}.png")
        frame.save(out_file)
    print("Done slicing!")
    return 0

def cmd_assemble(args):
    in_dir = args.frames_dir
    out_sheet = args.out_sheet
    frame_files = sorted([os.path.join(in_dir, f) for f in os.listdir(in_dir) if f.lower().endswith(".png")])
    if not frame_files:
        print("No PNG frames found in directory.")
        return 1
        
    frames = [Image.open(f) for f in frame_files]
    frame_w, frame_h = frames[0].size
    total_w = frame_w * len(frames)
    
    sheet = Image.new("RGBA", (total_w, frame_h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * frame_w, 0))
        
    os.makedirs(os.path.dirname(os.path.abspath(out_sheet)), exist_ok=True)
    sheet.save(out_sheet)
    print(f"Assembled {len(frames)} frames into {out_sheet} ({total_w}x{frame_h} px)")
    return 0

def main():
    parser = argparse.ArgumentParser(description="Sprite Forge Helper for Godot RPG")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # info
    p_info = subparsers.add_parser("info", help="Inspect image dimensions, colors, and possible frame splits")
    p_info.add_argument("path", help="Path to image or sprite sheet")
    
    # slice
    p_slice = subparsers.add_parser("slice", help="Slice a horizontal spritesheet into individual frames")
    p_slice.add_argument("sheet", help="Path to sprite sheet")
    p_slice.add_argument("frames", type=int, help="Number of horizontal frames")
    p_slice.add_argument("--out-dir", help="Output directory")
    
    # assemble
    p_asm = subparsers.add_parser("assemble", help="Assemble multiple frames into a horizontal spritesheet")
    p_asm.add_argument("frames_dir", help="Directory with PNG frames")
    p_asm.add_argument("out_sheet", help="Path to save assembled sheet")
    
    args = parser.parse_args()
    if args.command == "info":
        return cmd_info(args)
    elif args.command == "slice":
        return cmd_slice(args)
    elif args.command == "assemble":
        return cmd_assemble(args)

if __name__ == "__main__":
    sys.exit(main() or 0)
