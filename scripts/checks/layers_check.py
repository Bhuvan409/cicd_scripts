#!/usr/bin/env python3
# yocto_checks.py - Yocto-specific validation checks

import os
import sys
import re
import subprocess
from pathlib import Path

# Environment variables
PR_NUMBER = os.environ.get('PR_NUMBER')
PR_COMMIT = os.environ.get('PR_COMMIT')
TARGET_DIR = os.environ.get('TARGET_DIR')
RESULTS_DIR = os.environ.get('RESULTS_DIR')
CHANGED_FILES = os.environ.get('CHANGED_FILES')

# Change to target directory
os.chdir(TARGET_DIR)

print(f"Running Yocto checks for PR #{PR_NUMBER}")
print(f"Commit: {PR_COMMIT}")

# Get changed files
with open(CHANGED_FILES, 'r') as f:
    changed_files = [line.strip() for line in f.readlines()]

# Filter for Yocto recipe files
recipe_files = [f for f in changed_files if f.endswith('.bb') or f.endswith('.bbappend') or f.endswith('.inc')]

if not recipe_files:
    print("No Yocto recipe files changed, skipping checks")
    sys.exit(0)

print(f"Checking {len(recipe_files)} recipe files")

errors = []

# Check recipe syntax
for recipe in recipe_files:
    if not os.path.exists(recipe):
        continue
    
    # Check for proper license
    with open(recipe, 'r') as f:
        content = f.read()
        
        # Check for LICENSE field
        if 'LICENSE' not in content and recipe.endswith('.bb'):
            errors.append(f"❌ {recipe}: Missing LICENSE field")
        
        # Check for proper dependencies
        if 'DEPENDS' in content and '+=' in content and 'DEPENDS +=' not in content:
            errors.append(f"❌ {recipe}: Possible incorrect DEPENDS append (use DEPENDS += instead)")
        
        # Check for proper PV format
        pv_match = re.search(r'PV\s*=\s*"([^"]*)"', content)
        if pv_match and not re.match(r'^[0-9]+(\.[0-9]+)*', pv_match.group(1)):
            errors.append(f"❌ {recipe}: PV format looks incorrect: {pv_match.group(1)}")

# Report results
if errors:
    for error in errors:
        print(error)
    sys.exit(1)
else:
    print("✅ All Yocto checks passed!")
    sys.exit(0)
