# RELEASE_NOTES_METHOD Configuration

## ✨ Quick Start

Add this to your `.env` file to control how release notes are generated:

```env
RELEASE_NOTES_METHOD=claude
```

## 📋 Available Methods

### `claude` - Claude Code Interactive (Recommended if using Claude Code)

**How it works:**
1. Run `./scripts/build.sh publish`
2. Script shows commits and a prompt
3. Claude Code generates notes based on the prompt
4. Script uses Python categorization as fallback
5. Continues publishing

**Pros:**
- Best quality (context-aware, user-focused)
- Free (no API costs)
- Uses tool you're already running

**Cons:**
- Requires Claude Code to be active
- Falls back to Python if not interactive

**Setup:**
```env
RELEASE_NOTES_METHOD=claude
# No API keys needed!
```

---

### `openrouter` - OpenRouter API (Best for Full Automation)

**How it works:**
1. Run `./scripts/build.sh publish`
2. Automatically calls OpenRouter API
3. Gets AI-generated notes
4. Publishes immediately

**Pros:**
- Fully automated
- High quality AI notes
- Cheap (~$0.01 per release)
- Many model choices

**Cons:**
- Requires API key
- Costs money (minimal)

**Setup:**
```env
RELEASE_NOTES_METHOD=openrouter
OPENROUTER_KEY_PRIVATE=or-v1-xxxxxxxxxx
RELEASE_NOTES_MODEL=openai/gpt-4o-mini  # optional, defaults to this
```

Get key at: https://openrouter.ai/keys

---

### `openai` - OpenAI API

**How it works:**
Same as OpenRouter but uses OpenAI directly.

**Pros:**
- Fully automated
- High quality (GPT-4)

**Cons:**
- Requires API key
- Slightly more expensive than OpenRouter

**Setup:**
```env
RELEASE_NOTES_METHOD=openai
OPENAI_API_KEY=sk-xxxxxxxxxx
```

Get key at: https://platform.openai.com/api-keys

---

### `auto` - Smart Fallback

**How it works:**
1. Tries OpenRouter if `OPENROUTER_KEY_PRIVATE` exists
2. Tries OpenAI if `OPENAI_API_KEY` exists
3. Falls back to Python categorization

**Pros:**
- Flexible
- Works with or without API keys
- Good default for teams

**Cons:**
- Unpredictable (depends on what keys exist)

**Setup:**
```env
RELEASE_NOTES_METHOD=auto
# Optionally add API keys for AI enhancement:
OPENROUTER_KEY_PRIVATE=or-v1-xxxxxxxxxx
```

---

### `none` - Python Categorization Only

**How it works:**
Uses the improved Python script to categorize commits into Features/Fixes/Improvements.

**Pros:**
- Always works (no dependencies)
- Free
- Fast
- Consistent
- No API keys needed

**Cons:**
- Basic categorization (not as polished as AI)

**Setup:**
```env
RELEASE_NOTES_METHOD=none
# That's it!
```

---

## 🎯 Which Should You Use?

### You're using Claude Code actively
```env
RELEASE_NOTES_METHOD=claude
```
**Best quality, interactive, free**

### You want fully automated with best quality
```env
RELEASE_NOTES_METHOD=openrouter
OPENROUTER_KEY_PRIVATE=or-v1-xxxxxxxxxx
```
**Set it and forget it, ~$0.01 per release**

### You want simple and free
```env
RELEASE_NOTES_METHOD=none
```
**Always works, no setup, good quality**

### You're in a team/CI environment
```env
RELEASE_NOTES_METHOD=auto
OPENROUTER_KEY_PRIVATE=or-v1-xxxxxxxxxx  # optional
```
**Works with or without API keys**

---

## 🔄 How It Actually Works During Publish

When you run `./scripts/build.sh publish`, here's what happens:

### With `RELEASE_NOTES_METHOD=claude`:
```
1. ✅ Build plugins
2. ✅ Sign and notarize
3. 📝 Show commits to Claude Code
4. 🤖 Claude Code generates notes (or falls back to Python)
5. ✅ Create GitHub release
6. ✅ Publish!
```

### With `RELEASE_NOTES_METHOD=openrouter`:
```
1. ✅ Build plugins
2. ✅ Sign and notarize
3. 🤖 Call OpenRouter API → Get AI notes
4. ✅ Create GitHub release
5. ✅ Publish!
```

### With `RELEASE_NOTES_METHOD=none`:
```
1. ✅ Build plugins
2. ✅ Sign and notarize
3. 📝 Categorize commits with Python
4. ✅ Create GitHub release
5. ✅ Publish!
```

---

## 📊 Quality Comparison

### Claude Mode Output:
```markdown
## Version 0.5

### ✨ New Features
- Added automatic GitHub Pages landing page for easy plugin downloads
- Multi-plugin build support automatically detects all plugins in project

### 🔧 Improvements
- Enhanced build system documentation with better examples
- Streamlined diagnostic setup workflow

### 🐛 Bug Fixes
- Fixed build output to only show plugins from current session
```

### OpenRouter/OpenAI Output:
```markdown
## Version 0.5

### ✨ New Features
- GitHub Pages landing page generation with smart caching
- Multi-plugin support and AI prompts library integration
- DiagnosticKit optional integration

### 🔧 Improvements
- Enhanced build system documentation
- Improved project initialization UX
```

### Python (none) Output:
```markdown
## Version 0.5

### ✨ New Features
- Add GitHub Pages landing page generation with smart caching
- Add multi-plugin support and AI prompts library to build system
- Add DiagnosticKit opt-in to project initialization

### 🐛 Bug Fixes
- Fix build output to show only plugins built in current session
- Fix DiagnosticKit prompt option 3 to actually disable in .env

### 🔧 Improvements
- Enhance build system documentation in CLAUDE.md
- Improve init_plugin_project.sh UX based on user feedback
```

---

## 🚨 Important Notes

### All methods have improved fallbacks
Even if Claude mode or AI fails, the script will:
1. Try the next method
2. Fall back to Python categorization
3. Finally fall back to git log
4. **Never publish with "Initial release" generic notes anymore!**

### The fixes applied
- ✅ Fixed edge cases (repos with < 10 commits)
- ✅ Removed silent error suppression
- ✅ Added debug visibility
- ✅ Better error messages
- ✅ Improved commit categorization
- ✅ Smart fallback chain

### Migration from old system
If you had API keys before:
```env
# Old way (still works):
OPENROUTER_KEY_PRIVATE=or-v1-xxx
# Script uses "auto" method by default

# New way (explicit):
RELEASE_NOTES_METHOD=openrouter
OPENROUTER_KEY_PRIVATE=or-v1-xxx
```

---

## 🔗 Learn More

- See `scripts/about/release_notes_usage.md` for detailed usage guide
- See `scripts/about/release_notes_improvements.md` for what was fixed
- See `.env.example` for all configuration options
- See `CLAUDE.md` for Claude Code integration details
