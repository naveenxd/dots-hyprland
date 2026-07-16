#!/usr/bin/env python3
"""
symlink-dots.py
Symlinks all files in dots-hyprland/dots/ to their corresponding home directory paths.
- Identical files: replaced with symlinks
- New files (not in home yet): symlinked
- Different files: skipped, listed at the end
- Already symlinked to repo: left alone
"""

import os
import hashlib

REPO_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DOTS_DIR = os.path.join(REPO_DIR, "dots")
HOME_DIR = os.path.expanduser("~")

identical_symlinked = []
new_symlinked = []
already_symlinked = []
non_identical = []

def md5(filepath):
    h = hashlib.md5()
    try:
        with open(filepath, 'rb') as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return None

for root, dirs, files in os.walk(REPO_DOTS_DIR):
    for file in files:
        repo_path = os.path.join(root, file)
        rel_path  = os.path.relpath(repo_path, REPO_DOTS_DIR)
        home_path = os.path.join(HOME_DIR, rel_path)

        if os.path.islink(home_path):
            abs_target = os.path.realpath(home_path)
            if abs_target == repo_path:
                already_symlinked.append(rel_path)
            else:
                # Symlink points somewhere else — check content
                if md5(repo_path) == md5(abs_target):
                    os.unlink(home_path)
                    os.symlink(repo_path, home_path)
                    identical_symlinked.append(rel_path)
                else:
                    non_identical.append((rel_path, "symlink points elsewhere with different content"))
        elif os.path.exists(home_path):
            if os.path.isdir(home_path):
                non_identical.append((rel_path, "home path is a directory"))
            elif md5(repo_path) == md5(home_path):
                os.unlink(home_path)
                os.symlink(repo_path, home_path)
                identical_symlinked.append(rel_path)
            else:
                non_identical.append((rel_path, "content differs"))
        else:
            os.makedirs(os.path.dirname(home_path), exist_ok=True)
            os.symlink(repo_path, home_path)
            new_symlinked.append(rel_path)

print(f"✓ {len(already_symlinked)} already symlinked (skipped)")
print(f"✓ {len(identical_symlinked)} identical files → symlinked")
print(f"✓ {len(new_symlinked)} new files → symlinked")
print(f"✗ {len(non_identical)} files differ (skipped):")
for path, reason in sorted(non_identical):
    print(f"   {path}  ({reason})")
