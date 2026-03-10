# PacketFence Documentation Build System

This directory contains the PacketFence documentation written in [AsciiDoc](https://www.methods.co.nz/asciidoc/) format and the build system to generate HTML and PDF versions.

## Overview

The PacketFence documentation uses:
- **AsciiDoc** format for source files
- **[Asciidoctor](https://asciidoctor.org/)** for HTML/PDF generation (.asciidoc to .html)
- **[Asciidoctor-PDF](https://asciidoctor.org/docs/asciidoctor-pdf/)** for PDF generation (.asciidoc to .pdf)
- **[Rouge](https://github.com/rouge-ruby/rouge)** syntax highlighter
- **Custom Ruby processor** for HTML styling integration
- **Custom PDF theme** with Instrument Sans and Inconsolata fonts
- **JSON index generation** for HTML file metadata

## Build System

The documentation build system is controlled by Makefile targets in `/usr/local/pf/Makefile`.

### Available Targets

#### Core Build Targets
- `make html` - Generates all HTML guides + JSON index
- `make pdf` - Generates all PDF guides
- `make clean` - Removes all generated documentation files
- `make images` - Installs images for packaging (used by build system)

#### Individual PDF Targets
- `make docs/PacketFence_Installation_Guide.pdf`
- `make docs/PacketFence_Clustering_Guide.pdf`
- `make docs/PacketFence_Developers_Guide.pdf`
- `make docs/PacketFence_Network_Devices_Configuration_Guide.pdf`
- `make docs/PacketFence_Upgrade_Guide.pdf`

#### Generated Files
- `docs/*.html` - HTML versions of each guide
- `docs/*.pdf` - PDF versions of each guide
- `docs/index.js` - JSON metadata index of HTML files

## Dependencies

### Debian 12 (Bookworm)

Install system packages:
```bash
sudo apt update
sudo apt install asciidoctor ruby-dev build-essential jq
```

Install Ruby gems:
```bash
sudo gem install asciidoctor-pdf rouge
```

### Enterprise Linux 8 (RHEL8/CentOS8/Rocky8/AlmaLinux8)

Install system packages:
```bash
sudo dnf install rubygem-asciidoctor ruby-devel gcc make jq
```

Install Ruby gems:
```bash
sudo gem install asciidoctor-pdf rouge
```

## Custom Components

### HTML Generation
- **Custom Processor**: `asciidoctor-html.rb` - Integrates PacketFence admin interface CSS styling
- **CSS Integration**: Uses PacketFence's Bootstrap-based CSS from `html/pfappserver/root/dist/css/`
- **Index Generation**: Creates `docs/index.js` with file metadata using `jq`

### PDF Generation
- **Custom Theme**: `asciidoctor-pdf-theme.yml` - PacketFence branding and typography
- **Fonts**: Custom Instrument Sans and Inconsolata fonts in `docs/fonts/`
- **Theme Features**: Consistent branding, code syntax highlighting, proper typography

## Build Process

### HTML Build Process
1. Processes each `*.asciidoc` file with custom `asciidoctor-html.rb` processor
2. Applies PacketFence CSS styling from admin interface
3. Generates individual HTML files in `docs/`
4. Creates JSON index with file metadata using `jq`

### PDF Build Process
1. Uses `asciidoctor-pdf` with custom theme
2. Applies Instrument Sans fonts for body text, Inconsolata for code
3. Generates branded PDF files in `docs/`

## Usage Examples

Generate all HTML documentation:
```bash
cd /usr/local/pf
make clean
make html
```

Generate all PDF documentation:
```bash
cd /usr/local/pf
make clean
make pdf
```

Generate specific guide:
```bash
cd /usr/local/pf
make docs/PacketFence_Installation_Guide.pdf
```

## Troubleshooting

### Common Issues

**PDF Generation Fails**
- Ensure `asciidoctor-pdf` gem is installed: `gem list | grep asciidoctor-pdf`
- Check font permissions in `docs/fonts/`

**HTML Styling Issues**
- Verify PacketFence CSS files exist in `html/pfappserver/root/dist/css/`
- Check `asciidoctor-html.rb` processor can be loaded

**Build Permission Errors**
- Ensure write permissions to `docs/` directory
- Check Ruby gem installation permissions

**Missing jq Command**
- Install jq package: `apt install jq` (Debian) or `dnf install jq` (EL8)

### Verification

Test build system:
```bash
cd /usr/local/pf
make clean && make html
ls -la docs/*.html docs/index.js
```

Check dependencies:
```bash
asciidoctor --version
gem list | grep asciidoctor-pdf
jq --version
```

## File Structure

```
docs/
├── README.md                          # This file
├── asciidoctor-html.rb               # Custom HTML processor
├── asciidoctor-pdf-theme.yml         # Custom PDF theme
├── fonts/                            # Custom fonts for PDF
│   ├── inconsolata.ttf              # Monospace font
│   └── instrument-sans/             # Sans-serif font family
├── images/                          # Documentation images
├── includes/                        # Shared AsciiDoc includes
├── PacketFence_*.asciidoc          # Main guide sources
├── installation/                    # Installation guide chapters
├── network/                        # Network configuration chapters
├── developer/                      # Developer guide chapters
├── cluster/                        # Clustering guide chapters
├── troubleshooting/               # Troubleshooting chapters
└── upgrade-notes/                 # Upgrade guide chapters
```

## Integration with Build System

The documentation build system integrates with PacketFence's overall build system:
- CI/CD pipelines use `make html pdf` for release documentation
- Package builds include generated HTML/PDF in distribution archives
- Images target supports installation to system directories