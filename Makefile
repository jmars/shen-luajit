shen: vm/klambda deps/luvi/build/luvi
	./deps/luvi/build/luvi vm -o shen

deps/luvi/Makefile:
	git submodule update --init --recursive

deps/luvi/build/luvi: deps/luvi/Makefile
	cd deps/luvi && make regular
	cd deps/luvi && make

clean:
	rm -rf deps/luvi
	git checkout deps
	rm -rf vm/klambda
	rm -rf ShenOSKernel-22.2.tar.gz
	rm -rf ShenOSKernel-22.2

distclean: clean
	rm shen

ShenOSKernel-22.2.tar.gz:
	wget https://github.com/Shen-Language/shen-sources/releases/download/shen-22.2/ShenOSKernel-22.2.tar.gz

vm/klambda: ShenOSKernel-22.2.tar.gz
	tar -xvf ShenOSKernel-22.2.tar.gz
	cp -r ShenOSKernel-22.2/klambda vm/klambda