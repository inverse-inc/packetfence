#!/bin/sh
AG=$(which ag)
FILE=$0
YEAR=$(date +'%Y')
if [ -x "$AG" ];then
    ag  -l --null --ignore="class-wrapper.tt" --ignore "$(basename $FILE)" 'Copyright.* Inverse' | xargs -0 perl -pi -e"s/Copyright.*(20[0-9]{2}-)?20[0-9]{2}.*Inverse/Copyright (C) 2005-$YEAR Inverse/" 
else
    perl -pi -e"s/Copyright.*(20[0-9]{2}-)?20[0-9]{2}.*Inverse/Copyright (C) 2005-$YEAR Inverse/" $(grep --exclude="class-wrapper.tt" --exclude="$(basename $FILE)" -Prl 'Copyright.* Inverse' lib/ html/ addons/ sbin/ bin/ raddb/ t/ conf/ src/ docs/ debian/ )
fi;
