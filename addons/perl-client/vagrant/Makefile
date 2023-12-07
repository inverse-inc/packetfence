include ../vars.mk

fbdeb11dev: clean-fbdeb11dev
	PF_MINOR_RELEASE=$(PF_DEV_MINOR_RELEASE) vagrant up $@ --provider=libvirt --no-destroy-on-error

halt-fbdeb11dev:
	vagrant halt -f fbdeb11dev

clean-fbdeb11dev:
	vagrant destroy -f fbdeb11dev
	rm -rf roles/

fbel8dev: clean-fbel8dev
	PF_MINOR_RELEASE=$(PF_DEV_MINOR_RELEASE) vagrant up $@ --provider=libvirt --no-destroy-on-error

halt-fbel8dev:
	vagrant halt -f fbel8dev

clean-fbel8dev:
	vagrant destroy -f fbel8dev
	rm -rf roles/

