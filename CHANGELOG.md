# Changelog

## 0.4.0 - 2026-07-27

- Prepared a clean public-repository package.
- Replaced server-specific edition text with neutral WotLK 3.3.5a branding.
- Standardized maintainer metadata.
- Added `/rtb version` and English command help.
- Added release validation and an inventory/bank runtime test matrix.
- Included the MIT license in the installable addon directory, declared
  `X-License: MIT` in the manifest and validated both license copies.
- Updated the GitHub validation workflow to `actions/checkout@v7` after GitHub
  deprecated the Node.js 20 runtime used by the earlier workflow dependency.

Promoted to the stable local release source after the exact `0.4.0-dev`
candidate files matched the installed test copy by SHA-256 and the user
reported all expected in-client behavior working.
