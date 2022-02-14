#!/bin/bash
set -o nounset -o pipefail -o errexit

# ===== USAGE =====
# Usage: $ install_cpan.sh dependencies.csv
#  get the filename
CsvFile=$1
if [[ ! -f $CsvFile || "$CsvFile" == "" ]]; then
  echo "The CSV File $CsvFile has not been found"
  echo "Usage: $ install_cpan.sh dependencies.csv"
  exit 99
fi

# ===== FUNCTIONS =====
configure_and_check() {
    ### Variables
    # dir of current script
    SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))
    BASE_DIR=/usr/local/pf/lib/perl_modules
    DUMP_FILE=${BASE_DIR}/modules_installed.csv
    DISABLE_REPO="--disablerepo=packetfence"

    CPAN_BIN_PATH="/usr/bin/cpan"
    CPAN_VERSION=2.29

    MODULES_WITHOUT_VERSION="Net::Radius LWP::UserAgent Module::Loaded"

    prepare_env
    install_requirements

}

prepare_env() {
    # ===== PREPARE ENV =====
    mkdir -p ${BASE_DIR}/lib/perl5/
    # to find already downloaded Perl modules
    export PERL5LIB=/root/perl5/lib/perl5:${BASE_DIR}/lib/perl5/
    export PKG_CONFIG_PATH=/usr/lib/pkgconfig/
    TestPerlConfig=$(perl -e exit)
    if [[ "$TestPerlConfig" != "" ]]; then
        export LC_CTYPE=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
    fi
}

install_requirements() {
    if [ -f /etc/debian_version ]; then
        echo "Debian system detected"
        apt update
        apt install libmodule-signature-perl zip make build-essential libssl-dev zlib1g-dev libmariadb-dev-compat libmariadb-dev libssh2-1-dev libexpat1-dev pkg-config libkrb5-dev libsystemd-dev libgd-dev libcpan-distnameinfo-perl libyaml-perl curl wget graphviz libio-socket-ssl-perl libnet-ssleay-perl libcpan-perl-releases-perl -y
    elif [ -f /etc/redhat-release ]; then
        echo "EL system detected"
        yum install -y openssl-devel krb5-libs MariaDB-devel epel-release libssh2-devel systemd-devel gd-devel perl-open perl-Test perl-experimental perl-CPAN perl-IO-Socket-SSL perl-Net-SSLeay perl-Devel-Peek perl-CPAN-DistnameInfo $DISABLE_REPO
        yum group install -y "Development Tools" $DISABLE_REPO
        yum install -y http://repo.okay.com.mx/centos/8/x86_64/release/okay-release-1-5.el8.noarch.rpm
    else
        echo "Unknown system, exit"
        exit 0
    fi
}

upgrade_cpan() {
    echo "CPAN installation"
    # 1. configure CPAN with defaults (answer yes)
    # 2. override default conf to UNINST cpan after upgrade (seems mandatory for EL8)
    (echo o conf make_install_arg 'UNINST=1'; echo o conf commit)|PERL_MM_USE_DEFAULT=1 ${CPAN_BIN_PATH} &> /dev/null

    # upgrade CPAN
    ${CPAN_BIN_PATH} -i ANDK/CPAN-${CPAN_VERSION}.tar.gz &> /dev/null

    # display CPAN version
    ${CPAN_BIN_PATH} -D CPAN
    echo "CPAN installed at ${CPAN_VERSION}"
}

# generate MyConfig.pm for packetfence-perl
generate_pfperl_cpan_config() {
    # install modules in a specific directory
    (echo o conf makepl_arg "INSTALL_BASE=${BASE_DIR}"; echo o conf commit)|${CPAN_BIN_PATH} &> /dev/null
    # hard-coded due to quotes
    (echo o conf mbuildpl_arg '"--install_base /usr/local/pf/lib/perl_modules"' ; echo o conf commit)|${CPAN_BIN_PATH} &> /dev/null

    # allow to installed outdated dists
    (echo o conf allow_installing_outdated_dists 'yes'; echo o conf commit)|${CPAN_BIN_PATH} &> /dev/null

    # allow to downgrade installed modules automatically
    # assertion at end of script will check everything is expected
    (echo o conf allow_installing_module_downgrades 'yes'; echo o conf commit)|${CPAN_BIN_PATH} &> /dev/null

    # use cpan.metacpan.org to get outdated modules
    # disable pushy_https
    (echo o conf urllist 'https://cpan.metacpan.org'; echo o conf commit)|${CPAN_BIN_PATH} &> /dev/null
    (echo o conf pushy_https '0'; echo o conf commit)|${CPAN_BIN_PATH} &> /dev/null

    echo "packetfence-perl CPAN config generated"
}

# generate a CSV file which module name,module version
dump_modules_installed() {
    perl $SCRIPT_DIR/get_modules_installed.pl > ${DUMP_FILE}
}

check_module_installed_in_dump() {
    local mod_name=$1
    local mod_version=${mod_version:-$2}

    if [ -n "${mod_version}" ]; then
        grep "$mod_name,$mod_version" ${DUMP_FILE}
    else
        grep "$mod_name" ${DUMP_FILE}
    fi
}

# https://stackoverflow.com/a/8063398
contains() {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && exit 0 || exit 1
}
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
  date > ${InstallPath}/${ModNameClean}.txt
  if [[ "${ModTest}" == "True" ]]; then
    ${CPAN_BIN_PATH} install ${ModInstall} &>> ${InstallPath}/${ModNameClean}.txt
  else
    echo "No test"
    perl -MCPAN -e "CPAN::Shell->notest('install', '${ModInstall}')"  &>> ${InstallPath}/${ModNameClean}.txt
  fi
  # UNINST=1 is not always present in .txt, we could have: "./Build install  -- OK"
  tail -n 1 ${InstallPath}/${ModNameClean}.txt | grep --line-buffered "install \(UNINST=1\)\? -- OK"
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

# ===== MAIN =====

configure_and_check
upgrade_cpan
generate_pfperl_cpan_config
#
# Read from csv file
#  Read and extract info from csv file
#
ListCsvModName=()
ListCsvModVersion=()
ListCsvModInstall=()
ListCsvModTest=()

OLDIFS=$IFS
IFS=','
while read cpanName cpanVersion cpanInstall cpanTest cpanAll
do
  ListCsvModName+=( $cpanName )
  ListCsvModVersion+=( $cpanVersion )
  ListCsvModInstall+=( $cpanInstall )
  if [[ $cpanTest != "True" && $cpanTest != "False" ]]; then
     echo "$cpanTest for $cpanName is not valid, it will be equal to true"
     cpanTest="True"
  fi
  ListCsvModTest+=( $cpanTest )
done < $CsvFile
IFS=$OLDIFS

#
# Start to add cpan modules
#  Add a log file and a dependencie if perl_dependencies.pl is here
#
InstallPath=/root/install_perl
Bool=true
NumberOfDeps=$(wc -l $CsvFile | cut -f1 -d' ')
mkdir -p ${InstallPath}
date > ${InstallPath}/date.log
for i in ${!ListCsvModInstall[@]}
do
  echo "Remaining lines to parse in ${CsvFile}: ${NumberOfDeps}"
  echo "Start ${ListCsvModInstall[$i]}"
  install_module ${ListCsvModName[$i]} ${ListCsvModInstall[$i]} ${ListCsvModTest[$i]} $(clean_perl_name ${ListCsvModName[$i]}) 0
  NumberOfDeps=$((NumberOfDeps-1))
done
date >> ${InstallPath}/date.log

dump_modules_installed

#
# Assertions
# Parse all modules in source CSV file and assert they are installed at correct version
# based on dump

install_status=0
for i in ${!ListCsvModInstall[@]}
do
    if ! check_module_installed_in_dump ${ListCsvModName[$i]} ${ListCsvModVersion[$i]}; then
        echo "${ListCsvModName[$i]} ${ListCsvModVersion[$i]} not found installed in ${DUMP_FILE}"
        if contains ${MODULES_WITHOUT_VERSION} ${ListCsvModName[$i]}; then
            echo "${ListCsvModName[$i]} doesn't have version returned by 'dump_modules_installed', checking without version"

            # we check in dump without version
            if ! check_module_installed_in_dump ${ListCsvModName[$i]}; then
                echo "${ListCsvModName[$i]} not found installed in ${DUMP_FILE}"
                install_status=1
            else
                echo "${ListCsvModName[$i]} found installed in ${DUMP_FILE}"
            fi
        else
            install_status=1
        fi
    fi
done

if [ "$install_status" -eq 0 ]; then
    echo "All good, ready to package packetfence-perl"
    exit 0
else
    echo "Some modules are not installed correctly"
    exit 1
fi
