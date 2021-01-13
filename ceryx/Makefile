.phony : copy deb

copy :
	rm -rf buildroot/source
	mkdir -p buildroot/source/usr/local/openresty/nginx
	cp -r nginx/lualib buildroot/source/usr/local/openresty/nginx/lualib
	mkdir -p buildroot/source/etc/ceryx
	cp -r static buildroot/source/etc/ceryx/static

deb : copy
	$(eval DISTRIB:=$(shell vagrant ssh -c "lsb_release -c | sed 's/Codename:\t//'" 2>/dev/null))
	vagrant ssh -c "cd /usr/src/buildroot; dch --distribution $(DISTRIB) --increment --no-auto-nmu 'build'"
	vagrant ssh -c "cd /usr/src/buildroot; sudo dpkg-buildpackage --no-sign --build=binary" 2>/dev/null
	vagrant ssh -c "sudo mv /usr/src/ceryx*.deb /usr/src/package/" 2>/dev/null
