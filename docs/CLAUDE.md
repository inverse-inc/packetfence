# PacketFence Documentation Guidelines for AI Assistants

This file contains guidelines for AI assistants working with PacketFence documentation to ensure consistency, accuracy, and maintainability.

## **Documentation Standards & Guidelines**

### Formatting Rules
- **Line Length**: Maximum 80 characters per line for better readability
- **Line Endings**: Maintain CRLF line endings where established
- **Section Prefixing**: Prefix section titles with [filename] for context
- **AsciiDoc Syntax**: Use proper AsciiDoc formatting for headers, lists, code blocks, and cross-references
- **Image Lines**: Keep image declarations on single lines without line breaks (e.g., `image::radius-workflow.png["WiFi RADIUS workflow",width="75%",scaledwidth="100%"]`)
- **Admonition Line Endings**: Never use CRLF line endings within NOTE, WARNING, TIP, IMPORTANT, or CAUTION admonition blocks between delimiter markers. Use LF line endings for proper AsciiDoc rendering. The delimiter markers themselves (====, ===, etc.) are acceptable for structuring content within admonitions.

### Content Organization
- **Heading Hierarchy**: Use consistent heading levels (=, ==, ===, ====)
- **Logical Grouping**: Keep related content together
- **Standardized Includes**: Follow existing include file structure and patterns
- **Table of Contents Compatibility**: Avoid creating section headers that disrupt ToC structure; use inline bold text for visual emphasis instead of additional heading levels

### Quality Assurance
- **AsciiDoctor Validation**: Ensure all documents compile without errors
- **Cross-Reference Checking**: Verify all internal links resolve correctly
- **Link Validation**: Test external links for accessibility

## **Version Reference Guidelines**

### PacketFence Version Format
- **Correct Format**: Always use X.Y format (e.g., "13.2", "10.3")
- **Incorrect Format**: Never use X.Y.Z format (e.g., "13.2.1", "10.3.0")
- **Consistency**: Maintain this format throughout all documentation references

## **Code & Configuration Handling**

### Content Preservation
- **Never Modify Contents**: Do not alter the actual content of code blocks, configuration examples, or command outputs
- **Preserve Indentation**: Maintain exact indentation, spacing, and formatting within code blocks and config examples
- **Block Integrity**: Treat all content within AsciiDoc code delimiters (`----`, `....`, etc.) as immutable
- **Example Accuracy**: Ensure all technical examples remain functionally correct

## **Testing & Validation**

### Build Testing
- **Command**: Always run `make clean && make html` from `/usr/local/pf/` after making changes
- **Dependencies**: See [filename]`docs/README.md` for complete dependency installation instructions for supported operating systems
- **Error Resolution**: Fix any compilation errors, warnings, or broken references before committing
- **Link Verification**: Ensure all cross-references and includes resolve correctly

## **Writing Style Guidelines**

### Language Standards
- **Clear & Concise**: Use direct, technical language without unnecessary elaboration
- **Voice & Person**: Avoid second-person ("you") and third-person references
- **Imperative Mood**: Use imperative mood for instructions (e.g., "Configure the service" not "You should configure the service")
- **Technical Precision**: Focus on facts, procedures, and objective information rather than conversational tone

### FAQ Documentation Standards
- **Dedicated Guidelines**: For FAQ-specific work, reference `/usr/local/pf/docs/FAQ_GUIDELINES.md`
- **Comprehensive Coverage**: FAQ_GUIDELINES.md contains complete standards for structure, formatting, content quality, and thread research
- **Mandatory Usage**: Always consult FAQ_GUIDELINES.md before creating, modifying, or reviewing FAQ entries
- **Consistency Enforcement**: FAQ_GUIDELINES.md ensures uniform standards across all PacketFence FAQ documentation

### Privacy Standards
- **No Real Names**: Never include real individual names in documentation, FAQ entries, or CLAUDE.md
- **Anonymous Attribution**: Refer to authoritative sources by domain only (e.g., "@inverse.ca developer" instead of specific names)
- **Professional Neutrality**: Maintain professional documentation standards while protecting individual privacy
- **Privacy Compliance Verified**: FAQ_GUIDELINES.md has been verified clean of real names (2025-09-18)
- **Ongoing Vigilance**: Always check for real names during any content updates or additions

## **Link Management**

### Protocol Standards
- **HTTPS Required**: Always use `https://` instead of `http://` for all external links
- **Link Validation**: Test all external links before adding them to documentation
- **Redirect Handling**: When links redirect, warn the user and replace with the final redirect URL
- **Link Updates**: When updating existing HTTP links to HTTPS, verify the target still works

### Community Reference Requirements
- **Direct Thread Links**: All Community Reference links must point to specific thread URLs, never to monthly digest pages
- **Multiple Thread Support**: If more than one Community Reference was used, include links to all specific threads, not just one
- **Thread URL Format**: Use complete thread URLs like `https://sourceforge.net/p/packetfence/mailman/message/MESSAGEID/`

## **Critical Things NOT to Change**

### System Files
- **Global Attributes**: Never modify `/includes/global-attributes.asciidoc` or `/includes/docinfo.asciidoc` - these control document-wide settings
- **Include Structure**: Don't break the include chain that connects main guides to content files
- **Cross-References**: Preserve existing `<<file.asciidoc#,title>>` patterns for inter-document linking
- **Version Variables**: Don't modify release version placeholders like `{release_version}` and `{docyear}`

### File Organization
- **Directory Structure**: Don't move files between directories without updating all references
- **Filename Conventions**: Maintain existing filename patterns and extensions

### Technical Content
- **Code Content**: Never alter the contents of code blocks, configuration examples, or technical examples
- **Command Syntax**: Preserve exact command line syntax and parameters
- **Configuration Format**: Maintain precise configuration file formatting

## **Documentation Maintenance and Quality Control**

### Documentation Quality Control
- **General Standards**: Always run `make clean && make html` before committing changes
- **FAQ-Specific Process**: For FAQ entries, follow complete checklist in FAQ_GUIDELINES.md
- **Link Verification**: Test all external links and ensure accessibility
- **Cross-Reference Check**: Verify all internal document links and section references work

### Ongoing Maintenance Standards
- **Regular Updates**: Review FAQ entries quarterly for version relevance and link validity
- **Community Feedback**: Monitor mailing list for new frequent issues requiring FAQ coverage
- **Solution Evolution**: Update existing entries when better solutions are discovered
- **Link Maintenance**: Check and update community reference links if threads become unavailable
- **Performance Monitoring**: Track FAQ usage and prioritize improvements for most-accessed entries

## **Common Pitfalls to Avoid**

### Critical Formatting Standards
- **FAQ-Specific Rules**: Detailed formatting requirements are in FAQ_GUIDELINES.md
- **General AsciiDoc**: Follow standard AsciiDoc syntax for all non-FAQ content
- **Consistency**: Maintain uniform formatting across document types

### Content Quality Issues
- **Unverified Solutions**: Don't include solutions that haven't been validated by authoritative sources
- **Incomplete Troubleshooting**: Ensure solution steps are complete and actionable, not just diagnostic steps
- **Privacy Violations**: Never include real names of community members in documentation
- **Missing Error Context**: Always include specific error messages and log entries when available
- **Generic References**: Avoid linking to monthly digest pages instead of specific thread URLs

### Technical Validation Failures
- **Untested Commands**: All code examples should be tested or validated before inclusion
- **Version Conflicts**: Ensure solutions are appropriate for the specified PacketFence versions
- **Missing Dependencies**: Include information about required packages, services, or configurations
- **Incomplete Steps**: Verify troubleshooting procedures include verification/testing steps

## **Specialized Documentation Guidelines**

### FAQ Documentation Workflow
- **ALWAYS use FAQ_GUIDELINES.md** for any work involving PacketFence FAQ entries
- **Reference the dedicated file** at `/usr/local/pf/docs/FAQ_GUIDELINES.md` before creating, editing, or reviewing FAQ content
- **Follow all standards** in FAQ_GUIDELINES.md including formatting templates, thread research methodology, and quality control processes
- **FAQ_GUIDELINES.md is authoritative** for all FAQ-related work and supersedes general documentation guidelines for FAQ content

## **Working Approach Guidelines**

### Professional Standards
- **Be Direct & Objective**: Prioritize technical accuracy over validation
- **Respectful Disagreement**: Disagree respectfully when necessary rather than agreeing with incorrect assumptions
- **Ask Clarifying Questions**: When requirements are unclear, scope is ambiguous, or multiple approaches exist, ask specific questions before proceeding
- **Challenge Assumptions**: If a proposed change seems problematic or goes against established patterns, explain why and suggest alternatives

## **File Operations**

### Error Handling for File Operations
When writing files, please:
- Retry failed operations 2-3 times
- Show the error message and retry attempt
- Only move on after multiple failures
- Suggest alternative approaches if retries fail

## **File Maintenance**

### Guidelines Evolution
- **Auto-Update**: Always update this CLAUDE.md file automatically when new rules or guidelines are discovered
- **User Confirmation**: Always ask the Claude user if they wish to append new rules to this file when patterns emerge
- **Rule Evolution**: Keep guidelines current with project changes and lessons learned
- **Documentation**: Document the reasoning behind new guidelines for future reference

### Change Management Standards
- **Impact Assessment**: Evaluate how changes affect existing FAQ entries and overall documentation structure
- **Backward Compatibility**: Ensure formatting changes don't break existing cross-references or includes
- **Version Tracking**: Document major changes to guidelines with dates and reasons
- **Rollback Procedures**: Maintain ability to revert changes if they cause compilation or formatting issues
- **Testing Protocol**: Test all changes across different FAQ sections to ensure consistency

## **Git Workflow**

### Version Control Best Practices
- **Feature Branches**: Use feature branches for all changes, not direct commits to main branches
- **Descriptive Commits**: Write clear, descriptive commit messages explaining the changes
- **Build Testing**: Test compilation before committing any changes
- **Related Changes**: Group logically related changes in single commits
- **Commit Frequency**: Commit early and often with logical breakpoints

## **Common Patterns to Follow**

### Cross-Reference Format
```asciidoc
<<PacketFence_Installation_Guide.asciidoc#,Installation Guide>>
```

### Section ID Format
```asciidoc
[[section-identifier]]
== Section Title
```

### Code Block Format
```asciidoc
----
# Configuration example
config_option = value
----
```



This file ensures consistent, professional documentation work while maintaining the integrity of the PacketFence documentation system.