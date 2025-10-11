# AI Prompt Library for JUCE Plugin Development

This directory contains ready-to-use prompts for implementing common plugin features with AI coding assistants.

## 🎯 Purpose

These prompts help you:
- **Save time** - Skip explaining common features from scratch
- **Stay consistent** - Use tested patterns that work well with JUCE
- **Learn faster** - See how features are implemented in real code
- **Build faster** - Get AI assistants up to speed quickly

## 📋 Available Prompts

### Audio & MIDI Settings
**File**: `audio-midi-settings-prompt.md`
**Adds**: Comprehensive audio device selection, MIDI routing, and I/O configuration

**Use when you need**:
- Audio device selection UI
- MIDI input/output routing
- Sample rate and buffer size settings
- Audio channel configuration

### LFO & Modulation System
**File**: `lfo-modulation-prompt.md`
**Adds**: Flexible LFO with multiple waveforms and modulation routing

**Use when you need**:
- Low-frequency oscillators (sine, triangle, square, saw)
- Modulation routing matrix
- Tempo sync and free-running modes
- Parameter modulation system

## 🚀 How to Use These Prompts

### With Claude Code (CLI)

1. Open your project in Claude Code
2. Reference the prompt file directly:
   ```bash
   @prompts/audio-midi-settings-prompt.md
   ```
3. Ask Claude to implement the feature:
   ```
   Please implement the audio/MIDI settings feature described in this prompt
   ```

### With Cursor

1. Open the prompt file in Cursor
2. Select all content (Cmd+A)
3. Open Cursor chat (Cmd+L)
4. Paste the prompt and add:
   ```
   Implement this feature in my JUCE plugin
   ```

### With ChatGPT / Claude Web

1. Copy the entire prompt file contents
2. Start a new conversation
3. Paste the prompt and provide context about your plugin
4. Review and test the generated code

### With GitHub Copilot Chat

1. Open the prompt file
2. Use inline chat (Cmd+I)
3. Reference the prompt:
   ```
   @workspace Implement the feature in audio-midi-settings-prompt.md
   ```

## ✅ Best Practices

### Before Using a Prompt

1. **Read the entire prompt** - Understand what will be added
2. **Check dependencies** - Some features may require specific JUCE modules
3. **Review your architecture** - Make sure the feature fits your plugin design
4. **Back up your code** - Always commit changes before adding major features

### While Using a Prompt

1. **Provide context** - Tell the AI about your existing code structure
2. **Ask questions** - If the AI suggests something unclear, ask for explanation
3. **Iterate gradually** - Implement features step-by-step, not all at once
4. **Test frequently** - Build and test after each major change

### After Using a Prompt

1. **Review all code** - Don't blindly accept AI-generated code
2. **Test thoroughly** - Verify the feature works as expected
3. **Refactor if needed** - Adapt the code to match your style
4. **Document changes** - Add comments explaining the new feature

## 📝 Prompt Template Structure

Each prompt in this library follows a consistent structure:

```markdown
# Feature Name

## Overview
Brief description of what this feature does

## Context
Information about the plugin structure and requirements

## Implementation Requirements
Specific technical requirements and JUCE modules needed

## Code Structure
How the feature should be organized

## Implementation Steps
Step-by-step instructions for the AI

## Testing
How to verify the feature works correctly

## Integration Notes
How this feature integrates with existing code
```

## 🤝 Contributing New Prompts

Have a prompt that works well? Consider adding it!

### Good Prompts Are:
- **Self-contained** - Include all necessary context
- **Clear** - Specific about requirements and expectations
- **Tested** - Verified to work with at least one AI assistant
- **Documented** - Explain what the feature does and why
- **Modular** - Can be integrated without breaking existing code

### Prompt Naming Convention:
```
feature-name-prompt.md
```

Examples:
- `preset-manager-prompt.md`
- `spectrum-analyzer-prompt.md`
- `undo-redo-prompt.md`

## 🔧 Customizing Prompts

Feel free to modify these prompts for your specific needs:

1. **Add project context** - Include your plugin's unique requirements
2. **Adjust complexity** - Simplify or expand based on your needs
3. **Change implementation** - Specify different design patterns
4. **Add constraints** - Include coding standards or style requirements

## 📚 Additional Resources

- [JUCE Documentation](https://docs.juce.com/)
- [JUCE Forum](https://forum.juce.com/)
- [AI Pair Programming Best Practices](https://github.blog/developer-skills/github/how-to-use-github-copilot-your-ai-pair-programmer/)

## ⚠️ Important Notes

- **Review all generated code** - AI assistants can make mistakes
- **Test thoroughly** - Don't assume generated code is bug-free
- **Understand the code** - Make sure you know what was added and why
- **Maintain consistency** - Adapt AI suggestions to match your codebase style
- **Security first** - Review any code that handles user data or file I/O

---

**Remember**: These prompts are starting points, not finished features. Always review, test, and adapt the code to your specific needs.
