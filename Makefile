# this is a simple wrapper around "git archive" using make

%.tar: version = $(subst .tar,,$(subst v,,$@))
%.tar:
	mkdir -p gitolite-${version}/src
	git describe --tags --long $* > gitolite-${version}/src/VERSION
	git archive --format=tar --prefix=gitolite-${version}/ -o gitolite-${version}.tar $*
	tar -r -f gitolite-${version}.tar gitolite-${version}/src/VERSION
	gzip gitolite-${version}.tar
	rm -rf $@ gitolite-${version}
