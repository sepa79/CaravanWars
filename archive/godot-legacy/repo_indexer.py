#!/usr/bin/env python3
import os, io, sys, re, json, zipfile, shutil, pathlib, hashlib, argparse
from datetime import datetime
from fnmatch import fnmatch
from godot_indexers import parse_gd, parse_tscn, classify

DEFAULT_IGNORES = [
    ".git/**",".git/","*.png","*.jpg","*.jpeg","*.gif","*.mp3","*.ogg","*.wav","*.mp4","*.avi",
    "*.zip","*.7z","*.tar","*.rar","*.log","*.tmp","*.cache",
    ".import/**",".export/**","*.import","*.translation","*.mo","*.mono/**","mono/**","bin/**","build/**",
    "addons/asset*/**","_cw_index/**"
]

def load_custom_ignores(root):
    ig_path = os.path.join(root, ".indexignore")
    globs = []
    if os.path.exists(ig_path):
        with open(ig_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"): continue
                if line.endswith("/") and not line.endswith("**"):
                    line = line + "**"
                globs.append(line)
    return globs

def walk_files(root, ignore_globs):
    for dirpath, dirnames, filenames in os.walk(root):
        pruned = []
        for d in list(dirnames):
            full = os.path.join(dirpath, d).replace("\\","/")
            if any(fnmatch(full, g) for g in ignore_globs + DEFAULT_IGNORES):
                pruned.append(d)
        for d in pruned:
            dirnames.remove(d)
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            p = full.replace("\\","/")
            if any(fnmatch(p, g) for g in ignore_globs + DEFAULT_IGNORES):
                continue
            yield full

def read_text(path):
    for enc in ("utf-8","utf-16"):
        try:
            with open(path, "r", encoding=enc) as f:
                return f.read()
        except: pass
    return ""

def sha1_file(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def index_folder(src_root, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    ignores = load_custom_ignores(src_root)

    manifest, symbols, scenes, strings, imports, todos = [], [], [], [], [], []

    for path in walk_files(src_root, ignores):
        rel = os.path.relpath(path, src_root).replace("\\","/")
        kind = classify(path)
        size = os.path.getsize(path)
        sha1 = sha1_file(path)
        manifest.append({"path": rel, "kind": kind, "size": size, "sha1": sha1})

        text = ""
        if kind in ("gdscript","godot_scene","markdown","json","i18n","godot_resource","config","other"):
            text = read_text(path)

        if text:
            for m in re.finditer(r'(TODO|FIXME|HACK)[:\s-]+(.*)', text, flags=re.IGNORECASE):
                todos.append({"path": rel, "tag": m.group(1), "note": m.group(2)[:200]})

        if kind == "gdscript":
            info = parse_gd(rel, text)
            symbols.append(info)
            edges = []
            for m in re.finditer(r'(?:load|preload)\("([^"]+)"\)', text or ""):
                edges.append(m.group(1))
            ext = info.get("extends") or ""
            if ext and (ext.endswith(".gd") or "/" in ext):
                edges.append(ext)
            if edges:
                imports.append({"from": rel, "to": edges})
            for s in info.get("tr_strings", []):
                strings.append({"key": s, "path": rel, "where": "gdscript"})

        elif kind == "godot_scene":
            scenes.append(parse_tscn(rel, text))

        elif kind == "i18n":
            if rel.lower().endswith(".po"):
                for m in re.finditer(r'^msgid\s+"(.*)"$', text, flags=re.MULTILINE):
                    strings.append({"key": m.group(1), "path": rel, "where": "po"})
            if rel.lower().endswith(".csv"):
                for line in text.splitlines():
                    parts = [p.strip() for p in line.split(",")]
                    if len(parts) >= 2 and parts[0] and parts[0] != "key":
                        strings.append({"key": parts[0], "path": rel, "where": "csv"})

    idx = os.path.join(out_dir, "index")
    os.makedirs(idx, exist_ok=True)

    def dump(name, obj):
        with open(os.path.join(idx, name), "w", encoding="utf-8") as f:
            json.dump(obj, f, ensure_ascii=False, indent=2)

    dump("manifest.json", manifest)
    dump("symbols.json", symbols)
    dump("scenes.json", scenes)
    dump("strings.json", strings)
    dump("imports.json", imports)
    dump("docs_todos.json", todos)

    gd_count = sum(1 for m in manifest if m["kind"] == "gdscript")
    scene_count = sum(1 for m in manifest if m["kind"] == "godot_scene")
    md_count = sum(1 for m in manifest if m["kind"] == "markdown")

    report = []
    report.append(f"# Index Report — {datetime.utcnow().isoformat()}Z")
    report.append("")
    report.append(f"- Files indexed: {len(manifest)}")
    report.append(f"- GDScript files: {gd_count}, Scenes: {scene_count}, Docs/MD: {md_count}")
    report.append("")
    report.append("## Top-level symbols (class_name)")
    classes = [s for s in symbols if s.get("class_name")]
    for s in classes[:50]:
        report.append(f"- `{s['class_name']}` (extends: {s.get('extends')}) — file: {s['file']}")
    report.append("")
    report.append("## TODO/FIXME samples")
    for t in todos[:20]:
        report.append(f"- {t['path']}: {t['tag']} {t['note']}")
    with open(os.path.join(idx, "index_report.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(report))

    bundle = os.path.join(out_dir, "index_bundle.zip")
    with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED) as z:
        for fn in os.listdir(idx):
            z.write(os.path.join(idx, fn), arcname=fn)
    return bundle

def index_zip(zip_path, out_dir):
    tmp = os.path.join(out_dir, "_unzipped")
    os.makedirs(tmp, exist_ok=True)
    with zipfile.ZipFile(zip_path, "r") as z:
        z.extractall(tmp)
    entries = [e for e in os.listdir(tmp) if not e.startswith("__MACOSX")]
    root = tmp
    if len(entries) == 1 and os.path.isdir(os.path.join(tmp, entries[0])):
        root = os.path.join(tmp, entries[0])
    return index_folder(root, out_dir)

def run(args):
    # Zero-config defaults
    if not (args.path or args.zip or args.out):
        cwd = os.getcwd()
        out = os.path.join(cwd, "_cw_index")
        os.makedirs(out, exist_ok=True)
        bundle = index_folder(cwd, out)
        print(bundle)
        return

    # Parametrized modes
    os.makedirs(args.out, exist_ok=True)
    if args.path:
        bundle = index_folder(args.path, args.out)
    else:
        bundle = index_zip(args.zip, args.out)
    print(bundle)

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="CaravanWars/Godot repo indexer (drop-in)")
    ap.add_argument("--path", help="Path to repo folder")
    ap.add_argument("--zip", help="Path to repo zip")
    ap.add_argument("--out", help="Output folder (default: ./_cw_index when no params)")
    args = ap.parse_args()
    run(args)
