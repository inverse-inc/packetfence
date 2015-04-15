#!/bin/sh

FILE=$0

perl -pi -e's/Copyright.*(20(0[0-9]|1[0-4])-)?20(0[0-9]|1[0-4]).*Inverse/Copyright (C) 2005-2015 Inverse/' $(grep --exclude="$FILE" -Prl 'Copyright.*(20(0[0-9]|1[0-4])-)?20(0[0-9]|1[0-4]).*Inverse' lib/ html/ addons/ sbin/ bin/ raddb/ ) 
