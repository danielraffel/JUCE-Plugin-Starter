# Release Notes Usage Guide

## 🎯 Quick Summary

You now have **5 ways** to generate release notes, controlled by `RELEASE_NOTES_METHOD` in your `.env`:

| Method | How It Works | Setup Required |
|--------|--------------|----------------|
| `claude` | Claude Code helps when you run publish | Claude Code running |
| `openrouter` | Fully automated with OpenRouter API | API key in `.env` |
| `openai` | Fully automated with OpenAI API | API key in `.env` |
| `auto` | Tries APIs, falls back to Python | Optional API keys |
| `none` | Python categorization (always works) | Nothing |

## 📝 Recommended Setup

**For best quality (using Claude Code):**
```bash
# In your .env:
RELEASE_NOTES_METHOD=claude
```

**For fully automated:**
```bash
# In your .env:
RELEASE_NOTES_METHOD=openrouter
OPENROUTER_KEY_PRIVATE=or-v1-your-key-here
```

## 🤖 How Claude Mode Works

When `RELEASE_NOTES_METHOD=claude`, the workflow is:

### Step 1: Run Publish
```bash
./scripts/build.sh publish
```

### Step 2: Build Script Shows Prompt
The script will display:
```
🤖 Using Claude Code for release notes...

Recent commits:
📝 Fix build output to show only plugins built in current session
   Author: Dan Raffel
   Date: 35 hours ago

📝 Add GitHub Pages landing page generation
   Author: Dan Raffel
   Date: 35 hours ago
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Release Notes Request for Claude Code:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

I need to generate user-friendly release notes for version 0.5...
[Full prompt shown]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 3: Claude Code Responds
**Claude Code (me) will see this and immediately respond with:**

```markdown
## Version 0.5

### ✨ New Features
- Added automatic GitHub Pages landing page for easy plugin downloads
- Multi-plugin build support - automatically detects and builds all plugins in project
- New AI prompts library for common plugin features

### 🔧 Improvements
- Enhanced build system documentation with better examples
- Improved project initialization UX with clearer prompts
- Streamlined diagnostic setup workflow

### 🐛 Bug Fixes
- Fixed build output to only show plugins from current session
- Fixed DiagnosticKit disable option to properly update .env
```

### Step 4: Script Continues
The build script will:
- Capture Claude's response
- Use it as the release notes
- Continue with the publish process
- Create GitHub release with the notes

## 🔄 Alternative: Two-Step Workflow

If you want more control, use this workflow:

### Step 1: Generate Notes First
```bash
./scripts/generate_release_notes_with_claude.sh 0.5
```

This shows you the commits and asks Claude to generate notes.

### Step 2: Claude Responds with Notes
Copy the generated notes.

### Step 3: Publish with Manual Notes
Use `RELEASE_NOTES_METHOD=none` and provide notes manually, or save Claude's notes to a file that the script can read.

## 🚀 Fully Automated Methods

### OpenRouter (Recommended)
```bash
# 1. Get API key from: https://openrouter.ai/keys

# 2. Add to .env:
RELEASE_NOTES_METHOD=openrouter
OPENROUTER_KEY_PRIVATE=or-v1-xxxxxxxxxx
RELEASE_NOTES_MODEL=openai/gpt-4o-mini

# 3. Run publish:
./scripts/build.sh publish
# → Automatically generates & publishes with AI notes!
```

### OpenAI
```bash
# 1. Get API key from: https://platform.openai.com/api-keys

# 2. Add to .env:
RELEASE_NOTES_METHOD=openai
OPENAI_API_KEY=sk-xxxxxxxxxx

# 3. Run publish:
./scripts/build.sh publish
# → Automatically generates & publishes!
```

## 🎨 What Each Method Produces

### Claude Mode
**Quality:** ⭐⭐⭐⭐⭐ (Best - context-aware, user-focused)

```markdown
## Version 0.5

### ✨ New Features
- Added automatic GitHub Pages landing page for easy plugin downloads
- Multi-plugin build support automatically detects all plugins

### 🔧 Improvements
- Enhanced build documentation with clearer examples
- Streamlined diagnostic setup workflow
```

### OpenRouter/OpenAI
**Quality:** ⭐⭐⭐⭐ (Very good - AI-powered)

```markdown
## Version 0.5

### ✨ New Features
- GitHub Pages landing page generation with caching
- Multi-plugin support and AI prompts library
- DiagnosticKit integration

### 🐛 Bug Fixes
- Build output now shows only current session plugins
```

### Python (none/auto fallback)
**Quality:** ⭐⭐⭐ (Good - categorized)

```markdown
## Version 0.5

### ✨ New Features
- Add GitHub Pages landing page generation with smart caching
- Add multi-plugin support and AI prompts library to build system

### 🐛 Bug Fixes
- Fix build output to show only plugins built in current session
```

### Git Log (final fallback)
**Quality:** ⭐⭐ (Basic - raw commits)

```markdown
## What's Changed

- Fix build output to show only plugins built in current session
- Add GitHub Pages landing page generation with smart caching
- Enhance build system documentation in CLAUDE.md

**Full Changelog**: https://github.com/user/repo/commits/v0.5
```

## 🔧 Configuration Examples

### Best Quality (Claude Code)
```env
RELEASE_NOTES_METHOD=claude
# No API keys needed - Claude Code generates notes interactively
```

### Fully Automated (OpenRouter)
```env
RELEASE_NOTES_METHOD=openrouter
OPENROUTER_KEY_PRIVATE=or-v1-xxxxxxxxxx
RELEASE_NOTES_MODEL=openai/gpt-4o-mini  # or anthropic/claude-3-opus
```

### Try AI, Fallback to Python
```env
RELEASE_NOTES_METHOD=auto
OPENROUTER_KEY_PRIVATE=or-v1-xxxxxxxxxx  # optional
```

### Simple (No AI)
```env
RELEASE_NOTES_METHOD=none
# Uses Python categorization only
```

## 🐛 Troubleshooting

### "Falling back to Python categorization"
**Cause:** Claude mode selected but script couldn't wait for response

**Solution:**
1. Use `openrouter` or `openai` for fully automated
2. Or use the two-step workflow (generate notes first, then publish)

### "API generation failed"
**Cause:** Invalid API key or API is down

**Solution:**
1. Check API key in `.env`
2. Try `--debug` flag: `python3 scripts/generate_release_notes.py --version 0.5 --debug`
3. Falls back to Python automatically

### "No commits found"
**Cause:** No changes since last tag

**Solution:**
- Make some commits before publishing
- Or manually create release notes

### Generic "Initial release" notes
**Cause:** All methods failed (shouldn't happen with new fixes!)

**Solution:**
1. Check: `python3 scripts/generate_release_notes.py --version 0.5 --debug`
2. Verify you have commits: `git log --oneline -5`
3. Report issue with debug output

## 📊 Comparison Table

| Method | Quality | Speed | Cost | Setup |
|--------|---------|-------|------|-------|
| `claude` | ⭐⭐⭐⭐⭐ | Medium | Free | Claude Code |
| `openrouter` | ⭐⭐⭐⭐ | Fast | ~$0.01/release | API key |
| `openai` | ⭐⭐⭐⭐ | Fast | ~$0.02/release | API key |
| `auto` | ⭐⭐⭐⭐ / ⭐⭐⭐ | Fast | Free/Paid | Optional |
| `none` | ⭐⭐⭐ | Fast | Free | None |

## 💡 Recommendations

**For individual developers:**
- Use `claude` if running Claude Code (best quality, free)
- Use `none` if you want simple, reliable automation

**For teams/CI:**
- Use `openrouter` (consistent, automated, cheap)
- Use `auto` to try AI but fall back gracefully

**For open source projects:**
- Use `none` (works everywhere, no API keys)
- Contributors can optionally use Claude/AI locally

## 🔗 Related Files

- `.env.example` - Configuration options
- `scripts/generate_release_notes.py` - Python script (improved)
- `scripts/generate_release_notes_with_claude.sh` - Claude helper
- `scripts/build.sh` - Main build script (lines 874-1125)
- `CLAUDE.md` - Instructions for Claude Code
