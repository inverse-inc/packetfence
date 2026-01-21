#!/bin/bash
set -o nounset -o pipefail -o errexit

#
# setup-dev-env.sh - Set up a PacketFence development environment
#
# This script prepares a PacketFence installation for development by:
# - Replacing /usr/local/pf with a git clone of the PacketFence repository
# - Installing build dependencies (Node.js, Ruby, Go, etc.)
# - Building the web admin, captive portal, and documentation
# - Setting up container files for local development
#
# Prerequisites:
# - PacketFence must be installed
# - The configuration wizard must be completed (management interface configured)
#

# Default values
LOCAL_DEV=false

die() {
    echo "$(basename $0): $@" >&2 ; exit 1
}

log_section() {
   printf '=%.0s' {1..72} ; printf "\n"
   printf "=\t%s\n" "" "$@" ""
}

show_help() {
    cat << EOF
Usage: $(basename $0) [OPTIONS]

Set up a PacketFence development environment.

This script transforms a PacketFence installation into a development environment
by cloning the git repository, installing build tools, and compiling all components.

OPTIONS:
    -h, --help          Show this help message and exit
    --local-dev         Enable local development mode (sets LOCAL_DEV=true in
                        containers/.local_env). This configures containers to use
                        local builds instead of pulling from the registry.
                        WARNING: When enabled, starting any dockerized service will
                        rebuild it from scratch, including pfdebian (~3.5GB).
                        This requires significant disk space and CPU resources.

ENVIRONMENT VARIABLES:
    BRANCH              Git branch to checkout (default: devel)

PREREQUISITES:
    - PacketFence must be installed (package: packetfence)
    - Configuration wizard must be completed (management interface configured)

EXAMPLES:
    $(basename $0)                  # Standard setup with LOCAL_DEV=false
    $(basename $0) --local-dev      # Setup with local development mode enabled
    BRANCH=feature/xyz $(basename $0)   # Setup using a specific branch

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        --local-dev)
            LOCAL_DEV=true
            shift
            ;;
        *)
            die "Unknown option: $1. Use --help for usage information."
            ;;
    esac
done

# Detect OS type
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu)
                OS_TYPE="debian"
                ;;
            rhel|centos|rocky|almalinux|fedora)
                OS_TYPE="rhel"
                ;;
            *)
                die "Unsupported Linux distribution: $ID"
                ;;
        esac
    else
        die "/etc/os-release not found; unsupported OS"
    fi
}

detect_os

## Check if PacketFence is installed
log_section "Checking if PacketFence is installed"
PF_INSTALLED=false
case "$OS_TYPE" in
    debian)
        if dpkg -l packetfence 2>/dev/null | grep -q "^ii"; then
            PF_INSTALLED=true
        fi
        ;;
    rhel)
        if rpm -q packetfence >/dev/null 2>&1; then
            PF_INSTALLED=true
        fi
        ;;
esac

if [ "$PF_INSTALLED" = false ]; then
    echo "PacketFence is not installed."
    echo "Please install PacketFence first and complete the configuration wizard before running this script."
    echo "Visit https://www.packetfence.org/doc/PacketFence_Installation_Guide.html for installation instructions."
    exit 1
fi
echo "PacketFence is installed."

## Check if wizard has been completed (management interface configured)
log_section "Checking if configuration wizard has been completed"
PF_CONF="/usr/local/pf/conf/pf.conf"
if [ ! -f "$PF_CONF" ]; then
    echo "Configuration file $PF_CONF not found."
    echo "Please complete the PacketFence configuration wizard to set up a basic installation."
    exit 1
fi

# Check for management interface in pf.conf
if ! grep -q "^\[interface " "$PF_CONF" || ! grep -q "type=.*management" "$PF_CONF"; then
    echo "No management interface configured in $PF_CONF."
    echo "Please complete the PacketFence configuration wizard to set up the management interface."
    echo "You can access the wizard at https://<your-server-ip>:1443/configurator"
    exit 1
fi
echo "Management interface is configured."

## Install build dependencies
log_section "Installing build dependencies"
case "$OS_TYPE" in
    debian)
        apt install -y build-essential devscripts dpkg-dev fakeroot git tmux vim gnupg sudo curl
        ;;
    rhel)
        dnf groupinstall -y 'Development Tools'
        dnf install -y curl-devel git rpm-build tmux vim gnupg2 sudo curl
        ;;
esac

## Check and install Node.js if needed
log_section "Checking Node.js installation"

# Get required Node.js version from debian/control, default to 20 if not found
NODEJS_VERSION="20"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBIAN_CONTROL="$SCRIPT_DIR/../../debian/control"
if [ -f "$DEBIAN_CONTROL" ]; then
    # Extract version from nodejs (>= X.Y) pattern
    EXTRACTED_VERSION=$(grep -oP 'nodejs \(>= \K[0-9]+' "$DEBIAN_CONTROL" 2>/dev/null || echo "")
    if [ -n "$EXTRACTED_VERSION" ]; then
        NODEJS_VERSION="$EXTRACTED_VERSION"
        echo "Found Node.js version requirement in debian/control: $NODEJS_VERSION"
    else
        echo "Could not extract Node.js version from debian/control, using default: $NODEJS_VERSION"
    fi
else
    echo "debian/control not found, using default Node.js version: $NODEJS_VERSION"
fi

if ! type node 2>/dev/null || ! type npm 2>/dev/null; then
    echo "Node.js or npm is not installed. Installing Node.js $NODEJS_VERSION..."
    case "$OS_TYPE" in
        debian)
            curl -fsSL "https://deb.nodesource.com/setup_${NODEJS_VERSION}.x" | bash -
            apt install -y nodejs
            ;;
        rhel)
            dnf module install "nodejs:${NODEJS_VERSION}" -y
            ;;
    esac

    # Verify installation
    if ! type node 2>/dev/null || ! type npm 2>/dev/null; then
        die "Failed to install Node.js. Please install it manually."
    fi
    echo "Node.js installed successfully."
else
    INSTALLED_NODE_VERSION=$(node --version | grep -oP 'v\K[0-9]+')
    echo "Node.js is already installed (version: $(node --version))"
    if [ "$INSTALLED_NODE_VERSION" -lt "$NODEJS_VERSION" ]; then
        echo "Warning: Installed Node.js version is older than required ($NODEJS_VERSION). Consider upgrading."
    fi
fi

log_section "Cleanup previous dev setup directories"
rm -fr /usr/local/go
if [ ! -d "/usr/local/pf-pkg/lib_perl" ]; then
    echo "Directory /usr/local/pf-pkg/lib_perl not found. Removing /usr/local/pf-pkg/..."
    rm -rf /usr/local/pf-pkg/
else
    echo "Directory /usr/local/pf-pkg/lib_perl exists. No action taken."
fi

log_section "Stop services"
systemctl isolate multi-user

log_section "Replace /usr/local/pf by git repository"
if [ ! -d "/usr/local/pf-pkg/lib_perl" ]; then
    echo "Directory /usr/local/pf-pkg/lib_perl not found. Move /usr/local/pf/ to /usr/local/pf-pkg"
    mv /usr/local/pf /usr/local/pf-pkg
    git clone https://github.com/inverse-inc/packetfence /usr/local/pf
else
    echo "Directory /usr/local/pf-pkg/lib_perl exists. Git pull only."
    cd /usr/local/pf
    git pull
fi

log_section "Set the safe.directory in git"
git config --global --add safe.directory /usr/local/pf

log_section "install required header files from PF repo"

case "$OS_TYPE" in
    debian)
        echo "Installing header files for Debian-based system"
        apt install -y libcurl4-openssl-dev libcjson-dev
        ;;
    rhel)
        echo "Installing header files for Red Hat-based system"
        dnf install -y --enablerepo=packetfence libcurl-devel cjson-devel
        ;;
esac

cd /usr/local/pf/

BRANCH=${BRANCH:-devel}
git checkout $BRANCH

log_section "Create all necessary files"

# to have all Perl dependencies at correct location
cp -r /usr/local/pf-pkg/lib_perl /usr/local/pf/

cd /usr/local/pf
make devel
make conf/ssl/server.pem
mkdir -p /usr/local/pf/var/ssl_mutex
mkdir -p /usr/local/pf/logs
mkdir -p /usr/local/pf/conf/ssl/acme-challenge
# to keep settings set up during configurator
cp /usr/local/pf-pkg/conf/pf.conf conf/
cp /usr/local/pf-pkg/conf/pfconfig.conf conf/
cp /usr/local/pf-pkg/conf/networks.conf conf/
cp /usr/local/pf-pkg/sbin/sdnotify-proxy sbin/sdnotify-proxy
cp /usr/local/pf-pkg/conf/system_init_key /usr/local/pf/conf/system_init_key

log_section "Install asciidoc*"

case "$OS_TYPE" in
    debian)
        echo "Installing Ruby for Debian-based system"
        apt install -y ruby ruby-dev build-essential
        ;;
    rhel)
        echo "Installing Ruby for Red Hat-based system"
        dnf module reset ruby -y
        yum install -y @ruby:2.6
        ;;
esac

# Check if gems are already installed to avoid reinstalling
if ! gem list -i asciidoctor > /dev/null 2>&1; then
    gem install asciidoctor
else
    echo "asciidoctor already installed, skipping..."
fi

if ! gem list -i asciidoctor-pdf > /dev/null 2>&1; then
    gem install asciidoctor-pdf
else
    echo "asciidoctor-pdf already installed, skipping..."
fi

if ! gem list -i rouge > /dev/null 2>&1; then
    gem install rouge -f
else
    echo "rouge already installed, skipping..."
fi

log_section "Build web admin"
cd /usr/local/pf/html/pfappserver/root/
make vendor
npm run build-debug

log_section "Build captive portal"
cd /usr/local/pf/html/common
make vendor
make dev

log_section "Build Golang environment"
cd /usr/local/pf/go
make go-env
make all
make copy

log_section "Build Artifacts DOCS devel"
cd /usr/local/pf
make -C html/pfappserver/root/ vendor
make -C html/pfappserver/root/ light-dist
make pdf
make html

log_section "Setup container files"
cd /usr/local/pf
TAG_OR_BRANCH_NAME=`git rev-parse --abbrev-ref HEAD | sed 's#[/|.]#-#g'`
echo -n TAG_OR_BRANCH_NAME=$TAG_OR_BRANCH_NAME > conf/build_id
echo LOCAL_DEV=$LOCAL_DEV > containers/.local_env

for img in pfbuild-debian-bookworm pfdebian radiusd; do
  docker pull ghcr.io/inverse-inc/packetfence/$img:$TAG_OR_BRANCH_NAME
  docker tag ghcr.io/inverse-inc/packetfence/$img:$TAG_OR_BRANCH_NAME packetfence/$img:$TAG_OR_BRANCH_NAME
done

log_section "Fix permissions and start unmanaged services"
cd /usr/local/pf
# Ensure critical files exist before fixing permissions
if [ ! -f conf/system_init_key ]; then
    echo "Creating system_init_key..."
    make conf/system_init_key
fi
if [ ! -L lib/fingerbank ]; then
    echo "Creating fingerbank symlink..."
    make fingerbank
fi
make permissions
systemctl start packetfence-config packetfence-redis-cache
while ! /usr/local/pf/bin/pfcmd pfconfig get resource::fqdn 2>&1| grep last_touch_cache > /dev/null ; do
        echo "Waiting for pfconfig to be online..."
done
echo "pfconfig is now online!"
systemctl start packetfence-mariadb
systemctl restart rsyslog

log_section "Start all PF services"
/usr/local/pf/bin/pfcmd service pf restart

