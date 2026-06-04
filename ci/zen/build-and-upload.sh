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

QEMU_RESULT_DIR=${QEMU_RESULT_DIR:-results/qemu}
VMWARE_RESULT_DIR=${VMWARE_RESULT_DIR:-results/vmware}
VMX_OVA_NAME=${VM_NAME}-${PF_VERSION}.ova
VMX_OVA_NAME=`echo -n $VMX_OVA_NAME | tr '/' '-'`

VMX_ZIP_NAME=${VM_NAME}-${PF_VERSION}.zip
VMX_ZIP_NAME=`echo -n $VMX_ZIP_NAME | tr '/' '-'`

# upload
SF_RESULT_DIR=results/sf/${PF_VERSION}

declare -p VM_NAME
declare -p QEMU_RESULT_DIR
declare -p VMWARE_RESULT_DIR VMX_OVA_NAME

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

echo "===> Convert qcow2 to streamOptimized VMDK"
qemu-img convert -f qcow2 -O vmdk -o subformat=streamOptimized \
  "${QEMU_RESULT_DIR}/${VM_NAME}.qcow2" \
  "${VMWARE_RESULT_DIR}/${VM_NAME}-disk001.vmdk"

echo "===> Render VMX template"
sed -e "s/%%VM_NAME%%/${VM_NAME}/g" \
    "$(dirname "$0")/templates/packetfence-zen.vmx.tmpl" \
    > "${VMWARE_RESULT_DIR}/${VM_NAME}.vmx"

echo "===> Generate OVA for VMware via ovftool"
ovftool --shaAlgorithm=SHA1 --lax "${VMWARE_RESULT_DIR}/${VM_NAME}.vmx" "${VMWARE_RESULT_DIR}/${VMX_OVA_NAME}"

echo "===> Compress VMware OVA"
compress_vmware_ova

if [[ -n "${RCLONE_ACCESS_KEY_ID:-}" ]]; then
    echo "===> Upload to Linode"
    upload_to_linode
else
    echo "===> Skipping Linode upload (RCLONE_ACCESS_KEY_ID unset)"
fi
