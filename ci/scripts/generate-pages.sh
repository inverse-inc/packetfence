#!/bin/bash
set -euo pipefail

#############################################################################
# generate-pages.sh
#
# Build an installable PacketFence PPA from the freshly built/signed packages
# and lay it out exactly the way `apt` and `yum`/`dnf` expect, plus a browsable
# HTML index on top.
#
# This is a self-contained reimplementation of the gitlab-buildpkg-tools
# `ci-pages-ppa`, `ci-pages-home` and `ci-pages-tree` scripts. It depends on
# the same underlying tools (reprepro, createrepo_c, gpg, tree) but NOT on the
# external gitlab-buildpkg-tools package, and produces the same on-disk layout
# that devel published before that dependency was removed:
#
#   PUBLIC_DIR/
#     GPG_PUBLIC_KEY                      armored repo signing key
#     debian/
#       dists/<codename>/...              signed Release/Packages   (reprepro)
#       pool/...                          .deb / .dsc / source files
#     centos/<release>/
#       x86_64/{*.rpm,repodata/}          signed yum repo           (createrepo_c)
#       Source/{*.src.rpm,repodata/}
#     index.html                          install instructions      (home page)
#     <every-subdir>/index.html           directory listing         (tree pages)
#
# Expected input layout (produced by `make build_deb` / `make build_rpm`):
#   RESULT_DIR/debian/<codename>/*.{deb,dsc,changes,tar.*}
#   RESULT_DIR/centos/<release>/*.rpm
#
# The GPG signing key must already be importable: either it lives in the gpg
# keyring of the current user (the publish_ppa job imports it in before_script)
# or it is passed armored in $GPG_PRIVATE_KEY. The key to sign with is selected
# from $GPG_KEY_FINGERPRINT, then $GPG_USER_ID, then the first secret key found.
#############################################################################

# --- configuration ---------------------------------------------------------

RESULT_DIR="${RESULT_DIR:-result}"
# Accept PAGES_DIR as an alias for backward compatibility with the upstream var.
PUBLIC_DIR="${PUBLIC_DIR:-${PAGES_DIR:-public}}"

CI_PIPELINE_ID="${CI_PIPELINE_ID:-unknown}"
CI_COMMIT_REF_NAME="${CI_COMMIT_REF_NAME:-unknown}"
CI_COMMIT_SHA="${CI_COMMIT_SHA:-unknown}"
CI_PROJECT_NAME="${CI_PROJECT_NAME:-PacketFence}"
CI_PROJECT_NAMESPACE="${CI_PROJECT_NAMESPACE:-inverse-inc}"
CI_PROJECT_URL="${CI_PROJECT_URL:-https://github.com/inverse-inc/packetfence}"

# Public base URL where this PPA will be reachable. Used only to render the
# copy/paste install instructions on the home page.
PPA_URL="${PPA_URL:-https://www.packetfence.org/downloads/PacketFence/gitlab/${CI_PIPELINE_ID}}"
# normalise: strip trailing slashes
PPA_URL="${PPA_URL%/}"

PPA_NAME="${CI_PROJECT_NAMESPACE}/${CI_PROJECT_NAME}"
PPA_SLUG="$(tr '/[:upper:]' '-[:lower:]' <<< "$PPA_NAME")"

# APT suite suffix kept identical to the historical devel layout.
APT_SUITE_SUFFIX="${APT_SUITE_SUFFIX:--gitlab}"
APT_ARCHITECTURES="${APT_ARCHITECTURES:-amd64 source}"
APT_COMPONENTS="${APT_COMPONENTS:-main}"

# --- helpers ----------------------------------------------------------------

die() { echo "${0##*/}: $*" >&2; exit 1; }

log_section() {
    printf '=%.0s' {1..72}; printf '\n'
    printf '=\t%s\n' "" "$@" ""
}

log_subsection() { printf '=\t%s\n' "" "$@" ""; }

# tree(1) is only used for human-friendly logging; never fail the build on it.
show_tree() { command -v tree >/dev/null 2>&1 && tree "$@" || true; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

# --- gpg --------------------------------------------------------------------

# Resolves $GPG_KEY_ID (used for signing) and $GPG_USER_ID (used for the public
# key export), importing $GPG_PRIVATE_KEY first if it was provided.
configure_gpg() {
    log_subsection "Configure GPG signing key"
    require_cmd gpg

    if [ -n "${GPG_PRIVATE_KEY:-}" ]; then
        echo "Importing GPG private key from \$GPG_PRIVATE_KEY"
        gpg --batch --no-tty --yes --import - <<< "$GPG_PRIVATE_KEY" \
            || die "gpg import failed"
    fi

    # Pick the signing key: explicit fingerprint > user id > first secret key.
    GPG_KEY_ID="${GPG_KEY_FINGERPRINT:-}"
    if [ -z "$GPG_KEY_ID" ] && [ -n "${GPG_USER_ID:-}" ]; then
        GPG_KEY_ID="$(gpg --list-secret-keys --with-colons "$GPG_USER_ID" 2>/dev/null \
            | awk -F: '/^sec/{print $5; exit}')"
    fi
    if [ -z "$GPG_KEY_ID" ]; then
        GPG_KEY_ID="$(gpg --list-secret-keys --with-colons 2>/dev/null \
            | awk -F: '/^sec/{print $5; exit}')"
    fi
    [ -n "$GPG_KEY_ID" ] || die "no GPG secret key available (set GPG_KEY_FINGERPRINT/GPG_USER_ID or import a key)"

    # Resolve a human user-id for the key (best effort, only for logging/export).
    GPG_USER_ID="${GPG_USER_ID:-$(gpg --list-keys --with-colons "$GPG_KEY_ID" 2>/dev/null \
        | awk -F: '/^uid/{print $10; exit}')}"

    declare -p GPG_KEY_ID GPG_USER_ID
}

export_public_key() {
    local out="$PUBLIC_DIR/GPG_PUBLIC_KEY"
    log_subsection "Export GPG public key -> $out"
    gpg --batch --no-tty --yes --armor --export --output "$out" "$GPG_KEY_ID" \
        || die "gpg export failed: $out"
    [ -s "$out" ] || die "exported public key is empty: $GPG_KEY_ID"
}

# --- release discovery ------------------------------------------------------

# Emits "<id>/<name>" for every depth-2 directory under RESULT_DIR,
# e.g. "debian/bookworm", "centos/8". Hidden dirs are ignored.
find_releases() {
    [ -d "$RESULT_DIR" ] || return 0
    (cd "$RESULT_DIR" && find . -mindepth 2 -maxdepth 2 -type d \
        | sed 's,^\./,,' | grep -v '^\.' | sort -u)
}

# --- APT repository (reprepro) ----------------------------------------------

apt_repo() {
    log_section "Build APT repositories with reprepro"
    require_cmd reprepro
    echo "releases: $*"

    local apt_db="$RESULT_DIR/.apt"
    local pub_dir
    pub_dir="$(readlink -f "$PUBLIC_DIR")"
    mkdir -p "$apt_db"

    # 1. Write a reprepro distributions config per distro id (debian, ubuntu...).
    local release release_id codename conf_file
    for release in "$@"; do
        release_id="${release%%/*}"
        codename="${release##*/}"
        conf_file="$apt_db/$release_id/conf/distributions"
        if ! grep -q "^Codename: $codename$" "$conf_file" 2>/dev/null; then
            mkdir -p "$(dirname "$conf_file")"
            printf '%s <-- %s\n' "$conf_file" "$release"
            cat >> "$conf_file" <<EOF
Codename: $codename
Suite: ${codename}${APT_SUITE_SUFFIX}
Architectures: $APT_ARCHITECTURES
Components: $APT_COMPONENTS
SignWith: $GPG_KEY_ID

EOF
        fi
    done

    # 2. Include every .changes (skipping internal build-deps packages) into the
    #    matching codename. reprepro copies the referenced files into pool/ and
    #    regenerates+signs dists/<codename>/{Release,InRelease,Release.gpg}.
    for release in "$@"; do
        release_id="${release%%/*}"
        codename="${release##*/}"
        log_subsection "include $RESULT_DIR/$release -> $PUBLIC_DIR/$release_id"

        local changes found=0
        while IFS= read -r changes; do
            found=1
            echo "+ $changes"
            reprepro --basedir "$apt_db/$release_id" \
                     --outdir "$pub_dir/$release_id" \
                     --ignore=wrongdistribution \
                     --ignore=surprisingbinary \
                     --verbose \
                     include "$codename" "$changes" \
                || die "reprepro include failed: $changes"
        done < <(find "$RESULT_DIR/$release/" -name '*.changes' -not -ipath '*build-deps*' | sort)

        [ "$found" -eq 1 ] || echo "WARNING: no .changes found under $RESULT_DIR/$release"
        reprepro --basedir "$apt_db/$release_id" list "$codename" || true
    done
}

# --- YUM repository (createrepo_c) ------------------------------------------

detect_createrepo() {
    if command -v createrepo_c >/dev/null 2>&1; then
        CREATEREPO_BIN=createrepo_c
    elif command -v createrepo >/dev/null 2>&1; then
        CREATEREPO_BIN=createrepo
    else
        die "no createrepo / createrepo_c binary found"
    fi
}

yum_repo() {
    log_section "Build YUM repositories with $CREATEREPO_BIN"
    echo "releases: $*"

    local release src arch repo_dir
    for release in "$@"; do
        # Split binary (noarch/x86_64) and source rpms into arch subtrees.
        mkdir -p "$PUBLIC_DIR/$release/x86_64" "$PUBLIC_DIR/$release/Source"

        find "$RESULT_DIR/$release" \( -name '*.noarch.rpm' -o -name '*.x86_64.rpm' \) -print0 \
            | xargs -0 --no-run-if-empty cp -fv --target-directory "$PUBLIC_DIR/$release/x86_64" \
            || die "cp of binary rpms failed: $release"

        find "$RESULT_DIR/$release" -name '*.src.rpm' -print0 \
            | xargs -0 --no-run-if-empty cp -fv --target-directory "$PUBLIC_DIR/$release/Source" \
            || die "cp of source rpms failed: $release"

        for arch in x86_64 Source; do
            repo_dir="$PUBLIC_DIR/$release/$arch"
            log_subsection "createrepo $repo_dir"
            "$CREATEREPO_BIN" --update --verbose --outputdir "$repo_dir" "$repo_dir" \
                || die "createrepo failed: $repo_dir"
            # Sign the repo metadata so yum/dnf can verify repo_gpgcheck.
            rm -f "$repo_dir/repodata/repomd.xml.asc"
            gpg --batch --no-tty --yes --detach-sign --armor -u "$GPG_KEY_ID" \
                "$repo_dir/repodata/repomd.xml" \
                || die "gpg sign of repomd.xml failed: $repo_dir"
        done
    done
}

# --- HTML: home page (install instructions) ---------------------------------

# Codenames of published apt repos, derived from the generated InRelease files.
apt_published_releases() {
    find "$PUBLIC_DIR" -type f -name InRelease 2>/dev/null \
        | awk -F/ '{print $(NF-3)"/"$(NF-1)}' | sort -u
}

# "<id>/<release>" of published yum repos, derived from repodata dirs.
yum_published_releases() {
    find "$PUBLIC_DIR" -type d -name repodata 2>/dev/null \
        | awk -F/ '{print $(NF-3)"/"$(NF-2)}' | sort -u
}

# Escape text for safe embedding in HTML, in both element and (double-quoted)
# attribute contexts. Covers & < > " '.
html_escape() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/\x27/\&#39;/g'; }

generate_home() {
    log_section "Generate home page (install instructions)"
    local out="$PUBLIC_DIR/index.html"

    local apt_releases yum_releases
    mapfile -t apt_releases < <(apt_published_releases)
    mapfile -t yum_releases < <(yum_published_releases)

    # Escape every externally-influenced value before embedding it in HTML.
    # Branch/tag names especially are attacker-influenceable and git permits
    # '<', '>' and '&' in ref names, so this prevents stored XSS on the public
    # download site. URLs used in attributes are additionally scheme-checked.
    local ppa_name_h ppa_slug_h ppa_url_h ref_h sha_h pipeline_h project_url_text project_url_attr
    ppa_name_h="$(printf '%s' "$PPA_NAME" | html_escape)"
    ppa_slug_h="$(printf '%s' "$PPA_SLUG" | html_escape)"
    ppa_url_h="$(printf '%s' "$PPA_URL" | html_escape)"
    ref_h="$(printf '%s' "$CI_COMMIT_REF_NAME" | html_escape)"
    sha_h="$(printf '%s' "$CI_COMMIT_SHA" | html_escape)"
    pipeline_h="$(printf '%s' "$CI_PIPELINE_ID" | html_escape)"
    project_url_text="$(printf '%s' "$CI_PROJECT_URL" | html_escape)"
    if [[ "$CI_PROJECT_URL" =~ ^https?:// ]]; then
        project_url_attr="$project_url_text"
    else
        project_url_attr="#"
    fi

    {
        cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PacketFence PPA: $ppa_name_h</title>
<style>
  body { font-family: Arial, sans-serif; margin: 2em auto; max-width: 1000px; color: #222; }
  h1 { border-bottom: 2px solid #0066cc; padding-bottom: .3em; }
  h2 { margin-top: 1.6em; color: #0066cc; }
  pre { background: #ececec; border: 1px dotted gray; padding: .6em; overflow-x: auto; }
  code { font-family: monospace; }
  ul.meta li { margin: .2em 0; }
  select { padding: .3em; margin: .4em 0; }
</style>
<script>
function pick(cls, value) {
  var els = document.getElementsByClassName(cls);
  for (var i = 0; i < els.length; i++) { els[i].textContent = value; }
}
function pickDeb(sel) { var v = sel.value.split('/'); pick('deb_id', v[0]); pick('deb_name', v[1]); }
function pickRpm(sel) { var v = sel.value.split('/'); pick('rpm_id', v[0]); pick('rpm_name', v[1]); }
</script>
</head>
<body>
<h1>PacketFence PPA: $ppa_name_h</h1>
<ul class="meta">
  <li>Project: <a href="$project_url_attr">$project_url_text</a></li>
  <li>Reference: $ref_h</li>
  <li>Commit: $sha_h</li>
  <li>Pipeline: $pipeline_h</li>
  <li>Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')</li>
</ul>

<h2>Content</h2>
<ul>
EOF
        # Top-level directory listing (excludes the generated index.html).
        ls -1p --group-directories-first "$PUBLIC_DIR" 2>/dev/null \
            | grep -v '^index.html$' \
            | while read -r entry; do
                local entry_h; entry_h="$(printf '%s' "$entry" | html_escape)"
                printf '  <li><a href="%s">%s</a></li>\n' "$entry_h" "$entry_h"
              done
        echo "</ul>"

        if [ "${#apt_releases[@]}" -gt 0 ]; then
            cat <<EOF
<h2>Debian / Ubuntu (APT)</h2>
<p>Import the signing key and add the repository:</p>
<pre><code>curl -fsSL $ppa_url_h/GPG_PUBLIC_KEY | sudo tee /etc/apt/trusted.gpg.d/gitlab-$ppa_slug_h.asc > /dev/null
sudo apt-get install -y apt-transport-https</code></pre>
<form>
  <select onchange="pickDeb(this);">
    <option value="RELEASE_ID/RELEASE_NAME">Choose your release…</option>
EOF
            for r in "${apt_releases[@]}"; do
                r_h="$(printf '%s' "$r" | html_escape)"
                printf '    <option value="%s">%s</option>\n' "$r_h" "$r_h"
            done
            cat <<EOF
  </select>
</form>
<pre><code>echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/gitlab-$ppa_slug_h.asc] $ppa_url_h/<span class="deb_id">RELEASE_ID</span> <span class="deb_name">RELEASE_NAME</span> main" \\
  | sudo tee /etc/apt/sources.list.d/gitlab-$ppa_slug_h.list
sudo apt-get update</code></pre>
EOF
        fi

        if [ "${#yum_releases[@]}" -gt 0 ]; then
            cat <<EOF
<h2>CentOS / RHEL (YUM/DNF)</h2>
<pre><code>sudo rpm --import $ppa_url_h/GPG_PUBLIC_KEY</code></pre>
<form>
  <select onchange="pickRpm(this);">
    <option value="RELEASE_ID/RELEASE_NAME">Choose your release…</option>
EOF
            for r in "${yum_releases[@]}"; do
                r_h="$(printf '%s' "$r" | html_escape)"
                printf '    <option value="%s">%s</option>\n' "$r_h" "$r_h"
            done
            cat <<EOF
  </select>
</form>
<pre><code>sudo tee /etc/yum.repos.d/gitlab-$ppa_slug_h.repo &lt;&lt;'REPO'
[$ppa_slug_h]
name=PacketFence $ppa_slug_h
baseurl=$ppa_url_h/<span class="rpm_id">RELEASE_ID</span>/<span class="rpm_name">RELEASE_NAME</span>/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$ppa_url_h/GPG_PUBLIC_KEY
REPO</code></pre>
EOF
        fi

        cat <<EOF
</body>
</html>
EOF
    } > "$out"

    echo "Generated: $out"
}

# --- HTML: per-directory listing pages --------------------------------------

generate_dir_index() {
    local dir="$1"
    local rel="${dir#"$PUBLIC_DIR"}"; rel="${rel#/}"
    local title; title="$(printf '%s' "$CI_PROJECT_NAME${rel:+/$rel}" | html_escape)"
    local out="$dir/index.html"

    {
        cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Index of $title</title>
<style>
  body { font-family: Arial, sans-serif; margin: 2em auto; max-width: 1000px; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: .3em .6em; text-align: left; border-bottom: 1px solid #eee; }
  th { background: #66cfff; }
  tr:nth-child(even) { background: #e6f7ff; }
  td.size, th.size { text-align: right; }
</style>
</head>
<body>
<h2>Index of $title</h2>
<hr>
<table>
<thead><tr><th>Name</th><th>Last modified</th><th class="size">Size</th></tr></thead>
<tbody>
<tr><td><a href="../">[Parent directory]</a></td><td></td><td class="size"></td></tr>
EOF
        # Directories first, then files; skip the index.html we are writing.
        ( cd "$dir" && ls -1p --group-directories-first ) | grep -v '^index.html$' \
            | while read -r name; do
                local href disp size mtime
                disp="$(printf '%s' "$name" | html_escape)"
                href="$disp"
                if [ -d "$dir/$name" ]; then
                    size="&nbsp;"
                else
                    size="$(du -h "$dir/$name" 2>/dev/null | cut -f1)"
                fi
                mtime="$(date -r "$dir/$name" '+%Y-%m-%d %H:%M' 2>/dev/null || echo '')"
                printf '<tr><td><a href="%s">%s</a></td><td>%s</td><td class="size">%s</td></tr>\n' \
                    "$href" "$disp" "$mtime" "$size"
              done
        cat <<EOF
</tbody>
</table>
</body>
</html>
EOF
    } > "$out"
}

generate_tree() {
    log_section "Generate directory listing pages"
    # Every subdirectory except the top-level (which gets the rich home page).
    find "$PUBLIC_DIR" -mindepth 1 -type d | sort | while read -r dir; do
        generate_dir_index "$dir"
    done
}

# --- main -------------------------------------------------------------------

log_section "Configure"
declare -p RESULT_DIR PUBLIC_DIR PPA_URL
[ -d "$RESULT_DIR" ] || die "RESULT_DIR not found: $RESULT_DIR"
mkdir -p "$PUBLIC_DIR"

configure_gpg
detect_createrepo
export_public_key

log_section "Discover releases under $RESULT_DIR"
APT_RELEASES=() YUM_RELEASES=() UNKNOWN_RELEASES=()
while IFS= read -r release; do
    [ -n "$release" ] || continue
    case "$release" in
        debian/*|ubuntu/*|mint/*)         APT_RELEASES+=("$release") ;;
        centos/*|fedora/*|rhel/*|rocky/*) YUM_RELEASES+=("$release") ;;
        *)                                UNKNOWN_RELEASES+=("$release") ;;
    esac
done < <(find_releases)

printf 'APT: %s\n' "${APT_RELEASES[*]:-(none)}"
printf 'YUM: %s\n' "${YUM_RELEASES[*]:-(none)}"
printf 'UNKNOWN: %s\n' "${UNKNOWN_RELEASES[*]:-(none)}"
(( ${#UNKNOWN_RELEASES[@]} == 0 )) || die "unknown release layout: ${UNKNOWN_RELEASES[*]}"

(( ${#APT_RELEASES[@]} > 0 )) && apt_repo "${APT_RELEASES[@]}"
(( ${#YUM_RELEASES[@]} > 0 )) && yum_repo "${YUM_RELEASES[@]}"

generate_home
generate_tree

log_section "Published tree"
show_tree -L 4 "$PUBLIC_DIR"
echo "=== PPA generation complete ==="
