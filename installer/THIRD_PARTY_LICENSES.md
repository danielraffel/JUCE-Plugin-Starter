# Third-Party Software Licenses

This document acknowledges the third-party software tools and libraries used in the JUCE Plugin Starter project. We are grateful to the developers and maintainers of these tools.

**Last Updated:** June 2025

---

## Build Tools & Dependencies

### CMake
- **Purpose:** Cross-platform build system generator
- **License:** BSD 3-Clause License  
- **Copyright:** Kitware, Inc. and Contributors  
- **Website:** https://cmake.org/  
- **License Text:** https://cmake.org/licensing/

### GitHub CLI (gh)
- **Purpose:** Command-line interface for GitHub operations  
- **License:** MIT License  
- **Copyright:** GitHub, Inc.  
- **Website:** https://cli.github.com/  
- **License Text:** https://github.com/cli/cli/blob/trunk/LICENSE

### Homebrew
- **Purpose:** Package manager for macOS  
- **License:** BSD 2-Clause License  
Copyright: Homebrew maintainers  
- **Website:** https://brew.sh/  
- **License Text:** https://github.com/Homebrew/brew/blob/master/LICENSE.txt

### JUCE Framework
- **Purpose:** Cross-platform C++ application framework for audio applications  
- **License:** Dual License (GPL v3 / Commercial)  
- **Copyright:** Raw Material Software Limited  
- **Website:** https://juce.com/  
- **License Text:** https://github.com/juce-framework/JUCE/blob/master/LICENSE.md  
- **Note:** Users must comply with JUCE licensing terms for their specific use case

### Python 3
- **Purpose:** Programming language for build automation scripts  
- **License:** Python Software Foundation License  
- **Copyright:** Python Software Foundation  
- **Website:** https://www.python.org/  
- **License Text:** https://docs.python.org/3/license.html

### rsync
- **Purpose:** File synchronization and transfer utility  
- **License:** GPL v3  
- **Copyright:** Andrew Tridgell, Paul Mackerras, and others  
- **Website:** https://rsync.samba.org/  
- **License Text:** https://github.com/WayneD/rsync/blob/master/COPYING

### UV (Python Package Manager)
- **Purpose:** Fast Python package installer and resolver  
- **License:** Apache License 2.0 / MIT License  
- **Copyright:** Astral Software Inc.  
- **Website:** https://github.com/astral-sh/uv  
- **License Text:** https://github.com/astral-sh/uv/blob/main/LICENSE-APACHE

---

## Development Tools

### Xcode
- **Purpose:** Integrated development environment for macOS  
- **License:** Proprietary (Apple Inc.)  
- **Copyright:** Apple Inc.  
- **Website:** https://developer.apple.com/xcode/  
- **Note:** Subject to Apple Developer Agreement

---

## System Utilities

### Bash
- **Purpose:** Unix shell and command language  
- **License:** GPL v3  
- **Copyright:** Free Software Foundation  
- **Website:** https://www.gnu.org/software/bash/  
- **License Text:** https://www.gnu.org/licenses/gpl-3.0.html

### Git
- **Purpose:** Distributed version control system  
- **License:** GPL v2  
- **Copyright:** Linus Torvalds and others  
- **Website:** https://git-scm.com/  
- **License Text:** https://github.com/git/git/blob/master/COPYING

---

## License Compliance Notes

1. **GPL Licensed Tools:** Tools licensed under GPL (Git, Bash, rsync) are used as external utilities and are not linked or bundled with the distributed software. Their usage complies with GPL terms.

2. **JUCE Framework:** Users are responsible for selecting the appropriate JUCE license (GPL or Commercial) based on their usage. Commercial deployment may require a paid license.

3. **Apple Tools:** Xcode and related tools are subject to the Apple Developer Agreement and may impose restrictions on redistribution and deployment.

4. **Build-Time Dependencies:** All third-party tools listed are used strictly during development or the build process and are not included in distributed binaries.

---

## Disclaimer

This project aims to comply with all applicable licenses. If you believe there is a licensing issue or omission, please open an issue in the project repository.

For questions about licensing or to report issues, please contact the project maintainers through the GitHub repository.
