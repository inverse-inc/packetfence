#!/bin/bash

# Usage
# call it from packetfence directory
# /bin/bash addons/dev-helpers/bin/switch_options.sh


SwitchPath="./lib/pf/Switch"

function extract_name() {
 echo $1 | sed -En "s|${SwitchPath}/||p" | sed 's/\//::/g' | sed 's/.pm//'
}

function get_name_from_module() {
 echo $1 | sed 's/::/--/'
}

declare -A DictNameInfo
declare -A DictNameFile
declare -A DictNameRelatives

Files=$(find $SwitchPath -name '*.pm')
for MyFile in $Files; do
  #
  # Get Name and link to File
  #
  Name=$(extract_name $MyFile)
  DictNameFile[${Name}]="${MyFile}"

  #
  # Get the current info
  #
  InfosFile=$(grep -A 100 -ri "pf::SwitchSupports qw" ${MyFile} | tail -n +2 | grep -B 100 -m 1 ");" | head -n -1 | sed -n -e 's/^.* //p')
  InfoFile=""
  while read -r line; do
    if [ -z ${InfoFile} ]; then
      InfoFile+="${line}"
    else
      InfoFile+=",${line}"
    fi
  done <<< "${InfosFile}"

  #
  # SNMP
  # We will use another way to get this point
  #
  SnmpFile=$(grep -li "getSecureMacAddresses" ${MyFile})
  if [[ ! -z ${SnmpFile} ]]; then
    if [[ ! -z ${InfoFile} ]]; then
      InfoFile+=",SNMP"
    else
      InfoFile+="SNMP"
    fi
  fi
  tag=0
  if [[ "$Name" != *"::"* && -z $InfoFile ]]; then
    TmpSnmpFile=$(grep -li "use base ('pf::Switch');" ${MyFile})
    if [[ ! -z ${TmpSnmpFile} ]]; then
      TmpSnmpFile=$(grep -li "use Net::SNMP;" ${MyFile})
      if [[ ! -z ${TmpSnmpFile} ]]; then
        InfoFile+="SNMP"
      else
        tag=1
      fi
    else
      tag=1
    fi
  fi

  if [[ $tag == "0" ]]; then
    DictNameInfo["${Name}"]="${InfoFile}"
  else
    echo "$Name will not be used"
  fi

  #
  # Relatives extraction
  #
  Relatives=$(grep -i "use base ('pf::Switch::" ${MyFile} | sed 's/.*::Switch:://' | sed s/\'.*//)
  if [[ ! -z ${Relatives} ]]; then
    RelativesTab=""
    #while read -r line; do
    while read -r TmpName; do
      #TmpName=$(get_name_from_module $line)
      if [ -z ${RelativesTab} ]; then
        RelativesTab+="$TmpName"
      else
        RelativesTab+=",$TmpName"
      fi
    done <<< "${Relatives}"
    DictNameRelatives["${Name}"]="${RelativesTab}"
  fi

  #Test
  if [[ $Name == "Accton::ES3526XA" ]]; then
    echo ">${Name}"
    echo ${DictNameInfo[$Name]}
    echo "f>${DictNameRelatives[$Name]}"
    echo "####"
  fi
  if [[ $Name == "Accton" ]]; then
    echo ">${Name}"
    echo ${DictNameInfo[$Name]}
    echo ${DictNameRelatives[$Name]}
    echo "####"
  fi
done

#
# Update infos from relatives
# Add relatives info
#
Names=( $( echo "${!DictNameInfo[@]}" | tr ' ' $'\n' | sort ) )

for Name in "${Names[@]}"; do
  # Search for relatives
  if [[ ! -z DictNameRelatives["${Name}"] ]]; then
    if [[ "${DictNameRelatives[${Name}]}" == *","* ]]; then
      IFS=',' read -r -a array <<< "$DictNameRelatives[${Name}]"
      for element in "${array[@]}"; do
        RelativeName=${DictNameRelatives[${element}]}
        if [[ ! -z ${RelativeName} ]]; then
	  DictNameInfo["${Name}"]=${DictNameInfo[${Name}]}",r,"${DictNameInfo[$RelativeName]}
	fi
      done
    else
      RelativeName=${DictNameRelatives[${Name}]}
      if [[ ! -z ${RelativeName} ]]; then
        DictNameInfo["${Name}"]=${DictNameInfo[${Name}]}",r,"${DictNameInfo[$RelativeName]}
      fi
    fi
  fi
  ParentName=$( echo "${Name}" | sed 's/--.*//')
  ParentHere=$( grep -li "use base ('pf::Switch::${ParentName}');" ${DictNameFile[${Name}]} )
  if [[ ! -z ${ParentHere} ]]; then
    DictNameInfo["${Name}"]=${DictNameInfo[${TmpName}]}",p,"${DictNameInfo[${Name}]}
  fi
  #if [[ $Name == "Accton::ES3526XA" ]]; then
  #  echo ">>${Name}"
  #  echo ${DictNameInfo[$Name]}
  #  echo "######"
  #fi
  #if [[ $Name == "Accton" ]]; then
  #  echo ">>${Name}"
  #  echo ${DictNameInfo[$Name]}
  #fi
done

ListWiredWireless=()
ListWired=()
LisWireless=()
LisVPN=()

#NamesClean=( $( echo "${!DictNameInfoClean[@]}" | tr ' ' $'\n' | sort ) )
NamesClean=( $( echo "${!DictNameInfo[@]}" | tr ' ' $'\n' | sort ) )

for k in ${NamesClean[@]}; do
  #if [[ ${DictNameInfoClean[$k]} == *"VPN"* ]]; then
  if [[ ${DictNameInfo[$k]} == *"VPN"* ]]; then
    ListVPN+=("$k")
  #elif [[ ${DictNameInfoClean[$k]} == *"Wired"* && ${DictNameInfoClean[$k]} == *"Wireless"* ]]; then
  elif [[ ${DictNameInfo[$k]} == *"Wired"* && ${DictNameInfo[$k]} == *"Wireless"* ]]; then
    ListWiredWireless+=("$k")
  #elif [[ ${DictNameInfoClean[$k]} == *"Wired"* ]]; then
  elif [[ ${DictNameInfo[$k]} == *"Wired"* ]]; then
    ListWired+=("$k")
  #elif [[ ${DictNameInfoClean[$k]} == *"Wireless"* ]]; then
  elif [[ ${DictNameInfo[$k]} == *"Wireless"* ]]; then
    ListWireless+=("$k")
  fi
done


echo "VPN"
for n in ${ListVPN[@]}; do
  echo ${n}
  #echo ${DictNameInfoClean[$n]}
  echo ${DictNameInfo[$n]}
  echo "---"
done

echo "####"
echo "Wired and Wireless"
for n in ${ListWiredWireless[@]}; do
  echo ${n}
  #echo ${DictNameInfoClean[$n]}
  echo ${DictNameInfo[$n]}
  echo "---"
done

echo "####"
echo "Wired"
for n in ${ListWired[@]}; do
  echo ${n}
  #echo ${DictNameInfoClean[$n]}
  echo ${DictNameInfo[$n]}
  echo "---"
done

echo "####"
echo "Wireless"
for n in ${ListWireless[@]}; do
  echo ${n}
  #echo ${DictNameInfoClean[$n]}
  echo ${DictNameInfo[$n]}
  echo "---"
done
