all: tac a.out

tac: tac.l tac.y
	bison -d tac.y
	flex tac.l
	g++ -std=c++11 -D_GLIBCXX_USE_CXX11_ABI=0 -o $@ tac.tab.c lex.yy.c -lfl
	@rm lex.yy.c tac.tab.h tac.tab.c

a.out: a3.l a3.y
	bison -d a3.y
	flex a3.l
	g++ -std=c++11 -D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -o $@ a3.tab.c lex.yy.c -lfl
	@rm lex.yy.c a3.tab.h a3.tab.c

clean: 
	@rm a.out tac
