build:
	@jbuilder build @install

clean:
	@jbuilder clean

deps:
	@jbuilder external-lib-deps @install
