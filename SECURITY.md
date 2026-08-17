# Security policy

RaidThreeBags does not require network access or credentials. Never attach account data, SavedVariables, character names or server-identifying screenshots to a public report without redaction.

Version `0.4.2` and later store a bounded Sort Trace in the account-wide `RaidThreeBagsDB` SavedVariables table. The latest ten sessions can contain character and realm names, timestamps, item IDs and names, item counts, bag and slot coordinates, first-observed ages, compatible movement-pool assignments, arrangement plans and confirmed move or merge results. The trace is not transmitted and does not contain chat, character location or credentials, but it is still private gameplay metadata. Turning logging off does not erase retained sessions and also disables the independent final audit for future arrangements; use `/rtb sortlog clear` to remove retained sessions. Review and redact SavedVariables before sharing.

Reports involving item-count changes, cross-family movement, an incorrect physical move, unintended bag replacement, protected-action errors or another addon's UI being broken should include exact reproduction steps, the reported Sort Trace result and a redacted Lua stack trace. Do not publish unredacted SavedVariables. Use a private GitHub security advisory for a vulnerability.
