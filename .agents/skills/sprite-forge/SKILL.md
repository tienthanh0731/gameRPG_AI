---
name: sprite-forge
description: >-
  Tooling and pipeline for generating, checking, and packaging 2D pixel art, sprite sheets,
  and animations for Godot 4 using Agent Sprite Forge.
---

# Sprite Forge Pipeline Guide

This skill provides direct access to the `agent-sprite-forge` pipeline located in `.external_tools/agent-sprite-forge/`.

## Key Capabilities

1. **Sprite Sheet Quality Control (`sheet_qc.py`):**
   - Detects frame spill, cutoffs, alignment issues, and color drift.
   - Usage:
     ```bash
     python .external_tools/agent-sprite-forge/skills/generate2dsprite/scripts/sheet_qc.py spill --input <raw_sheet.png> --rows <r> --cols <c> --output-dir <qc_dir>
     ```

2. **Pixel-Look Generation & Quantization (`pixel_look.py`):**
   - Converts high-resolution concept art or AI art into true 1x grid-aligned pixel art with a unified color palette.
   - Usage:
     ```bash
     python .external_tools/agent-sprite-forge/skills/generate2dsprite/scripts/pixel_look.py master --picture <input.png> --output <pixel_sprite.png>
     ```

3. **Frame Slicing & Assembly (`assemble_frames.py`):**
   - Stitches individual animation frames into seamless Godot horizontal strips with uniform cell sizing.

4. **Godot Engine Export (`export_godot.py`):**
   - Automatically exports SpriteFrames resources and animation sets ready for Godot 4.
