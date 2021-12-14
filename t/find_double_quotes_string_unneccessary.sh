#!/bin/bash
PFDIR=/usr/local/pf/
export PERL5LIB=$PFDIR/lib_perl/lib/perl5 POLICY=Perl::Critic::Policy::ValuesAndExpressions::ProhibitInterpolationOfLiterals

find $PFDIR/lib/{pf,pfconfig,captiveportal,pfappserver} -iname '*.pm' | xargs perlcritic -l --single-policy $POLICY | xargs perlcritic --single-policy $POLICY
