#!/bin/bash

# ===== USAGE =====
# Usage: $ create_csv-dep_file.sh dependencies.csv
#  get the filename
CsvFile=$1
if [[ ! -f $CsvFile || "$CsvFile" == "" ]]; then
  echo "The CSV File $CsvFile has not been found"
  echo "Usage: $ create_csv-dep_file.sh dependencies.csv"
  exit 99
fi

# ===== PREPARE ENV =====
mkdir -p /usr/local/pf/lib/perl_modules/lib/perl5/
export PERL5LIB=/root/perl5/lib/perl5:/usr/local/pf/lib/perl_modules/lib/perl5/
export PKG_CONFIG_PATH=/usr/lib/pkgconfig/
TestPerlConfig=$(perl -e exit)
if [[ "$TestPerlConfig" != "" ]]; then
  export LC_CTYPE=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
fi

# ===== INSTALL PERL DEP =====
# Test to install perl dependencies
#
array=( 'Archive::Zip' )
array+=( 'Capture::Tiny' )
array+=( 'Devel::CheckOS' )
array+=( 'Env::Path' )
array+=( 'File::Path' )
array+=( 'File::Type' )
array+=( 'Parse::CPAN::Packages' )
array+=( 'Test::Differences' )
array+=( 'Test::Time' )
array+=( 'Text::Diff' )
array+=( 'Archive::Peek' )
array+=( 'CPAN::DistnameInfo' )
array+=( 'File::Slurp' )
array+=( 'PPI' )
array+=( 'Test::InDistDir' )
array+=( 'Archive::Zip' )
array+=( 'Moose' )
array+=( 'MooseX::Types::Path::Class' )
array+=( 'Test::Fatal' )
array+=( 'CPAN::Meta::Check' )
array+=( 'Class::Load' )
array+=( 'Class::Load::XS' )
array+=( 'Devel::GlobalDestruction' )
array+=( 'Devel::OverloadInfo' )
array+=( 'Devel::StackTrace' )
array+=( 'Dist::CheckConflicts' )
array+=( 'Eval::Closure' )
array+=( 'List::Util' )
array+=( 'Module::Runtime::Conflicts' )
array+=( 'Package::DeprecationManager' )
array+=( 'Test::CleanNamespaces' )
array+=( 'Test::Fatal' )
array+=( 'Test::Requires' )
array+=( 'Test::Deep' )
array+=( 'Test::Fatal' )
array+=( 'Test::Needs' )
array+=( 'Class::Load' )
array+=( 'Test::Fatal' )
array+=( 'Test::Needs' )
array+=( 'Carp::Clan' )
array+=( 'Module::Build::Tiny' )
array+=( 'Moose' )
array+=( 'Moose::Exporter' )
array+=( 'Moose::Meta::TypeConstraint::Union' )
array+=( 'Moose::Role' )
array+=( 'Moose::Util::TypeConstraints' )
array+=( 'Sub::Exporter::ForMethods' )
array+=( 'Test::Fatal' )
array+=( 'Test::Requires' )
array+=( 'namespace::autoclean' )
array+=( 'namespace::autoclean' )
array+=( 'Test::Needs' )
array+=( 'Class::Inspector' )
array+=( 'IO::String' )
array+=( 'Task::Weaken' )
array+=( 'Test::Deep' )
array+=( 'Test::NoWarnings' )
array+=( 'Test::Object' )
array+=( 'Test::SubCalls' )
array+=( 'Hook::LexWrap' )
array+=( 'Capture::Tiny' )
array+=( 'Text::Diff' )
array+=( 'CPAN::FindDependencies' )

bo=0
for i in "${array[@]}"
do
  perl -MCPAN -e "CPAN::Shell->notest('install', '${i}')"
  if [ $? -eq 0 ]; then
    echo "Done ${i}"
  else
    echo "Failed ${i}"
    bo=1
  fi
done

if [[ "$bo" == "1" ]]; then
  echo "Install perl dependency CPAN::FindDependencies failed. At least, one module was not able to be installed."
  exit 1
fi

#
# Test if perl script is here
#
FindDependenciesFile=find_dependencies.pl
Bool=true
if [ ! -f "${FindDependenciesFile}" ]; then
  echo "Perl file ${FindDependenciesFile} has not been found"
  exit 1
fi

#
# Function
#   Recreate modules dependencies from dependencies.txt
#
function reload_dependencies_from_csv(){
declare -A DicNameNum
declare -A DicNameVersion
declare -A DicNamePath

while IFS=$'\n' read line
do
  if [[ $line =~ "WARNING"  ]]; then
    NumSpace=$(echo "$line" | sed '1s/[^ \t]//g' |wc -c)
    AllVals=$(echo "$line" | sed 's/.*FindDependencies: \(.*\): no.*/\1/')
    ModPath=$(echo "$AllVals" | sed 's/.* (\(.*\))/\1/')
    ModName=$(echo "$AllVals" | sed 's/.*\/\(.*\)-[0-9].*/\1/')
    ModName=$(echo "$ModName" | sed 's/-/::/g')
    ModVersion=$(echo "$AllVals" | sed 's/.*-\([0-9].*$\)/\1/')
  elif ! [[  $line =~ *"/perl-[0-9]"* && $line =~ *"no_index"* ]]; then
    NumSpace=$(echo "$line" | sed '1s/[^ \t]//g' |wc -c)
    AllVals=$(echo "$line" | sed 's/^ *\(.*\)/\1/')
    ModPath=$(echo "$AllVals" | sed 's/.* (\(.*\))/\1/')
    ModName=$(echo "$AllVals" | sed 's/\(.*\) .*/\1/')
    ModVersion=$(echo "$AllVals" | sed 's/.* (.\/..\/\(.*\))/\1/')
  fi
  if [ ${NumSpace} == "" ]; then
    ${NumSpace}=0
  fi
  if [ -v DicNameNum["${ModName}"] ];then
    if [[ ${DicNameNum[${ModName}]} -lt "${NumSpace}" ]]; then
      DicNameNum["${ModName}"]=${NumSpace}
      DicNameVersion["${ModName}"]=${ModVersion}
      DicNamePath["${ModName}"]=${ModPath}
    fi
  else
    DicNameNum["${ModName}"]=${NumSpace}
    DicNameVersion["${ModName}"]=${ModVersion}
    DicNamePath["${ModName}"]=${ModPath}
  fi
done < $1

ListNum=( $(echo ${DicNameNum[@]} | tr ' ' $'\n' | sort  -run ) )

declare -a ListNewMod=()
for v in ${ListNum[@]}; do
  for k in ${!DicNameNum[@]}; do
    if [[ "${DicNameNum[$k]}" == "$v" ]] ; then
      ListNewMod+=($k)
    fi
  done
done

create_new_dep_file
}

#
# Function to create the new dependencies file
#
function create_new_dep_file(){

NewDepFile=dependencies-$(date '+%Y%m%d%H%M%S').csv
declare -a ListDiff=()
d=0

for i in "${ListNewMod[@]}"; do
  for v in "${ListCsvModName[@]}"; do
    if [ $i == $v ]; then
      Version=$(echo "${DicNameVersion[${i}]}" | sed 's/.*-\(.*\)\.tar.gz.*/\1/')
      echo "$i,${Version},${DicNameVersion[${i}]},${DicNamePath[${i}]},${DicNameNum[$i]}" >>$NewDepFile
      ((d=d+1))
      ListDiff+=($i)
      break
    fi
  done
done

echo "The following modules are in the imported csv dependencies files BUT not the new dependencies file"
# need to be removed
for u in "${ListCsvModName[@]}"; do
  boo=0
  for p in "${ListDiff[@]}"; do
    if [ $u == $p ]; then
      boo=1
    fi
  done
  if [ $boo == 0 ]; then
    echo $u
  fi
done

echo "The new dependencies file has been created with $d entries in $NewDepFile"
}

#
# Read from csv file
#  Read and extract info from csv file
#
ListCsvModInstall=()
ListCsvModName=()
CsvFile=$1
OLDIFS=$IFS
IFS=','
[ ! -f $CsvFile ] && { echo "CsvFile file not found"; exit 99; }

while read cpanName cpanVersion cpanInstall cpanAll
do
  ListCsvModInstall+=( $cpanInstall )
  ListCsvModName+=( $cpanName )
done < $CsvFile
IFS=$OLDIFS

#
# Start to add cpan modules
#  Add a log file and a dependencies if perl_dependencies.pl is here
#
FindDependenciesFile=find_dependencies.pl
Bool=true
if [ ! -f "${FindDependenciesFile}" ]; then
  echo "Perl file ${FindDependenciesFile} has not been found"
  exit 1
fi

DependenciesFile=dependencies.tmp.txt
date > ${DependenciesFile}

for i in ${!ListCsvModInstall[@]}
do
  echo "Start search dependencies on ${ListCsvModInstall[$i]}"
  #perl ${FindDependenciesFile} "${ListCsvModName[$i]}" &>> ${DependenciesFile}
  perl ${FindDependenciesFile} "${ListCsvModInstall[$i]}" &>> ${DependenciesFile}
done

if [ -f "${DependenciesFile}" ]; then
  reload_dependencies_from_csv ${DependenciesFile}
else
  echo "The file ${DependenciesFile} has not been found."
fi
