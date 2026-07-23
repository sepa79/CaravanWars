import re, json, os, io, hashlib, pathlib

GD_FUNC_RE = re.compile(r'^\s*func\s+([A-Za-z0-9_]+)\s*\(', re.MULTILINE)
GD_CLASS_RE = re.compile(r'^\s*class_name\s+([A-Za-z0-9_]+)', re.MULTILINE)
GD_EXTENDS_RE = re.compile(r'^\s*extends\s+([A-Za-z0-9_./"]+)', re.MULTILINE)
GD_SIGNAL_RE = re.compile(r'^\s*signal\s+([A-Za-z0-9_]+)', re.MULTILINE)
GD_EXPORT_RE = re.compile(r'^\s*@export\s*(?:var\s+)?([A-Za-z0-9_]+)', re.MULTILINE)
GD_TR_RE = re.compile(r'tr\(\s*"(.*?)"\s*\)')

TS_NODE_RE = re.compile(r'^\[node name="([^"]+)"(?:\s+type="([^"]*)")?(?:\s+parent="([^"]*)")?\]', re.MULTILINE)
TS_CONN_RE = re.compile(r'^\[connection signal="([^"]+)"\s+from="([^"]+)"\s+to="([^"]+)"\s+method="([^"]+)"\]', re.MULTILINE)
TS_SCRIPT_RE = re.compile(r'^script = (.+)$', re.MULTILINE)

def sha1_bytes(b: bytes) -> str:
    h = hashlib.sha1(); h.update(b); return h.hexdigest()

def classify(path: str) -> str:
    e = pathlib.Path(path).suffix.lower()
    if e == '.gd': return 'gdscript'
    if e == '.tscn': return 'godot_scene'
    if e == '.tres': return 'godot_resource'
    if e == '.md': return 'markdown'
    if e == '.json': return 'json'
    if e in {'.po','.csv'}: return 'i18n'
    if e in {'.cfg','.ini','.yml','.yaml'}: return 'config'
    return 'other'

def parse_gd(path: str, text: str):
    return {
        "file": path,
        "class_name": (GD_CLASS_RE.search(text or "") or [None, None])[1],
        "extends": (GD_EXTENDS_RE.search(text or "") or [None, None])[1],
        "signals": GD_SIGNAL_RE.findall(text or ""),
        "exports": GD_EXPORT_RE.findall(text or ""),
        "functions": GD_FUNC_RE.findall(text or ""),
        "tr_strings": GD_TR_RE.findall(text or ""),
    }

def parse_tscn(path: str, text: str):
    nodes = [{"name": n, "type": t or "", "parent": p or ""} for n,t,p in TS_NODE_RE.findall(text or "")]
    conns = [{"signal": s, "from": f, "to": to, "method": m} for s,f,to,m in TS_CONN_RE.findall(text or "")]
    scripts = TS_SCRIPT_RE.findall(text or "")
    return {"file": path, "nodes": nodes, "connections": conns, "scripts_raw": scripts}
