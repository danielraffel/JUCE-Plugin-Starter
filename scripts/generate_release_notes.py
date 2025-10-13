#!/usr/bin/env python3
"""
Generate release notes for plugin releases
Supports AI-enhanced notes via OpenRouter/OpenAI or fallback to git history
"""

import sys
import os
import subprocess
import json
import re
from datetime import datetime

def get_git_history(since_tag=None):
    """Get git commits since last tag or specified tag"""
    try:
        # Get last tag if not specified
        if not since_tag:
            result = subprocess.run(
                ['git', 'describe', '--tags', '--abbrev=0'],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                since_tag = result.stdout.strip()

        # Get commits since tag (or all commits if no tags)
        if since_tag:
            commit_range = f"{since_tag}..HEAD"
        else:
            # For repos without tags, get all commits (safer than HEAD~10)
            # First, try to get commit count
            count_result = subprocess.run(
                ['git', 'rev-list', '--count', 'HEAD'],
                capture_output=True, text=True, check=False
            )

            if count_result.returncode == 0:
                commit_count = int(count_result.stdout.strip())
                if commit_count == 0:
                    print("Warning: No commits found in repository", file=sys.stderr)
                    return "Initial release"
                elif commit_count == 1:
                    # For single commit, just use HEAD
                    commit_range = "HEAD"
                else:
                    # Get last 10 commits, or all if fewer than 10
                    lookback = min(10, commit_count - 1)
                    commit_range = f"HEAD~{lookback}..HEAD"
            else:
                # Fallback: just try to get recent commits
                commit_range = "HEAD"

        # Get the commits
        result = subprocess.run(
            ['git', 'log', '--oneline', '--no-merges', commit_range],
            capture_output=True, text=True, check=False
        )

        if result.returncode != 0:
            print(f"Warning: git log failed: {result.stderr}", file=sys.stderr)
            return "Initial release"

        commits = result.stdout.strip()
        if not commits:
            print("Warning: No commits found in range", file=sys.stderr)
            return "Initial release"

        return commits
    except subprocess.CalledProcessError as e:
        print(f"Error getting git history: {e}", file=sys.stderr)
        return "Initial release"
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return "Initial release"

def categorize_commits(commits):
    """Categorize commits by type based on conventional commit patterns"""
    categories = {
        'features': [],
        'fixes': [],
        'improvements': [],
        'other': []
    }
    
    for line in commits.split('\n'):
        if not line:
            continue
        
        # Remove commit hash
        parts = line.split(' ', 1)
        if len(parts) < 2:
            continue
        message = parts[1]
        
        # Categorize by common patterns
        lower_msg = message.lower()
        if any(word in lower_msg for word in ['add', 'feat', 'feature', 'new']):
            categories['features'].append(message)
        elif any(word in lower_msg for word in ['fix', 'bug', 'repair', 'resolve']):
            categories['fixes'].append(message)
        elif any(word in lower_msg for word in ['update', 'improve', 'enhance', 'optimize', 'refactor']):
            categories['improvements'].append(message)
        else:
            categories['other'].append(message)
    
    return categories

def generate_ai_release_notes(commits, version):
    """Generate AI-enhanced release notes using OpenRouter or OpenAI"""
    import urllib.request
    import urllib.error
    
    # Load environment variables
    env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
    env_vars = {}
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key] = value.strip('"').strip("'")
    
    openrouter_key = env_vars.get('OPENROUTER_KEY_PRIVATE', os.environ.get('OPENROUTER_KEY_PRIVATE'))
    openai_key = env_vars.get('OPENAI_API_KEY', os.environ.get('OPENAI_API_KEY'))
    model = env_vars.get('RELEASE_NOTES_MODEL', 'openai/gpt-4o-mini')
    
    if not openrouter_key and not openai_key:
        return None
    
    prompt = f"""Based on these git commits for version {version}, write concise, user-friendly release notes in markdown format. 
Focus on features and improvements users would care about. Group changes by category (Features, Fixes, Improvements).
Keep it brief but informative. Do not include commit hashes or technical implementation details.

Commits:
{commits}

Respond with clean markdown only, no code blocks or extra text."""
    
    # Try OpenRouter first
    if openrouter_key:
        try:
            data = json.dumps({
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 500
            }).encode('utf-8')
            
            req = urllib.request.Request(
                "https://openrouter.ai/api/v1/chat/completions",
                data=data,
                headers={
                    "Authorization": f"Bearer {openrouter_key}",
                    "Content-Type": "application/json"
                }
            )
            
            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode('utf-8'))
                return result['choices'][0]['message']['content']
        except Exception as e:
            print(f"OpenRouter API failed: {e}", file=sys.stderr)
    
    # Fallback to OpenAI
    if openai_key:
        try:
            data = json.dumps({
                "model": "gpt-4o-mini",
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 500
            }).encode('utf-8')
            
            req = urllib.request.Request(
                "https://api.openai.com/v1/chat/completions",
                data=data,
                headers={
                    "Authorization": f"Bearer {openai_key}",
                    "Content-Type": "application/json"
                }
            )
            
            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode('utf-8'))
                return result['choices'][0]['message']['content']
        except Exception as e:
            print(f"OpenAI API failed: {e}", file=sys.stderr)
    
    return None

def generate_standard_release_notes(commits, version, format='markdown'):
    """Generate standard release notes from git history"""
    categories = categorize_commits(commits)
    
    if format == 'markdown':
        notes = f"## Version {version}\n\n"
        
        if categories['features']:
            notes += "### ✨ New Features\n"
            for item in categories['features']:
                notes += f"- {item}\n"
            notes += "\n"
        
        if categories['fixes']:
            notes += "### 🐛 Bug Fixes\n"
            for item in categories['fixes']:
                notes += f"- {item}\n"
            notes += "\n"
        
        if categories['improvements']:
            notes += "### 🔧 Improvements\n"
            for item in categories['improvements']:
                notes += f"- {item}\n"
            notes += "\n"
        
        if categories['other'] and not (categories['features'] or categories['fixes'] or categories['improvements']):
            notes += "### 📝 Changes\n"
            for item in categories['other']:
                notes += f"- {item}\n"
        
        return notes.strip()
    
    elif format == 'sparkle':
        # HTML format for Sparkle updater
        notes = f"<h2>Version {version}</h2>\n\n"
        
        if categories['features']:
            notes += "<h3>✨ New Features</h3>\n<ul>\n"
            for item in categories['features']:
                notes += f"<li>{item}</li>\n"
            notes += "</ul>\n\n"
        
        if categories['fixes']:
            notes += "<h3>🐛 Bug Fixes</h3>\n<ul>\n"
            for item in categories['fixes']:
                notes += f"<li>{item}</li>\n"
            notes += "</ul>\n\n"
        
        if categories['improvements']:
            notes += "<h3>🔧 Improvements</h3>\n<ul>\n"
            for item in categories['improvements']:
                notes += f"<li>{item}</li>\n"
            notes += "</ul>\n\n"
        
        if categories['other'] and not (categories['features'] or categories['fixes'] or categories['improvements']):
            notes += "<h3>📝 Changes</h3>\n<ul>\n"
            for item in categories['other']:
                notes += f"<li>{item}</li>\n"
            notes += "</ul>\n"
        
        return notes.strip()
    
    return commits

def main():
    import argparse

    parser = argparse.ArgumentParser(description='Generate release notes from git history')
    parser.add_argument('--version', help='Version number for the release', default='1.0.0')
    parser.add_argument('--since', help='Generate notes since this tag', default=None)
    parser.add_argument('--format', choices=['markdown', 'sparkle'], default='markdown',
                        help='Output format (markdown or sparkle HTML)')
    parser.add_argument('--ai', action='store_true', help='Use AI to enhance release notes')
    parser.add_argument('--debug', action='store_true', help='Show debug information')

    args = parser.parse_args()

    if args.debug:
        print("🔍 Debug mode enabled", file=sys.stderr)
        print(f"   Version: {args.version}", file=sys.stderr)
        print(f"   Since tag: {args.since or '(none - will use last tag or recent commits)'}", file=sys.stderr)
        print(f"   Format: {args.format}", file=sys.stderr)
        print(f"   AI enhancement: {'enabled' if args.ai else 'disabled'}", file=sys.stderr)
        print("", file=sys.stderr)

    # Get git history
    if args.debug:
        print("📝 Getting git history...", file=sys.stderr)

    commits = get_git_history(args.since)

    if args.debug:
        commit_lines = len(commits.split('\n')) if commits != "Initial release" else 0
        print(f"   Found {commit_lines} commits", file=sys.stderr)
        print("", file=sys.stderr)

    # Try AI-enhanced notes if requested
    if args.ai:
        if args.debug:
            print("🤖 Attempting AI-enhanced release notes...", file=sys.stderr)

        ai_notes = generate_ai_release_notes(commits, args.version)
        if ai_notes:
            if args.debug:
                print("✅ AI generation successful", file=sys.stderr)

            # Convert to requested format if needed
            if args.format == 'sparkle' and not ai_notes.startswith('<'):
                # Convert markdown to HTML
                ai_notes = ai_notes.replace('## ', '<h2>').replace('\n\n', '</h2>\n\n')
                ai_notes = ai_notes.replace('### ', '<h3>').replace('\n\n', '</h3>\n\n')
                ai_notes = re.sub(r'^- (.+)$', r'<li>\1</li>', ai_notes, flags=re.MULTILINE)
                ai_notes = re.sub(r'(<li>.*</li>)', r'<ul>\n\1\n</ul>', ai_notes, flags=re.DOTALL)
            print(ai_notes)
            return
        else:
            if args.debug:
                print("⚠️  AI generation failed, falling back to standard", file=sys.stderr)
                print("", file=sys.stderr)

    # Generate standard notes
    if args.debug:
        print("📝 Generating standard release notes...", file=sys.stderr)

    notes = generate_standard_release_notes(commits, args.version, args.format)

    if args.debug:
        print("✅ Release notes generated", file=sys.stderr)
        print("", file=sys.stderr)

    print(notes)

if __name__ == "__main__":
    main()