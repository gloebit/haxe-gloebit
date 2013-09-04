#
#
#

all: Index.js Gloebit.n

Index.js Gloebit.n: compile.hxml Index.hx Gloebit.hx
	haxe compile.hxml

clean:
	rm -rf *~ Index.js Gloebit.n
