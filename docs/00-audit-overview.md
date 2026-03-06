# Cross-Platform Audit Overview

This document tracks the feature gap analysis between JUCE-Plugin-Starter (+ juce-dev plugin + Visage fork) and the reference cross-platform JUCE template. It guides prioritized work across repos.

## Documents in This Audit

| Doc | Purpose |
|-----|---------|
| [00-audit-overview.md](00-audit-overview.md) | This file - index and status tracker |
| [01-feature-comparison.md](01-feature-comparison.md) | Side-by-side feature matrix |
| [02-visage-platform-support.md](02-visage-platform-support.md) | Visage GPU backend support per platform |
| [03-priority-roadmap.md](03-priority-roadmap.md) | Stack-ranked feature additions with phases |
| [04-branch-strategy.md](04-branch-strategy.md) | Feature branch naming across all repos |

## Repos Involved

| Repo | Path | Purpose |
|------|------|---------|
| JUCE-Plugin-Starter | `/Users/danielraffel/Code/JUCE-Plugin-Starter` | Template for new plugin projects |
| juce-dev plugin | `/Users/danielraffel/Code/generous-corp-marketplace/plugins/juce-dev` | Claude Code plugin for JUCE dev |
| Visage fork | `/Users/danielraffel/Code/visage` | GPU-accelerated UI framework |

## Current Status

- [x] Audit: Reference template (pamplejuce)
- [x] Audit: JUCE-Plugin-Starter
- [x] Audit: juce-dev Claude Code plugin
- [x] Audit: Visage platform support
- [x] Feature comparison matrix
- [x] Visage platform analysis
- [x] Priority roadmap
- [x] Branch strategy
- [ ] Phase 1: macOS/iOS enhancements
- [ ] Phase 2: Windows support
- [ ] Phase 3: Linux support
- [ ] Phase 4: Android investigation (research only)
