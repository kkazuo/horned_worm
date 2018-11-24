build:
	@dune build

clean:
	@dune clean

deps:
	@dune external-lib-deps @install
