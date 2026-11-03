#!/bin/bash
#
# Extract the localizable strings of the admin UI extensions
# (html/pfappserver/root/extensions/README.md) to <extension>/i18n/en.po.tmp
#
# The extensions are the drop-ins of html/pfappserver/root/extensions/ and the
# absolute paths of PF_UI_EXTENSIONS (':' separated), like the UI build.
# Run from the root of the repository.
#
set -o nounset -o pipefail -o errexit

dropin=html/pfappserver/root/extensions
extensions=()
if [ -d "$dropin" ]; then
    for dir in "$dropin"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        case "$name" in .*|_*) continue ;; esac
        extensions+=("${dir%/}")
    done
fi
IFS=':' read -r -a from_env <<< "${PF_UI_EXTENSIONS:-}"
for dir in "${from_env[@]}"; do
    [ -n "$dir" ] && extensions+=("${dir%/}")
done

if [ ${#extensions[@]} -eq 0 ]; then
    echo "No UI extension found in $dropin or PF_UI_EXTENSIONS" >&2
    exit 0
fi

for dir in "${extensions[@]}"; do
    mkdir -p "$dir/i18n"
    ./addons/extract_i18n_strings_api.pl --src "$dir" --po "$dir/i18n/en.po" > "$dir/i18n/en.po.tmp"
    cat <<EOT

# $dir: review the strings, then commit them in the extension repository and push them to Transifex
diff $dir/i18n/en.po{,.tmp}
mv $dir/i18n/en.po{.tmp,}
(cd $dir && tx push -s)
EOT
done
