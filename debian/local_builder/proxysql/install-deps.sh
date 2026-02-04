#!/bin/bash
# Install build dependencies based on version from deps.conf
set -e

usage() {
    echo "Usage: $0 [-h|--help] [-n|--dry-run] [-v|--verbose] <version> [deps.conf]"
    echo ""
    echo "Install build dependencies based on version from deps.conf."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -n, --dry-run  Show packages without installing"
    echo "  -v, --verbose  Show pattern matching debug"
    echo ""
    echo "Arguments:"
    echo "  version        ProxySQL version (e.g., 3.0.5, 2.6.0)"
    echo "  deps.conf      Dependencies file (default: /tmp/deps.conf)"
    echo ""
    echo "Examples:"
    echo "  $0 3.0.5                          # Install deps for 3.0.5"
    echo "  $0 -n 3.0.5 deps.conf             # Dry-run with custom file"
    echo "  $0 -v -n 2.6.0 /tmp/deps.conf     # Verbose dry-run"
    exit 0
}

DRY_RUN=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [-h|--help] [-n|--dry-run] [-v|--verbose] <version> [deps.conf]" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

VERSION="$1"
DEPS_FILE="${2:-/tmp/deps.conf}"

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 [-n|--dry-run] [-v|--verbose] <version> [deps.conf]" >&2
    exit 1
fi

if [[ ! -f "$DEPS_FILE" ]]; then
    echo "Error: deps.conf not found at $DEPS_FILE" >&2
    exit 1
fi

[[ $VERBOSE -eq 1 ]] && echo "Reading dependencies from: $DEPS_FILE"
[[ $VERBOSE -eq 1 ]] && echo "Version: $VERSION"

PACKAGES=""

# Read deps.conf and collect packages
while IFS='|' read -r pattern packages; do
    # Skip comments and empty lines
    [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue

    # Check if pattern matches
    if [[ "$pattern" == "BASE" ]]; then
        [[ $VERBOSE -eq 1 ]] && echo "Matched BASE: $packages"
        PACKAGES="$PACKAGES $packages"
    elif [[ "$VERSION" == $pattern ]]; then
        [[ $VERBOSE -eq 1 ]] && echo "Matched $pattern: $packages"
        PACKAGES="$PACKAGES $packages"
    fi
done < "$DEPS_FILE"

# Remove leading/trailing whitespace and duplicates
PACKAGES=$(echo "$PACKAGES" | tr ' ' '\n' | sort -u | tr '\n' ' ')

echo "Dependencies for version $VERSION:"
echo "$PACKAGES"
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY-RUN] Would run: apt-get install -y $PACKAGES"
    exit 0
fi

# Check if apt-get is available
if ! command -v apt-get &> /dev/null; then
    echo "Warning: apt-get not found, skipping installation" >&2
    echo "Packages needed: $PACKAGES"
    exit 0
fi

apt-get update
apt-get install -y $PACKAGES
apt-get clean
rm -rf /var/lib/apt/lists/
