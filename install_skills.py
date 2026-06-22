#!/usr/bin/env python3
"""Install claude-skills as a Claude Code plugin marketplace (GitHub-sourced)."""

import json, os, shutil
from pathlib import Path

HOME = Path.home()
SRC = Path(r"C:\Users\LokiPad\AppData\Local\Temp\claude-skills-tmp")
DST = HOME / ".claude" / "plugins" / "marketplaces" / "claude-skills"
KM = HOME / ".claude" / "plugins" / "known_marketplaces.json"
ST = HOME / ".claude" / "settings.json"

# Step 1: Copy repo to marketplace dir
if not DST.exists():
    shutil.copytree(
        str(SRC), str(DST),
        ignore=shutil.ignore_patterns(".gemini", ".codex", ".git", "__pycache__")
    )
    print("✅ Step 1: Repo copied to marketplace directory")
else:
    print("ℹ️  Step 1: Already exists — skipping copy")

# Step 2: Register marketplace (GitHub source like the official one)
if KM.exists():
    known = json.loads(KM.read_text(encoding="utf-8"))
else:
    known = {}
known["claude-skills"] = {
    "source": {"source": "github", "repo": "alirezarezvani/claude-skills"},
    "installLocation": str(DST),
    "lastUpdated": None,
}
KM.write_text(json.dumps(known, indent=2), encoding="utf-8")
print("✅ Step 2: Marketplace registered in known_marketplaces.json")

# Step 3: Enable all plugins
mp_file = DST / ".claude-plugin" / "marketplace.json"
mp = json.loads(mp_file.read_text(encoding="utf-8"))
plugins = {}
for p in mp.get("plugins", []):
    plugins[f"claude-skills@{p['name']}"] = True

settings = json.loads(ST.read_text(encoding="utf-8"))
settings.setdefault("enabledPlugins", {}).update(plugins)
ST.write_text(json.dumps(settings, indent=2), encoding="utf-8")
print(f"✅ Step 3: {len(plugins)} plugins enabled in settings.json")

# Step 4: Verify
skill_count = 0
for root, dirs, files in os.walk(str(DST)):
    dirs[:] = [d for d in dirs if d not in (".gemini", ".codex", ".git")]
    if "SKILL.md" in files:
        skill_count += 1
plugin_json_count = 0
for root, dirs, files in os.walk(str(DST)):
    dirs[:] = [d for d in dirs if d not in (".gemini", ".codex", ".git")]
    if "plugin.json" in files and ".claude-plugin" in root:
        plugin_json_count += 1

print(f"\n{'='*50}")
print(f"  INSTALLATION COMPLETE")
print(f"{'='*50}")
print(f"  Marketplace:  claude-skills")
print(f"  Plugins:       {len(mp.get('plugins', []))}")
print(f"  Skills:        {skill_count}")
print(f"  Plugin files:  {plugin_json_count}")
print(f"\n  Plugin list:")
for i, p in enumerate(mp.get("plugins", []), 1):
    print(f"    {i:2d}. {p['name']}")

print(f"\n{'='*50}")
print(f"  🎯 Now run /reload-plugins in Claude Code to activate!")
print(f"{'='*50}")
