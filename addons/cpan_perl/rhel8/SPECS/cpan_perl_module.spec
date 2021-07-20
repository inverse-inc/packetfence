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

# ===== RHEL8 =====
yum install -y openssl-devel
yum install -y krb5-libs
yum install -y mariadb-devel
dnf install -y epel-release
yum install -y libssh2-devel
yum install -y systemd-devel
yum install -y gd-devel
yum install -y perl-open.noarch
yum install -y perl-experimental
dnf group install -y "Development Tools"
dnf install http://repo.okay.com.mx/centos/8/x86_64/release/okay-release-1-1.noarch.rpm
dnf install -y perl-Devel-Peek

# ===== DEBIAN11 =====
apt update
apt install zip make build-essential libssl-dev zlib1g-dev libmariadb-dev-compat libmariadb-dev libssh2-1-dev libexpat1-dev pkg-config libkrb5-dev libsystemd-dev libgd-dev libcpan-distnameinfo-perl libyaml-perl curl wget -y

cpan install CPAN

#
# Extract a simple name from perl
#  Replace :: by _ in perl name dependencies
#
function clean_perl_name(){
  myVar=`sed -r 's/[:+\/]/_/g' <<< $1`
  echo ${myVar}
}

#
# Try to install with cpan
#  Return Done or failed according to cpan exit code
#
function install_module(){
  ModName=$1
  ModInstall=$2
  ModTest=$3
  ModNameClean=$4
  ModInstallRep=$5
  date > ${InstallPath}/${NameCleaned}.txt
  if [[ "${ModTest}" == "True" ]]; then
    cpan install ${ModInstall} &>> ${InstallPath}/${ModNameClean}.txt
  else
    echo "No test"
    perl -MCPAN -e "CPAN::Shell->notest('install', '${ModInstall}')"  &>> ${InstallPath}/${ModNameClean}.txt
  fi
  tail -n 1 ${InstallPath}/${ModNameClean}.txt | grep --line-buffered "install  -- OK"
  ModInstallStatus=$?

  #echo "ModInstallStatus $ModInstallStatus"
  #echo "ModInstallRep $ModInstallRep"
  if [[ "$ModInstallStatus" != "0" && "$ModInstallRep" -lt "2" ]]; then
    #echo "Num of rep = $ModInstallRep"
    ((ModInstallRep=ModInstallRep+1))
    install_module ${ModName} ${ModInstall} ${ModTest} ${ModNameClean} ${ModInstallRep}
  fi
  if [[ "$ModInstallStatus" == "0"  ]]; then
    echo "Done"
  else
    echo "Failed ${ModName}. Please check  ${InstallPath}/${ModNameClean}.txt"
    tail -n 10 ${InstallPath}/${ModNameClean}.txt
  fi
}

#
# Read from csv file
#  Read and extract info from csv file
#
ListCsvModInstall=()
ListCsvModName=()
ListCsvModTest=()

OLDIFS=$IFS
IFS=','
while read cpanName cpanVersion cpanInstall cpanTest cpanAll
do
  ListCsvModInstall+=( $cpanInstall )
  ListCsvModName+=( $cpanName )
  if [[ $cpanTest != "True" && $cpanTest != "False" ]]; then
     echo "$cpanTest for $cpanName is not valide, it will be equal to true"
     cpanTest="True"
  fi
  ListCsvModTest+=( $cpanTest )
done < $CsvFile
IFS=$OLDIFS

#
# Start to add cpan modules
#  Add a log file and a dependencies if perl_dependencies.pl is here
#
InstallPath=/root/install_perl
Bool=true
mkdir -p ${InstallPath}
date > ${InstallPath}/date.log
for i in ${!ListCsvModInstall[@]}
do
  echo "Start ${ListCsvModInstall[$i]}"
  install_module ${ListCsvModName[$i]} ${ListCsvModInstall[$i]} ${ListCsvModTest[$i]} $(clean_perl_name ${ListCsvModName[$i]}) 0
done
date >> ${InstallPath}/date.log
