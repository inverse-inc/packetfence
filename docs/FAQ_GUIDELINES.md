# PacketFence FAQ Guidelines

## FAQ Entry Standards

**Consistent Structure**: Use standardized Problem/Symptoms/Solution format with inline bold text for visual distinction
**Step-by-Step Solutions**: Break complex solutions into numbered steps using bold text format (*Step 1: Action Name*)
**Version Information**: Always include "Affected Versions" section specifying which PacketFence versions are impacted
**Community References**: Include specific thread URLs rather than generic monthly digest links
**Code Examples**: Provide practical, testable code snippets with explanatory comments
**Troubleshooting Flow**: Organize solutions in logical troubleshooting sequence from most common to advanced fixes

## Layout and Readability Standards

**Visual Hierarchy**: Use AsciiDoc formatting elements (.lead, NOTE blocks, code blocks) to improve document flow
**Section Separation**: Use horizontal rules (''') to clearly separate FAQ entries
**Bullet Point Consistency**: Use consistent bullet formatting for symptoms and solution steps
**Code Block Standards**: Always include descriptive comments in code examples
**Length Guidelines**: Keep individual FAQ entries focused - split overly complex topics into multiple entries
**Whitespace Usage**: Use appropriate spacing between sections for visual clarity

## Content Quality Guardrails

**Solution Completeness**: Every FAQ entry must provide actionable, step-by-step solutions
**Error Message Inclusion**: Include specific error messages and log entries when relevant
**Testing Requirements**: All code examples must be tested or validated before inclusion
**Authority Validation**: Only include solutions confirmed by @inverse.ca or @akamai.com users, or validated through community consensus
**Version Specificity**: Clearly identify which PacketFence versions are affected by each issue
**Practical Focus**: Prioritize real-world deployment scenarios over theoretical edge cases

## FAQ Formatting Template

```asciidoc
[[unique-section-id]]
==== Brief descriptive title

*Problem:* Brief description of the issue

*Symptoms:*

* Bullet point symptom 1
* Bullet point symptom 2
* Specific error messages or behaviors

*Solution:*

*Step 1: Action Name*

Description of the step:

----
# Code example with comments
command-to-run --option value
----

*Step 2: Next Action*

Continue with numbered steps using bold text format.

*Affected Versions:* PacketFence version information

*Community Reference:*
https://sourceforge.net/p/packetfence/mailman/packetfence-users/thread/THREAD_ID/[Description of thread]

'''
```

## Pre-Publication Checklist

**Compilation Test**: Always run `make clean && make html` before committing changes
**Link Verification**: Test all external links and ensure thread URLs are accessible
**Format Validation**: Verify consistent Problem/Symptoms/Solution structure across entries
**Code Testing**: Validate all command examples and configuration snippets
**Privacy Review**: Confirm no real names or sensitive information is included

## Content Review Process

**Authority Verification**: Confirm solutions are backed by @inverse.ca or @akamai.com users
**Version Accuracy**: Verify affected versions are correctly specified and current
**Solution Completeness**: Ensure each FAQ provides complete, actionable troubleshooting steps
**Cross-Reference Check**: Verify all internal document links and section references work
**Thread Validation**: Confirm community reference links point to specific threads, not digest pages

## Critical Formatting Errors to Avoid

**Table of Contents Disruption**: Never use section headers (==, ===) within FAQ entries - use bold text instead
**Inconsistent Visual Hierarchy**: Maintain uniform Problem/Symptoms/Solution formatting across all entries
**Code Block Inconsistency**: Always use proper AsciiDoc code block delimiters (----) with descriptive comments
**Missing Horizontal Rules**: Use ''' between FAQ entries for clear visual separation

## Thread Research Methodology

**Paginated Access**: Use `https://sourceforge.net/p/packetfence/mailman/packetfence-users/?style=threaded&limit=10000&page=N` for comprehensive thread access
**Multiple Thread Coverage**: For complex issues affecting many users, include multiple thread references when available
**Cross-Validation**: Verify solutions work across different PacketFence versions and deployment scenarios
**Gap Analysis**: Identify frequently discussed topics that lack comprehensive FAQ coverage

## Thread Selection Criteria

**Minimum Replies**: Only use threads with at least 1 reply (not standalone posts)
**Authoritative Sources**: Trust answers from users with @akamai.com or @inverse.ca email addresses
**Community Validation**: For other users' answers, require follow-up agreement or positive feedback in the thread
**Solution Quality**: Ensure selected threads contain working solutions, not just problem reports
**Multiple References**: For complex issues, include multiple thread references when available to provide comprehensive coverage
**Cross-Validation**: Verify solutions work across different PacketFence versions and deployment scenarios
**Gap Analysis**: Identify frequently discussed topics that lack comprehensive FAQ coverage

## Privacy Standards

**No Real Names**: Never include real individual names in documentation, FAQ entries, or CLAUDE.md
**Anonymous Attribution**: Refer to authoritative sources by domain only (e.g., "@inverse.ca developer" instead of specific names)

## Mailing List Thread Management

### FAQ Thread Source Tracking
**Thread Inventory**: Maintain a record of which mailing list archive months have been scanned for FAQ thread sources
**Archive Format**: Mailing list archives use `viewmonth=YYYYMM` format (e.g., viewmonth=202412 for December 2024)
**Search Methodology**: Use the paginated mailing list archives at `https://sourceforge.net/p/packetfence/mailman/packetfence-users/?style=threaded&limit=10000&page=1` for comprehensive thread access - do not use external web search

### Thread URL Format
**Complete URLs**: Always use full thread URLs when updating FAQ references
**URL Structure**: Thread URLs follow pattern `https://sourceforge.net/p/packetfence/mailman/packetfence-users/thread/THREAD_ID/`
**Link Text**: Preserve existing link text format `[PacketFence Users Mailing List]`

### Archive Scanning Process
1. **Start with Recent Months**: Begin scanning from most recent months working backwards
2. **Record Progress**: Document which `viewmonth=YYYYMM` periods have been scanned
3. **Topic Matching**: Match thread subjects/content to specific FAQ entries
4. **Quality Validation**: Verify thread meets reply and authority criteria
5. **URL Collection**: Collect full thread URLs for each qualified FAQ topic

### FAQ Thread Mapping Requirements
**Version Specification**: Always include affected PacketFence versions in FAQ entries
**Sorting Order**: Organize FAQ items with version-agnostic issues first, then version-specific issues in descending version order (v14.x, v13.x, v12.x, etc.)
**Version Format**: Use consistent X.Y format for versions (e.g., v14.0, v13.2)

## FAQ Enhancement History

### Comprehensive FAQ Expansion (2025-09-18)
Completed major enhancement of PacketFence FAQ based on extensive mailing list research spanning 2020-2025, adding 12 new comprehensive entries covering the most frequently reported community issues.

### New FAQ Entries Added - Round 1 (Core Issues)
Based on extensive mailing list research and community-reported issues, the following new FAQ entries have been added:

#### RADIUS & Authentication Section
1. **MAC Authentication Bypass not working on Cisco switches**
   - Addresses device authentication failures with MAB configuration
   - Covers switch port configuration, RADIUS connectivity, and hardware compatibility
   - Thread source: Cisco switch authentication troubleshooting discussion

2. **Captive portal email authentication shows 502 Bad Gateway error**
   - Solves inline enforcement issues with email authentication
   - Covers IPSET sessions, firewall configuration, and VLAN enforcement alternatives
   - Thread source: Email authentication error troubleshooting

3. **802.1X authentication fails for new Active Directory accounts**
   - Addresses pre-login authentication challenges for new AD users
   - Covers computer authentication, domain connectivity, and PacketFence AD configuration
   - Thread source: 802.1x AD first connexion discussion

#### Version-Specific Issues Section
4. **PacketFence v11.0 VLAN assignment not working after migration**
   - Covers migration issues from v10.3 CentOS to v11.0 Debian
   - Addresses API authorization changes, switch compatibility, and platform differences
   - Thread source: v11.0 vlan issue discussion

#### Performance & Scalability Section
5. **No cluster-wide service restart mechanism available**
   - Documents current limitation in cluster service management
   - Provides workarounds for manual service restart and certificate synchronization
   - Thread source: Cluster service restart discussion

#### Network Device Integration Section
6. **UniFi controller HTTPS redirection to captive portal fails**
   - Addresses SSL certificate errors and multiple browser tab issues after controller migration
   - Covers controller configuration, network connectivity, and certificate validation
   - Thread source: Ubiquity Controller HTTPS redirection to PacketFence

### New FAQ Entries Added - Round 2 (Current Issues 2024-2025)
Continued expansion with recent community-reported issues from 2024-2025:

#### RADIUS & Authentication Section
7. **Authentication succeeds but VLAN assignment returns "undefined"** (September 2024)
   - Comprehensive RADIUS attribute debugging and role configuration troubleshooting
8. **Cannot login to admin interface after server restart** (August 2024)
   - Service verification, password reset, and database connectivity procedures
9. **PacketFence installation fails on RHEL 9 with repository 404 error** (August 2024)
   - Official confirmation RHEL 9 not supported, with platform alternatives

#### Performance & Scalability Section
10. **Fingerbank collector service constantly restarting with high CPU usage** (June 2024)
    - TCP handler disable solution and service optimization
11. **High CPU usage in large K-12 deployment with 14,000+ devices** (June 2024)
    - Cluster architecture recommendations and load balancing for educational environments

#### Advanced Troubleshooting Section
12. **Security event configuration not triggering despite proper setup** (July 2024)
    - Comprehensive debugging procedures for security event automation

### Major Accomplishments
- **Formatting Standardization**: Implemented consistent Problem/Symptoms/Solution structure across all FAQ entries
- **Documentation Quality**: Enhanced code examples with explanatory comments and proper context
- **Compilation Validation**: All changes tested with `make clean && make html` to ensure AsciiDoc compatibility
- **Research Methodology**: Established systematic approach to mailing list thread research and validation
- **Privacy Compliance**: Maintained anonymous attribution standards throughout all FAQ content
- **Comprehensive Coverage**: Successfully documented solutions for the most frequently reported community issues

## Future FAQ Changes

**Documentation Protocol**: All future FAQ modifications, additions, and enhancements must be documented in this section with date, description, and rationale.

### Change Documentation Template
```
### [Date] - [Change Type]
**Description**: Brief summary of changes made
**Entries Affected**: List of FAQ entries added, modified, or removed
**Rationale**: Why the change was necessary
**Thread Sources**: Community discussion references that prompted the change
**Validation**: How the change was tested/verified
```