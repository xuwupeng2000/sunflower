# 1.5 release preparation — 2026-11-10

- Version 1.5, build 1; app and widget share the same version.
- Updated flower screenshots: actual app rendering of the sunflower with the hedgehog cottage planter, in ten locales.
- Raw captures: `<locale>/01-flower.png`, 1320×2868. Upload files: `upload/<locale>/06-flower.png`, 1206×2622 RGB.
- The other five screenshots per locale are preserved from the existing 1.3 materials.
- SHA-256 and dimensions are recorded in manifest.json.
- Screenshot generation uses an isolated example save; the real alarm save is not changed.
- Xcode archive and App Store Connect upload succeeded on 2026-11-10. TestFlight confirms version 1.5 (1), received at 22:10 Asia/Shanghai, processing completed and selected for version 1.5.
- App Store Connect version 1.5 draft created. Replaced the sixth flower screenshot in all ten locales with the localized sunflower + hedgehog cottage image; English preview visually verified.
- Saved localized 1.5 release notes and refreshed review notes. Validation has no missing text fields.
- Release remains automatic after approval, retaining existing ratings.
- Not yet submitted for review: the build is selected and text validation passed. As of 22:21 Asia/Shanghai, Apple blocks submission with “1 张或多张截屏必须完成处理。” Several locale screenshots remain processing. English, Traditional Chinese and Spanish previews are available.
- Upload completed with a non-blocking warning: SunflowerShared.framework is missing its dSYM.

- Added the four other flower screenshots (07–10) in all ten locales. Each locale now shows 10/10 screenshots in App Store Connect. New screenshots are awaiting Apple processing.
