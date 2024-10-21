#!/bin/bash
set -o nounset -o pipefail -o errexit

# Fix PF version if maintenance to match tag
if [[ "$PF_VERSION" =~ ^maintenance\/([0-9]+\.[0-9]+)$ ]];
then
  PF_VERSION=v;
  PF_VERSION+=${BASH_REMATCH[1]};
  PF_VERSION+=.0;
  echo "Maintenance Branch detected, try to match tag version with PF version = $PF_VERSION"
elif [[ "$PF_VERSION" =~ ^.*\/.*$ ]];
then
  PF_VERSION="`echo $PF_VERSION | sed -r 's/\//-/g'`"
fi

VM_NAME=${VM_NAME:-vm}

VBOX_RESULT_DIR=${VBOX_RESULT_DIR:-results/virtualbox}
VBOX_OVA_NAME=${VM_NAME}.ova
VBOX_OVF_NAME=${VM_NAME}.ovf

VMWARE_RESULT_DIR=${VMWARE_RESULT_DIR:-results/vmware}
VMX_OVA_NAME=${VM_NAME}-${PF_VERSION}.ova
VMX_OVA_NAME=`echo -n $VMX_OVA_NAME | tr '/' '-'`

VMX_ZIP_NAME=${VM_NAME}-${PF_VERSION}.zip
VMX_ZIP_NAME=`echo -n $VMX_ZIP_NAME | tr '/' '-'`

# upload
SF_RESULT_DIR=results/sf/${PF_VERSION}

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
    local ova_file="${VMWARE_RESULT_DIR}/${VMX_OVA_NAME}"
    local zip_file="${SF_RESULT_DIR}/${VMX_ZIP_NAME}"

    echo "zip source ${ova_file} =>  dest: ${zip_file}"

    zip -j ${zip_file} ${ova_file}
}

upload_to_linode() {
    echo "Create directory packetfence-zen/${PF_VERSION}/"
    rclone mkdir --s3-provider="Ceph"  --s3-access-key-id=${RCLONE_ACCESS_KEY_ID}  --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY}  --s3-endpoint="${RCLONE_LINODE_URL}"  --s3-acl=public-read :s3:packetfence-zen/${PF_VERSION}/
    echo "rclone ${VMX_ZIP_NAME} to packetfence-zen/${PF_VERSION}/"
    rclone copyto  --s3-provider="Ceph"  --s3-access-key-id=${RCLONE_ACCESS_KEY_ID}  --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY}  --s3-endpoint="${RCLONE_LINODE_URL}"  --s3-acl=public-read  ${SF_RESULT_DIR}/${VMX_ZIP_NAME} :s3:packetfence-zen/${PF_VERSION}/${VMX_ZIP_NAME}
    echo "Add md5sum of ${VMX_ZIP_NAME} in ${VMX_ZIP_NAME}.md5sums.txt"
    echo "`md5sum ${SF_RESULT_DIR}/${VMX_ZIP_NAME} | cut -d ' ' -f 1` ${VMX_ZIP_NAME}" | tee -a ${SF_RESULT_DIR}/${VMX_ZIP_NAME}.md5sums.txt
    rclone copyto  --s3-provider="Ceph"  --s3-access-key-id=${RCLONE_ACCESS_KEY_ID}  --s3-secret-access-key=${RCLONE_SECRET_ACCESS_KEY}  --s3-endpoint="${RCLONE_LINODE_URL}"  --s3-acl=public-read  ${SF_RESULT_DIR}/${VMX_ZIP_NAME}.md5sums.txt :s3:packetfence-zen/${PF_VERSION}/${VMX_ZIP_NAME}.md5sums.txt
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
compress_vmware_ova

echo "===> Upload to Linode"
upload_to_linode
