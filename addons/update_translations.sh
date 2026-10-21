#!/bin/bash

./addons/extract_i18n_strings.pl > html/pfappserver/lib/pfappserver/I18N/en.po.tmp 
./addons/extract_i18n_strings_portal.pl > conf/locale/en/LC_MESSAGES/packetfence.po.tmp
./addons/extract_i18n_strings_api.pl > conf/I18N/api/en.po.tmp
cat <<EOF

# diff between current po file and new po file
# tip: check all strings in current po file and absent from new po file

diff conf/locale/en/LC_MESSAGES/packetfence.po{,.tmp}
diff html/pfappserver/lib/pfappserver/I18N/en.po{,.tmp}
diff conf/I18N/api/en.po{,.tmp}

# If all is good then commit translations
#

mv conf/locale/en/LC_MESSAGES/packetfence.po{.tmp,}
mv html/pfappserver/lib/pfappserver/I18N/en.po{.tmp,}
mv conf/I18N/api/en.po{.tmp,}

commit -m"Update translations"
tx push -s
ls

EOF
