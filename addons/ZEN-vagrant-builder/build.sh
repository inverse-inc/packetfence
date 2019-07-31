#!/bin/bash

rm -f \
        work/box.ovf \
        work/*.vmdk \
        work/box.ova \
        work/package.box \
        work/vagrant_private_key \
        work/Vagrantfile

rm -f *.ova
rm -f *.zip

vagrant destroy -f

if ! vagrant up; then
       echo "Failed to build VM. Exiting"
       exit 1
fi

vagrant halt

VBoxManage modifyvm PacketFence-ZEN --memory 8096

VBoxManage modifyvm PacketFence-ZEN --uartmode1 disconnected

vagrant package

mkdir -p work
mv package.box work/
cd work/
tar -xvf package.box

../fix_ovf_alt box.ovf
\mv vmx_box.ovf box.ovf

#yes | cp ../box-release.ovf box.ovf

ovftool --lax box.ovf box.ova

mv box.ova ../PacketFence-ZEN.ova

