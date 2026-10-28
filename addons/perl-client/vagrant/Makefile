include ../vars.mk

fbdeb13dev: clean-fbdeb13dev
	PF_MINOR_RELEASE=$(PF_DEV_MINOR_RELEASE) vagrant up $@ --provider=libvirt --no-destroy-on-error

halt-fbdeb13dev:
	vagrant halt -f fbdeb13dev

clean-fbdeb13dev:
	vagrant destroy -f fbdeb13dev
	rm -rf roles/

fbel8dev: clean-fbel8dev
	PF_MINOR_RELEASE=$(PF_DEV_MINOR_RELEASE) vagrant up $@ --provider=libvirt --no-destroy-on-error

halt-fbel8dev:
	vagrant halt -f fbel8dev

clean-fbel8dev:
	vagrant destroy -f fbel8dev
	rm -rf roles/

