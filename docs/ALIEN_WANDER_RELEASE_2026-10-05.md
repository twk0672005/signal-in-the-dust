# Alien Wander publication

Nova's current 2026-10-05 instruction, "PASH PUT MAIN", authorizes committing the
verified free-exploration source, updating local source main, pushing the source
branch and publishing the corresponding Web bundle to the existing GitHub main.
The working name remains a proposal. This is the current publication authority.

Accepted local release: 565b87cc7346650fc245d405.
Source base: 87f4de73d39af23bcc5a4cfb50e6d045f6f093ec.
Source and website Git histories are separate.
Public repository: twk0672005/signal-in-the-dust.

Use the frozen accepted PCK/WASM and shell bytes. Only split-package transport
configuration changes for Pages; verify reconstructed PCK and decoded WASM.
Retain old immutable releases, root aliases, save namespace and unrelated WIP.
Source commit excludes preexisting imports, historical evidence and art WIP.

## Published And Verified

- Play: https://twk0672005.github.io/signal-in-the-dust/?v=0f0d23d21cd310d632cf7000
- Website main: edd72bac585af55c964334a87336a36115e93169.
- Game source: 0bf2332ca1ddfce3cb813493e5af5b830b24390b.
- Published transport release: 0f0d23d21cd310d632cf7000.
- Accepted game release: 565b87cc7346650fc245d405.

Pages built the exact website commit. All 26 published files and both metadata
files match; PCK reconstruction preserves the accepted game bytes. All 143 prior
website dependencies were retained. Unrelated tracked WIP was read back unchanged.

The public desktop journey passed 26 checks, including all four habitats and the
world tree without E, optional observation, continued driving, title and Continue.
Landscape touch emulation passed 20 checks, including backup recovery. No browser
errors were recorded. Observed public launch-to-control samples were 18.52 seconds
desktop and 19.24 seconds touch. These used fresh Chromium contexts and recording;
OS/GPU/CDN caches were uncontrolled. They are not universal cold-load guarantees.

The initial push returned HTTP 408 without changing the remote main. A normal
retry with per-command HTTP/1.1 and a larger post buffer succeeded; no persistent
Git configuration was changed.

Physical phone and Safari remain unverified. The brand is still a working name.
Full receipt: [FINAL_RECEIPT](../evidence/alien-wander-publish-20261005/FINAL_RECEIPT.json).
