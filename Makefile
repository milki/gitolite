# this is a simple wrapper around "git archive" using make

2.%:
	mkdir -p gitolite-$@/conf
	git describe --tags --long v$@ > gitolite-$@/conf/VERSION
	git archive --format=tar --prefix=gitolite-$@/ -o gitolite-$@.tar v$@
	tar -r -f gitolite-$@.tar gitolite-$@/conf/VERSION
	gzip gitolite-$@.tar
	rm -rf $@ gitolite-$@

3.%:
	mkdir -p gitolite-$@/src
	git describe --tags --long v$@ > gitolite-$@/src/VERSION
	git archive --format=tar --prefix=gitolite-$@/ -o gitolite-$@.tar v$@
	tar -r -f gitolite-$@.tar gitolite-$@/src/VERSION
	gzip gitolite-$@.tar
	rm -rf $@ gitolite-$@
