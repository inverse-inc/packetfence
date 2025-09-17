# PacketFence Documentation Guidelines for AI Assistants

This file contains guidelines for AI assistants working with PacketFence documentation to ensure consistency, accuracy, and maintainability.

## **Documentation Standards & Guidelines**

### Formatting Rules
- **Line Length**: Maximum 80 characters per line for better readability
- **Line Endings**: Maintain CRLF line endings where established
- **Section Prefixing**: Prefix section titles with [filename] for context
- **AsciiDoc Syntax**: Use proper AsciiDoc formatting for headers, lists, code blocks, and cross-references

### Content Organization
- **Heading Hierarchy**: Use consistent heading levels (=, ==, ===, ====)
- **Logical Grouping**: Keep related content together
- **Standardized Includes**: Follow existing include file structure and patterns

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
- **Dependency Resolution**: When running build commands for first time, resolve any missing dependencies as needed
- **Error Resolution**: Fix any compilation errors, warnings, or broken references before committing
- **Link Verification**: Ensure all cross-references and includes resolve correctly

## **Writing Style Guidelines**

### Language Standards
- **Clear & Concise**: Use direct, technical language without unnecessary elaboration
- **Voice & Person**: Avoid second-person ("you") and third-person references
- **Imperative Mood**: Use imperative mood for instructions (e.g., "Configure the service" not "You should configure the service")
- **Technical Precision**: Focus on facts, procedures, and objective information rather than conversational tone

## **Link Management**

### Protocol Standards
- **HTTPS Required**: Always use `https://` instead of `http://` for all external links
- **Link Validation**: Test all external links before adding them to documentation
- **Redirect Handling**: When links redirect, warn the user and replace with the final redirect URL
- **Link Updates**: When updating existing HTTP links to HTTPS, verify the target still works

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

## **Working Approach Guidelines**

### Professional Standards
- **Be Direct & Objective**: Prioritize technical accuracy over validation
- **Respectful Disagreement**: Disagree respectfully when necessary rather than agreeing with incorrect assumptions
- **Ask Clarifying Questions**: When requirements are unclear, scope is ambiguous, or multiple approaches exist, ask specific questions before proceeding
- **Challenge Assumptions**: If a proposed change seems problematic or goes against established patterns, explain why and suggest alternatives

## **File Maintenance**

### Guidelines Evolution
- **Auto-Update**: Always update this CLAUDE.md file automatically when new rules or guidelines are discovered
- **User Confirmation**: Always ask the Claude user if they wish to append new rules to this file when patterns emerge
- **Rule Evolution**: Keep guidelines current with project changes and lessons learned
- **Documentation**: Document the reasoning behind new guidelines for future reference

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