# Security Policy

The PacketFence team takes the security of PacketFence and its users seriously. This document explains how to report a vulnerability privately and what you can expect from us after you report.

## Reporting a Vulnerability

**Do not report security vulnerabilities through public GitHub issues, pull requests, discussions, or mailing lists.**

Report privately through either channel:

1. **GitHub private vulnerability reporting (preferred):** open the repository's **Security** tab and click **Report a vulnerability**, or go to <https://github.com/inverse-inc/packetfence/security/advisories/new>.
2. **Email:** [security@akamai.com](mailto:security@akamai.com). Put "PacketFence" in the subject line.

Please include as much of the following as you can:

- The affected component (for example the admin GUI, captive portal, RADIUS/802.1X, API, a specific service or package) and version(s)
- The type of issue (for example RCE, SQL injection, XSS, authentication bypass, privilege escalation, information disclosure)
- Step-by-step instructions to reproduce, including any non-default configuration
- A proof of concept or exploit code, if available
- The impact as you understand it, and how an attacker could exploit it
- Whether the issue is already public or known to others
- How you would like to be credited, if at all

## What to Expect

| Stage | Target |
| --- | --- |
| Acknowledgement of your report | Within 3 business days |
| Initial assessment (validity and severity) | Within 10 business days |
| Status updates | At least every 14 days until resolution |
| Fix released: Critical | Within 30 days of confirmation |
| Fix released: High | Within 60 days of confirmation |
| Fix released: Medium / Low | In the next release |

Security fixes are provided for the latest release line (its `maintenance/X.Y` branch) and for `devel`. Older release lines are not supported; upgrade to the latest release to receive fixes.

Severity is assessed using CVSS (v3.1 or later) together with how PacketFence is typically deployed. If we decline a report, we will tell you why.

No bug bounty is offered.

## Coordinated Disclosure

We follow coordinated disclosure:

- Please give us a reasonable chance to release a fix before disclosing publicly. We ask for **up to 90 days** from your report, and we will agree on a disclosure date with you. If a Medium or Low fix will ship after that window, we will ask you to agree an extension.
- When a fix is released, we publish a **GitHub Security Advisory** for this repository, request a **CVE** where appropriate, and note the fix in [NEWS.asciidoc](NEWS.asciidoc).
- Reporters are credited in the advisory unless they ask not to be.

## Scope

**In scope:**

- Source code in this repository
- PacketFence release packages (RPM and DEB) and container images built from this repository

**Out of scope:**

- Vulnerabilities in third-party dependencies that do not affect PacketFence. Report those to the upstream project. If a dependency vulnerability is exploitable through PacketFence, it is in scope, so please tell us.
- Issues that require an attacker to already hold full administrative access, unless they cross a privilege boundary (for example from a restricted admin role to a full admin, or to OS-level code execution)
- Insecure configurations explicitly warned against in the PacketFence documentation
- Volumetric denial-of-service, social engineering, and physical attacks
- Reports from automated scanners with no demonstrated impact

## Safe Harbor

We will not pursue or support legal action against anyone who researches and reports vulnerabilities in good faith under this policy. Good faith means that you:

- Test only against systems you own or are authorized to test
- Avoid privacy violations, data destruction, and service disruption
- Do not access, change, or keep data that does not belong to you beyond what you need to demonstrate the issue
- Report the issue privately and give us reasonable time to fix it before disclosure

## Security Updates

To be notified of security fixes, **Watch** this repository and select **Releases** under *Custom*, follow the [NEWS file](NEWS.asciidoc), and check this repository's [published security advisories](https://github.com/inverse-inc/packetfence/security/advisories).
