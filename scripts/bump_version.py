#!/usr/bin/env python3
"""
Version management script for JUCE plugin projects
Reads and updates version numbers in .env file
"""

import sys
import os
import re
from datetime import datetime

def read_env_file(env_path):
    """Read the .env file and return as dictionary"""
    env_vars = {}
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    if '=' in line:
                        key, value = line.split('=', 1)
                        env_vars[key] = value.strip('"').strip("'")
    return env_vars

def write_env_file(env_path, env_vars):
    """Write the updated .env file preserving comments and structure"""
    lines = []
    updated_keys = set()
    
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            for line in f:
                original_line = line.rstrip()
                if line.strip() and not line.strip().startswith('#'):
                    if '=' in line:
                        key = line.split('=', 1)[0].strip()
                        if key in ['VERSION_MAJOR', 'VERSION_MINOR', 'VERSION_PATCH', 'VERSION_BUILD']:
                            lines.append(f"{key}={env_vars.get(key, '0')}")
                            updated_keys.add(key)
                        else:
                            lines.append(original_line)
                    else:
                        lines.append(original_line)
                else:
                    lines.append(original_line)
    
    # Add any missing version keys
    for key in ['VERSION_MAJOR', 'VERSION_MINOR', 'VERSION_PATCH', 'VERSION_BUILD']:
        if key not in updated_keys:
            lines.append(f"{key}={env_vars.get(key, '0')}")
    
    with open(env_path, 'w') as f:
        f.write('\n'.join(lines) + '\n')

def get_current_version(env_path):
    """Get current version from .env file"""
    env_vars = read_env_file(env_path)
    
    version = {
        'major': int(env_vars.get('VERSION_MAJOR', '0')),
        'minor': int(env_vars.get('VERSION_MINOR', '0')),
        'patch': int(env_vars.get('VERSION_PATCH', '1')),
        'build': int(env_vars.get('VERSION_BUILD', '0'))
    }
    
    return version

def bump_version(version, bump_type='patch'):
    """Increment version based on bump type"""
    new_version = version.copy()
    
    if bump_type == 'major':
        new_version['major'] += 1
        new_version['minor'] = 0
        new_version['patch'] = 0
    elif bump_type == 'minor':
        new_version['minor'] += 1
        new_version['patch'] = 0
    elif bump_type == 'patch':
        new_version['patch'] += 1
    elif bump_type == 'build':
        # Build number always increments
        pass
    
    # Always increment build number
    new_version['build'] += 1
    
    # Enforce Audio Unit version limits (each component must be 0-255)
    if new_version['major'] > 255:
        raise ValueError(f"Major version {new_version['major']} exceeds AU limit of 255")
    if new_version['minor'] > 255:
        raise ValueError(f"Minor version {new_version['minor']} exceeds AU limit of 255")
    if new_version['patch'] > 255:
        raise ValueError(f"Patch version {new_version['patch']} exceeds AU limit of 255")
    
    # Auto-rollover patch to minor, minor to major if needed
    if new_version['patch'] > 255:
        new_version['patch'] = 0
        new_version['minor'] += 1
    if new_version['minor'] > 255:
        new_version['minor'] = 0
        new_version['major'] += 1
    
    return new_version

def update_version_in_env(env_path, version):
    """Update version numbers in .env file"""
    env_vars = read_env_file(env_path)
    
    env_vars['VERSION_MAJOR'] = str(version['major'])
    env_vars['VERSION_MINOR'] = str(version['minor'])
    env_vars['VERSION_PATCH'] = str(version['patch'])
    env_vars['VERSION_BUILD'] = str(version['build'])
    
    write_env_file(env_path, env_vars)

def format_version(version, include_build=False):
    """Format version as string"""
    v = f"{version['major']}.{version['minor']}.{version['patch']}"
    if include_build:
        v += f".{version['build']}"
    return v

def update_cmake_version(project_root, version):
    """Update version in CMakeLists.txt if it exists"""
    cmake_path = os.path.join(project_root, 'CMakeLists.txt')
    if not os.path.exists(cmake_path):
        return
    
    with open(cmake_path, 'r') as f:
        content = f.read()
    
    # Update VERSION in project() command
    content = re.sub(
        r'(project\([^)]*VERSION\s+)\d+\.\d+\.\d+',
        f'\\g<1>{version["major"]}.{version["minor"]}.{version["patch"]}',
        content
    )
    
    with open(cmake_path, 'w') as f:
        f.write(content)

def main():
    # Parse command line arguments
    bump_type = 'patch'  # default
    export_only = False
    dry_run = False
    
    for arg in sys.argv[1:]:
        if arg in ['major', 'minor', 'patch', 'build']:
            bump_type = arg
        elif arg == '--export-only':
            export_only = True
        elif arg == '--dry-run':
            dry_run = True
        elif arg in ['-h', '--help']:
            print("""
Usage: bump_version.py [bump_type] [options]

Bump Types:
  major       Increment major version (X.0.0)
  minor       Increment minor version (0.X.0)
  patch       Increment patch version (0.0.X) [default]
  build       Only increment build number

Options:
  --export-only   Only export current version, don't bump
  --dry-run       Show what would be changed without modifying files
  -h, --help      Show this help message

Examples:
  bump_version.py              # Bump patch version
  bump_version.py minor        # Bump minor version
  bump_version.py --export-only # Export current version for shell
""")
            return
    
    # Get paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    env_path = os.path.join(project_root, '.env')
    
    # Get current version
    current = get_current_version(env_path)
    
    if export_only:
        # Export version as shell variables
        print(f"export PROJECT_VERSION={format_version(current)}")
        print(f"export PROJECT_VERSION_FULL={format_version(current, include_build=True)}")
        print(f"export VERSION_MAJOR={current['major']}")
        print(f"export VERSION_MINOR={current['minor']}")
        print(f"export VERSION_PATCH={current['patch']}")
        print(f"export VERSION_BUILD={current['build']}")
        # Calculate AU version integer
        au_version = (current['major'] << 16) | (current['minor'] << 8) | current['patch']
        print(f"export AU_VERSION_INT={au_version}")
        return
    
    # Bump the version
    new_version = bump_version(current, bump_type)
    
    # Display changes
    print(f"Version bump: {format_version(current)} → {format_version(new_version)}")
    print(f"Build number: {current['build']} → {new_version['build']}")
    
    # Show AU version integer for debugging
    au_version = (new_version['major'] << 16) | (new_version['minor'] << 8) | new_version['patch']
    print(f"AU version int: {au_version} (0x{au_version:06X})")
    
    if dry_run:
        print("\n[DRY RUN] No files were modified")
        return
    
    # Update files
    print("\nUpdating version files...")
    
    # Update .env
    update_version_in_env(env_path, new_version)
    print(f"  ✓ Updated .env")
    
    # Update CMakeLists.txt if it exists
    update_cmake_version(project_root, new_version)
    if os.path.exists(os.path.join(project_root, 'CMakeLists.txt')):
        print(f"  ✓ Updated CMakeLists.txt")
    
    print(f"\n✅ Version bumped to {format_version(new_version)} (build {new_version['build']})")

if __name__ == "__main__":
    main()