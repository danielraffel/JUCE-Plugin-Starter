# Auto-Update Implementation Learnings

## PlunderTube Reference Notes
- PlunderTube downloads Sparkle 2.8.0 as xcframework (tar.xz), renames to `Sparkle/`
- The actual framework path inside is `Sparkle/macos-arm64_x86_64/Sparkle.framework`
- PlunderTube uses a two-repo model we are NOT reproducing
- PlunderTube injects PAT via configure_file() — we skip this for public mode

## A1.1 — setup_sparkle.sh
- Sparkle 2.8.0 tar.xz extracts FLAT into the target directory — NOT as xcframework
- Actual structure: external/Sparkle.framework, external/bin/ (tools), external/Symbols/
- PlunderTube's script expected Sparkle.xcframework — that was wrong for 2.8.0
- Tools (sign_update, generate_keys) are in external/bin/, NOT inside the framework
