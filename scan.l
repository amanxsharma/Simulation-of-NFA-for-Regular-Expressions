/* Lexical scanner for baby lex */

%{
#include <stdlib.h>
#include <assert.h>
#include "defs.h"
#include "nfa.h"
#include "parse.tab.h"
%}

    int yywrap();

metachar        [?+*|()\n]
empty_string    \"\"
string		    ["]([^"\\]|(\\.))+["]
special_char    \\[nrt]
ascii_code      \\[1-9][0-9]*
literal_char    \\.
character_class \[([^]\\]|(\\.))+\]
complement_character_class \[(\^)([^]\\]|(\\.))+\]
dot				[\.]

%%

{metachar}      { return yytext[0]; }

{empty_string}  { return EMPTY_STRING; }

{string}		{ yytext++; yytext[strlen(yytext)-1] = 0; yylval.yystr = strdup(yytext);  return STRING; }

{complement_character_class}	{ yytext++; yytext[strlen(yytext)-1] = 0; yylval.yystr = strdup(yytext); return COMPLEMENT_CHARACTER_CLASS; }

{character_class} { yytext++; yytext[strlen(yytext)-1] = 0; yylval.yystr = strdup(yytext); return CHARACTER_CLASS; }

{special_char}  { switch (yytext[1]) {
                    case 'n':
                      yylval.yyint = '\n';
                      break;
                    case 'r':
                      yylval.yyint = '\r';
                      break;
                    case 't':
                      yylval.yyint = '\t';
                      break;
                    default:
                      assert(FALSE);
                  }
                  return SYMBOL;
                }

{ascii_code}    { yylval.yyint = atoi(yytext+1);
                  return SYMBOL;
                }

{literal_char}  { yylval.yyint = yytext[1];
                  return LITERAL_SYMBOL;
                }

{dot}			{ return DOT;}
				
.               { yylval.yyint = yytext[0];
					//printf("detected dot %c\n",yylval.yyint);
                  return SYMBOL;
                }



%%

int yywrap()
{
    return 1;
}
