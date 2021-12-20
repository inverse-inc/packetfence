#!/bin/bash
PFDIR=/usr/local/pf/
export PERL5LIB=$PFDIR/lib_perl/lib/perl5 POLICY=Perl::Critic::Policy::Variables::ProhibitUnusedVariables

find $PFDIR/lib/{pf,pfconfig,captiveportal,pfappserver} -iname '*.pm' | xargs perlcritic -l --single-policy $POLICY | xargs -r perlcritic --verbose 5 --single-policy $POLICY

echo "Done"
