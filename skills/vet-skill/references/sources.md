# Scanners studied for /vet-skill

Research date: 2026-11-18. Every licence below was read from the repo's own LICENSE file through the GitHub API on that date. Search results and star counts are context only.

No outside scanner is a runtime dependency of /vet-skill, and nothing is vendored. We read each README, recreate the useful ideas in `checks.md` with the upstream URL cited, and copy no code. Anything that sends content off the machine is marked opt-in and is never run by default.

| Name | Repo URL | Licence (verified 2026-11-18) | Form | Sends data off-machine? | Disposition | Ideas taken |
|---|---|---|---|---|---|---|
| Snyk Agent Scan | https://github.com/snyk/agent-scan | Apache-2.0 | CLI (`uvx` or standalone binary) | Yes. Its analysis step sends agent app details, MCP server configs and signatures, tool names and descriptions, and skill content to the Snyk analysis API, with a Snyk token. Opt-in only. | Recreate ideas; no code copied; nothing vendored | Discovery of installed skills and MCP servers, consent before running a server, redacting env vars and headers, refusing cloud-metadata and link-local destinations |
| Cisco skill-scanner | https://github.com/cisco-ai-defense/skill-scanner | Apache-2.0 (the API reports NOASSERTION; the LICENSE file is the Apache 2.0 text, copyright Cisco Systems) | CLI and REST server | Optional: its LLM judge and cloud scanning engines send content out. Opt-in only. | Recreate ideas; no code copied; nothing vendored | Pattern rules for prompt injection, exfiltration and malicious code; dataflow checks; published recall and false-positive rates per preset |
| Cisco mcp-scanner | https://github.com/cisco-ai-defense/mcp-scanner | Apache-2.0 | CLI and REST server | Optional: the Cisco AI Defense API, LLM analysis and VirusTotal hash lookups send data out. Opt-in only. | Recreate ideas; no code copied; nothing vendored | Scanning tool descriptions, prompts, resources and server instructions; offline scan of saved JSON; dependency vulnerability audit; source-code behaviour checks |
| decoy-scan | https://github.com/decoy-run/decoy-scan | MIT | CLI (`npx`) | Anonymised telemetry by default (`DECOY_TELEMETRY=0` turns it off), and an opt-in `--report` upload to its dashboard. Treat as opt-in only. | Recreate ideas; no code copied; nothing vendored | Cross-server toxic flows, risky server commands (pipe to shell, typosquats, temp-dir spawns), secrets passed through env vars, over-broad permissions |
| Mondoo skillcheck | https://github.com/mondoohq/skillcheck | Apache-2.0 | CLI (`npx`) | Yes. It checks installed items against Mondoo's AI Agent Security service, so item identity leaves the machine. Opt-in only. | Recreate ideas; no code copied; nothing vendored | One verdict per installed skill, plugin or MCP server; content hashes; a `validate` mode for a skills repo contract |
| CAI (Alias Robotics) | https://github.com/aliasrobotics/cai | Other (the API reports NOASSERTION; not a standard permissive licence, so treated as ideas only). No text quoted here. | Agent framework (archived) | Not assessed | Ideas only; no code, nothing vendored | None recorded yet |
| HexStrike AI | https://github.com/0x4m4/hexstrike-ai | MIT | Offensive-security MCP server, not a scanner | Not assessed; never run | Test-fixture source only: a known-bad MCP server to check that our scanner flags it. Read its text as data; never install or run it. | None |

## Other tools seen in searches (unverified)

These came up in repo searches. Their licences are listed as the API reported them and were not checked against a LICENSE file. Ideas only, nothing vendored.

| Name | Repo URL | Listed licence |
|---|---|---|
| NVIDIA SkillSpector | https://github.com/NVIDIA/SkillSpector | Apache-2.0 |
| agent-security-scanner-mcp | https://github.com/sinewaveai/agent-security-scanner-mcp | MIT |
| Ramparts | https://github.com/highflame-ai/ramparts | Apache-2.0 |
| MCPScan (antgroup) | https://github.com/antgroup/MCPScan | Apache-2.0 |
| prism-scanner-skill | https://github.com/NextFrontierBuilds/prism-scanner-skill | no licence found |
| tranqy/mcpscan | https://github.com/tranqy/mcpscan | no licence found |

Research date: 2026-11-18. Listings were unverified until a row's licence column says otherwise.
