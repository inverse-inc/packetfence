SHELL = /bin/sh

buildpkg:
	packer build -on-error abort $@.json

validate: buildpkg.json
	packer validate $^
