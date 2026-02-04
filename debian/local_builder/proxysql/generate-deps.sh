#!/bin/bash
# Generate deps.conf for proxysql build dependencies
set -e

usage() {
    echo "Usage: $0 [-h|--help] [output_file]"
    echo ""
    echo "Generate deps.conf for proxysql build dependencies."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Arguments:"
    echo "  output_file   Output file (default: stdout)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Print to stdout"
    echo "  $0 deps.conf          # Write to deps.conf"
    echo "  $0 /tmp/deps.conf     # Write to /tmp/deps.conf"
    exit 0
}

case "${1:-}" in
    -h|--help)
        usage
        ;;
esac

OUTPUT="${1:-/dev/stdout}"

cat > "$OUTPUT" << 'EOF'
# ProxySQL build dependencies by major version
# Format: VERSION_PATTERN|package1 package2 package3 ...

# Common base dependencies for all versions
BASE|automake cmake equivs g++ gawk gcc gdb gdbserver git libgnutls28-dev libmariadb-dev libssl-dev libtool make python3 uuid-dev libsystemd-dev systemd

# 3.x requires additional packages
3.*|bison bzip2 flex libevent-dev libicu-dev libncurses-dev libtirpc-dev libunwind-dev libunwind8 openssl

# 2.x has fewer requirements
2.*|bzip2
EOF

if [[ "$OUTPUT" != "/dev/stdout" ]]; then
    echo "Generated: $OUTPUT" >&2
fi
