SHELL = /bin/sh

buildpkg: buildpkg.json
	packer validate $@.json
	packer build -on-error abort $@.json
