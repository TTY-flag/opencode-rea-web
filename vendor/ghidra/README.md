# Bundled Ghidra 12.1.4

This directory contains the complete, unmodified official release archive,
split into 48 MiB parts so a normal Git clone can fetch it from GitHub.
The Dockerfile reassembles the parts, verifies every part and the complete
archive, and extracts Ghidra automatically. Git LFS is not required.

Original release:
https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build

Original archive: `ghidra_12.1.4_PUBLIC_20260921.zip`

Complete SHA-256:
`ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`

`manifest.json` records the source URL, exact sizes and ordered parts.
`SHA256SUMS` records the individual part hashes. The archive retains its
original upstream license files and third-party notices. Ghidra's licenses
are separate from this repository's MIT license.
