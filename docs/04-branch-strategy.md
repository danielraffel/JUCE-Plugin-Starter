# Branch Strategy: Cross-Platform Work

## Branch Naming Convention

All repos use the same branch name prefix for coordinated work:

```
feature/cross-platform-{phase}-{feature}
```

## Current Branches

| Repo | Branch | Purpose |
|------|--------|---------|
| JUCE-Plugin-Starter | `feature/cross-platform-audit` | This audit and planning work |

## Planned Branches (Phase 1: macOS/iOS)

| Repo | Branch | Work |
|------|--------|------|
| JUCE-Plugin-Starter | `feature/cross-platform-1-clap` | CLAP format support |
| JUCE-Plugin-Starter | `feature/cross-platform-1-auv3` | AUv3 format support |
| JUCE-Plugin-Starter | `feature/cross-platform-1-catch2` | Unit testing framework |
| JUCE-Plugin-Starter | `feature/cross-platform-1-clang-format` | .clang-format |
| juce-dev | `feature/cross-platform-1-clap` | Update build command for CLAP |
| juce-dev | `feature/cross-platform-1-auv3` | Update setup-ios for AUv3 |
| juce-dev | `feature/cross-platform-1-catch2` | Update build command for tests |

## Planned Branches (Phase 2: Windows)

| Repo | Branch | Work |
|------|--------|------|
| JUCE-Plugin-Starter | `feature/cross-platform-2-windows` | Windows build system, signing, installer |
| juce-dev | `feature/cross-platform-2-windows` | Windows-aware commands |
| Visage | `feature/cross-platform-2-juce-bridge-win` | Windows JUCE-Visage bridge |
| JUCE-Plugin-Starter | `feature/cross-platform-2-ci` | GitHub Actions CI/CD |
| juce-dev | `feature/cross-platform-2-ci` | CI setup in /juce-dev:create |

## Planned Branches (Phase 4: Linux)

| Repo | Branch | Work |
|------|--------|------|
| JUCE-Plugin-Starter | `feature/cross-platform-4-linux` | Linux build system |
| Visage | `feature/cross-platform-4-juce-bridge-linux` | Linux JUCE-Visage bridge |
| juce-dev | `feature/cross-platform-4-linux` | Linux-aware commands |

## Merge Strategy

1. Work on feature branches, never on main
2. Each feature branch should be independently mergeable
3. Phase 1 branches merge first, then Phase 2, etc.
4. Cross-repo branches with same name indicate coordinated changes
5. All docs committed locally, not pushed until ready

## Windows Dev Environment

A Windows VM is available via UTM:
- SSH access: `ssh win` (configured in ~/.ssh/config)
- Purpose: Testing Windows builds and Visage bridge
- Status: Running, needs development tools configured
- Phase 2 work will use this VM for testing
