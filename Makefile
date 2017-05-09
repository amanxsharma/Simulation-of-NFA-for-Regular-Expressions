#
#	makefile for the Simple Expression Evaluator
#
#

CC = gcc

#CFLAGS = -g
CFLAGS =

#LIBS = -lfl
LIBS =

YACC = bison

YACCFLAGS = -t -v -d

LEX = flex

OBJECTS = main.o nfa.o parse.tab.o lex.yy.o

babylex: $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) $(LIBS) -o babylex

y.tab.h parse.tab.c: parse.y nfa.h defs.h
	$(YACC) $(YACCFLAGS) parse.y

lex.yy.c: scan.l parse.tab.h
	$(LEX) scan.l

nfa.c: nfa.h defs.h

main.c: nfa.h

clean:
	-rm *.o parse.tab.c parse.tab.h lex.yy.c parse.output babylex
