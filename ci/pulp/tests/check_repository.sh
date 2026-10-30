#!/bin/bash
# Run in the publish-ppa image. Builds tiny fixture packages, never installs them.
set -euo pipefail
source_root=$(cd "$(dirname "$0")/../../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"
gpg --batch --passphrase '' --quick-generate-key 'Pulp CI fixture <fixture@example.invalid>' rsa2048 sign 1d
export GPG_KEY_FINGERPRINT=$(gpg --with-colons --list-keys | awk -F: '$1=="fpr" {print $10;exit}')
export CI_PIPELINE_ID=12345 CI_COMMIT_SHA=fixture CI_COMMIT_REF_NAME=fixture
export RESULT_DIR="$work/result" PUBLIC_DIR="$work/public" PPA_DEPENDENCIES_DIR="$work/dependencies"
mkdir -p "$RESULT_DIR/debian/bookworm" "$RESULT_DIR/centos/8" "$PPA_DEPENDENCIES_DIR/debian/bookworm" "$PPA_DEPENDENCIES_DIR/centos/8"
python3 - "$work" <<'PY'
from pathlib import Path
import hashlib,subprocess,sys,os,tarfile
root=Path(sys.argv[1])
files=[]
for name, version, dependency in [('fixture-library','2.0',''),('packetfence','16.0.0','fixture-library (>= 2.0)'),('packetfence-test','16.0.0','packetfence')]:
    source=root/'deb'/name
    (source/'DEBIAN').mkdir(parents=True)
    control=f'Package: {name}\nVersion: {version}\nArchitecture: all\nMaintainer: Fixture <fixture@example.invalid>\nDescription: CI fixture\nSection: misc\nPriority: optional\n'
    if name != 'fixture-library': control+='Source: packetfence\n'
    if dependency: control+='Depends: '+dependency+'\n'
    (source/'DEBIAN/control').write_text(control)
    dest=root/('dependencies' if name=='fixture-library' else 'result')/'debian/bookworm'/f'{name}_{version}_all.deb'
    subprocess.run(['dpkg-deb','--build',str(source),str(dest)],check=True)
    if name!='fixture-library': files.append(dest)
# Include a real signed Debian source control file and source archive.
source = root/'source'
source.mkdir()
(source/'README').write_text('fixture source\n')
archive = root/'result/debian/bookworm/packetfence_16.0.0.tar.gz'
with tarfile.open(archive, 'w:gz') as tar:
    tar.add(source, arcname='packetfence-16.0.0')
dsc = root/'result/debian/bookworm/packetfence_16.0.0.dsc'
unsigned = root/'source.dsc'
unsigned.write_text('Format: 1.0\nSource: packetfence\nBinary: packetfence, packetfence-test\nArchitecture: any\nVersion: 16.0.0\nMaintainer: Fixture <fixture@example.invalid>\nStandards-Version: 3.9.8\nFiles:\n '+hashlib.md5(archive.read_bytes()).hexdigest()+f' {archive.stat().st_size} {archive.name}\n')
subprocess.run(['gpg','--batch','--yes','--local-user',os.environ['GPG_KEY_FINGERPRINT'],'--clearsign','--output',str(dsc),str(unsigned)],check=True)
files.extend([dsc,archive])
text='Format: 1.8\nDate: Wed, 21 Oct 2026 00:00:00 +0000\nSource: packetfence\nBinary: packetfence packetfence-test\nArchitecture: source all\nVersion: 16.0.0\nDistribution: bookworm\nUrgency: low\nMaintainer: Fixture <fixture@example.invalid>\nChanged-By: Fixture <fixture@example.invalid>\nDescription:\n packetfence - fixture\n packetfence-test - fixture\nChanges:\n packetfence (16.0.0) bookworm; urgency=low\n .\n  * Fixture.\nChecksums-Sha256:\n'
for p in files: text+=f' {hashlib.sha256(p.read_bytes()).hexdigest()} {p.stat().st_size} {p.name}\n'
text+='Files:\n'
for p in files: text+=f' {hashlib.md5(p.read_bytes()).hexdigest()} {p.stat().st_size} misc optional {p.name}\n'
(root/'result/debian/bookworm/packetfence_16.0.0_all.changes').write_text(text)
PY
for name in fixture-library packetfence packetfence-test; do
    requires=''
    case "$name" in
        packetfence) requires='Requires: fixture-library >= 2.0' ;;
        packetfence-test) requires='Requires: packetfence' ;;
    esac
    cat > "$work/package.spec" <<EOF
Name: $name
Version: 16.0.0
Release: 1
Summary: CI fixture
License: MIT
BuildArch: noarch
$requires
%description
CI fixture
%install
mkdir -p %{buildroot}/usr/share/$name
printf fixture > %{buildroot}/usr/share/$name/fixture
%files
/usr/share/$name/fixture
EOF
    rpmbuild --define "_topdir $work/rpm" -ba "$work/package.spec" >/dev/null
    rpmfile="$work/rpm/RPMS/noarch/$name-16.0.0-1.noarch.rpm"
    rpmsign --define "_gpg_name $GPG_KEY_FINGERPRINT" --define "_gpg_path $GNUPGHOME" --define '__gpg /usr/bin/gpg' --addsign "$rpmfile"
    if [[ "$name" == fixture-library ]]; then
        cp "$rpmfile" "$PPA_DEPENDENCIES_DIR/centos/8/"
    else
        cp "$rpmfile" "$RESULT_DIR/centos/8/"
        cp "$work/rpm/SRPMS/$name-16.0.0-1.src.rpm" "$RESULT_DIR/centos/8/"
    fi
done
bash "$source_root/ci/scripts/generate-pages.sh" > "$work/generator.log"
test -s "$PUBLIC_DIR/debian/dists/bookworm/InRelease"
test -s "$PUBLIC_DIR/centos/8/x86_64/repodata/repomd.xml.asc"
test -s "$PUBLIC_DIR/centos/8/Source/packetfence-16.0.0-1.src.rpm"
test -s "$PUBLIC_DIR/debian/pool/main/p/packetfence/packetfence_16.0.0.dsc"
zcat "$PUBLIC_DIR/debian/dists/bookworm/main/binary-amd64/Packages.gz" | grep -q '^Package: fixture-library$'
export PF_PULP_DEBIAN_SOURCES_FILE="$work/os.list" PF_PULP_RPM_REPOS_DIR="$work/os-repos"
: > "$PF_PULP_DEBIAN_SOURCES_FILE"
mkdir "$PF_PULP_RPM_REPOS_DIR"
# An empty approved OS repo file: the fixture packages have no OS dependencies.
: > "$PF_PULP_RPM_REPOS_DIR/empty.repo"
bash "$source_root/ci/pulp/validate-repository.sh" "$PUBLIC_DIR" > "$work/validation.log" 2>&1 || { cat "$work/validation.log"; exit 1; }
# A generated tree without its dependency must fail before publication.
mv "$RESULT_DIR/.apt" "$work/apt-before"
export PUBLIC_DIR="$work/incomplete" PPA_DEPENDENCIES_DIR=''
bash "$source_root/ci/scripts/generate-pages.sh" > "$work/incomplete.log"
if bash "$source_root/ci/pulp/validate-repository.sh" "$PUBLIC_DIR" > "$work/missing.log" 2>&1; then
    echo 'ERROR: missing dependency passed validation' >&2
    exit 1
fi
echo 'Real signed Debian/RPM generation, dependency inclusion, Debian source/SRPM preservation and missing-dependency rejection passed'
