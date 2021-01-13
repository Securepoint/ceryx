.phony : copy deb

copy :
	rm -rf buildroot/source
	mkdir -p buildroot/source/etc/ceryx-api
	cp -r config/config.env buildroot/source/etc/ceryx-api/config.env
	mkdir -p buildroot/source/opt/ceryx-api
	cp -r ceryx buildroot/source/opt/ceryx-api
	cp api.py buildroot/source/opt/ceryx-api/api.py
	cp Pipfile buildroot/source/opt/ceryx-api/Pipfile
	cp Pipfile.lock buildroot/source/opt/ceryx-api/Pipfile.lock

deb : copy
	$(eval GIT_VERSION:=$(shell (git describe --tags 2>/dev/null || git branch --show-current) | tr -d v))
	$(eval DISTRIB:=$(shell vagrant ssh -c "lsb_release -c | sed 's/Codename:\t//'" 2>/dev/null))
	vagrant ssh -c "cd /usr/src/buildroot; dch --distribution $(DISTRIB) --newversion $(GIT_VERSION) 'build'"
	vagrant ssh -c "cd /usr/src/buildroot; sudo dpkg-buildpackage --no-sign --build=binary" 2>/dev/null
	vagrant ssh -c "sudo mv /usr/src/ceryx*.deb /usr/src/package/" 2>/dev/null
