include ../vars.mk

fbdeb12dev: clean-fbdeb12dev
	PF_MINOR_RELEASE=$(PF_DEV_MINOR_RELEASE) vagrant up $@ --provider=libvirt --no-destroy-on-error

halt-fbdeb12dev:
	vagrant halt -f fbdeb12dev

clean-fbdeb12dev:
	vagrant destroy -f fbdeb12dev
	rm -rf roles/

fbel8dev: clean-fbel8dev
	PF_MINOR_RELEASE=$(PF_DEV_MINOR_RELEASE) vagrant up $@ --provider=libvirt --no-destroy-on-error

halt-fbel8dev:
	vagrant halt -f fbel8dev

clean-fbel8dev:
	vagrant destroy -f fbel8dev
	rm -rf roles/

