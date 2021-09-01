#!/bin/bash
set -o nounset -o pipefail -o errexit

VM_NAME=${VM_NAME:-vm}

VBOX_RESULT_DIR=${VBOX_RESULT_DIR:-results/virtualbox}
VBOX_OVA_NAME=${VM_NAME}.ova
VBOX_OVF_NAME=${VM_NAME}.ovf

VMWARE_RESULT_DIR=${VMWARE_RESULT_DIR:-results/vmware}
VMX_OVA_NAME=${VM_NAME}-${PF_VERSION}.ova
VMX_OVA_NAME=`echo -n $VMX_OVA_NAME | tr '/' '-'`

# upload
SF_RESULT_DIR=results/sf/${PF_VERSION}
PUBLIC_REPO_DIR="/home/frs/project/p/pa/packetfence/PacketFence\ ZEN/${PF_VERSION}"
DEPLOY_SF_USER=${DEPLOY_SF_USER:-inverse-bot,packetfence}
DEPLOY_SF_HOST=${DEPLOY_SF_HOST:-frs.sourceforge.net}

declare -p VM_NAME
declare -p VBOX_RESULT_DIR VBOX_OVA_NAME VBOX_OVF_NAME
declare -p VMWARE_RESULT_DIR VMX_OVA_NAME

generate_manifest() {
    local vmx_dir=${1}
    ( cd ${vmx_dir} ;
      sha1sum --tag ${VBOX_OVF_NAME} ${VM_NAME}-disk001.vmdk > ${VM_NAME}.mf
      )
}

compress_vmware_ova() {
    local ova_file=${1}
    
    # replace .ova by .zip
    local zip_file=$(basename ${ova_file/.ova/.zip})
    
    zip -j ${SF_RESULT_DIR}/${zip_file} ${ova_file}
}

upload_to_sf() {
    # warning: slashs at end of dirs are significant for rsync
    local src_dir="${SF_RESULT_DIR}/"
    local dst_repo="${PUBLIC_REPO_DIR}/"
    local dst_dir="/root/"
    declare -p src_dir dst_dir
    echo "rsync: $src_dir -> $dst_dir"

    # quotes to handle space in filename
    rsync -avz $src_dir "$dst_dir"
}

mkdir -p ${VMWARE_RESULT_DIR} ${SF_RESULT_DIR}

echo "===> Extract Virtualbox OVA to ${VMWARE_RESULT_DIR}"
tar xvf ${VBOX_RESULT_DIR}/${VBOX_OVA_NAME} -C ${VMWARE_RESULT_DIR}

echo "===> Convert OVF in-place for VMware"
sed -i 's/<OperatingSystemSection ovf:id="80">/<OperatingSystemSection ovf:id="101">/' ${VMWARE_RESULT_DIR}/${VBOX_OVF_NAME}
sed -i 's/<vssd:VirtualSystemType>virtualbox-2.2/<vssd:VirtualSystemType>vmx-07/' ${VMWARE_RESULT_DIR}/${VBOX_OVF_NAME}

# Manifest need to be generate by hand because we modify OVF during last step
echo "===> Generate a manifest"
generate_manifest ${VMWARE_RESULT_DIR}

echo "===> Generate OVA for VMware"
ovftool --shaAlgorithm=SHA1 --lax ${VMWARE_RESULT_DIR}/${VBOX_OVF_NAME} ${VMWARE_RESULT_DIR}/${VMX_OVA_NAME}

echo "===> Compress VMware OVA"
compress_vmware_ova ${VMWARE_RESULT_DIR}/${VMX_OVA_NAME}

echo "===> Upload to Sourceforge"
upload_to_sf
