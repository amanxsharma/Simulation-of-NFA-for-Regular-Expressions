/* Baby lex */

/* parse.y
 *
 * Grammer rules for bison.
 * Includes the lexical analyzer routine yylex().
 */


%{
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <assert.h>
#include "nfa.h"
#define YYDEBUG 1

NFA_LIST the_nfa_list = NULL;
unsigned int seq_num = 1;

int yylex();
char * char_to_string(int c);
int yyerror(char *s);
NFA build_or_nfa(NFA nfa1, NFA nfa2);
NFA build_concat_nfa(NFA first, NFA last);
NFA build_star_nfa(NFA nfa);
NFA build_plus_nfa(NFA nfa);
NFA build_dot_nfa();
NFA build_optional_nfa(NFA nfa);
NFA build_string_nfa(char* str);
NFA build_character_class_nfa(char* str);
NFA build_character_class_star_nfa(char* str);
NFA build_character_class_plus_nfa(char* str);
NFA build_character_class_optional_nfa(char* str);
NFA build_complement_character_class_nfa(char* str);
NFA build_basic_nfa(int c);
NFA build_literal_character_nfa(int c);
char * concat(const char * str1, const char * str2);
char * char_to_string(int c);
%}

%union {
    int    yyint;
    char * yystr;
    NFA    yynfa;
}

%type  <yynfa> regex concat_regex star_regex primary_regex
%token <yyint> SYMBOL LITERAL_SYMBOL
%token <yystr> STRING CHARACTER_CLASS COMPLEMENT_CHARACTER_CLASS
%token EMPTY_STRING DOT

%%

session
    : eval
    ;

eval
    : eval line
    | /* empty */
    ;

line
    : regex '\n'               { add_nfa(&the_nfa_list,$1); seq_num++; }
    ;

regex
    : regex '|' concat_regex   { $$ = build_or_nfa($1,$3); }
    | concat_regex
    ;

concat_regex
    : concat_regex star_regex  { $$ = build_concat_nfa($1,$2); }
    | star_regex
    ;

star_regex
    : star_regex '*'           { $$ = build_star_nfa($1); }
	| CHARACTER_CLASS '*'	   { $$ = build_character_class_star_nfa($1); }
	| star_regex '+'		   { $$ = build_plus_nfa($1); }
	| CHARACTER_CLASS '+'	   { $$ = build_character_class_plus_nfa($1); }
	| star_regex '?'		   { $$ = build_optional_nfa($1); }
	| CHARACTER_CLASS '?'	   { $$ = build_character_class_optional_nfa($1); }
	| primary_regex
    ;

primary_regex
: '(' regex ')'                { set_regex($2,
                                           concat("(",
                                                  concat(get_regex($2),")")));
                                 $$ = $2; }
    | EMPTY_STRING             { $$ = build_basic_nfa('\0'); }
	| STRING				   { $$ = build_string_nfa($1); }
	| DOT					   { $$ = build_dot_nfa(); }
	| CHARACTER_CLASS		   { $$ = build_character_class_nfa($1); }
	| COMPLEMENT_CHARACTER_CLASS {  $$ = build_complement_character_class_nfa($1); }
    | SYMBOL                   { $$ = build_basic_nfa($1); }
	| LITERAL_SYMBOL		   { $$ = build_literal_character_nfa($1); }
	;

%%
//Build complement character class nfa
NFA build_complement_character_class_nfa(char* str)
{
	int i=1,j,flag=0;
	char c;
	char * regex = concat("[",concat(str,"]"));
	NFA first_nfa,second_nfa;
	c=i;
	str++;
	
	first_nfa = build_basic_nfa(c);
	
	char backslash_char,char_after_hyphen, char_before_hyphen;
	int int_after_hyphen, int_before_hyphen,k,len;
	len = strlen(str);
	for(i=2;i<=127;i++)
	{	flag = 0;
		c = i;
		
		for(j=0;j<len;j++)
		{
			if(str[j] == '\\')
			{	j++;
				if(str[j] == 'n')
					backslash_char = '\n';
				else if(str[j] == 't')
					backslash_char = '\t';
				else if(str[j] == 'r')
					backslash_char = '\r';
				else
					backslash_char = str[j];
					
				if(c==backslash_char)
					flag = 1;
					break;
			}
			else if(str[j] == '-' && c != '-')
			{	
				
					if(j!=len-1 && j!=0)
					{
						char_after_hyphen = str[j+1];
						char_before_hyphen = str[j-1];
						int_after_hyphen = char_after_hyphen;
						int_before_hyphen = char_before_hyphen;
						if(c >= int_before_hyphen && c <= int_after_hyphen)
						{
						flag= 1;
						break;
						}
					}
					
				
			}
			else if(c == str[j])
			{					
					flag=1;
					break;					
			}
		}
		if(flag==0)
		{
			second_nfa = build_basic_nfa(c);
			first_nfa = build_or_nfa(first_nfa,second_nfa);
		}
		
		
	}
	//printf("regex created is %s\n",get_regex(first_nfa));
	set_regex(first_nfa,regex);
	return first_nfa;
}

//Build DOT nfa
NFA build_dot_nfa()
{
	//printf("building dot nfa\n");
	int i=1;
	char c;
	char* regex = ".";
	NFA first_nfa, second_nfa;
	c = i;
	first_nfa = build_basic_nfa(c);
	for(i=2;i<=127;i++)
	{
		c = i;
		second_nfa = build_basic_nfa(c);
		first_nfa = build_or_nfa(first_nfa,second_nfa);
	}
	set_regex(first_nfa, regex);
	return first_nfa;
}

//Build character class star nfa
NFA build_character_class_star_nfa(char* str)
{
	return build_star_nfa(build_character_class_nfa(str));
}

//Build character class plus nfa
NFA build_character_class_plus_nfa(char* str)
{
	return build_plus_nfa(build_character_class_nfa(str));
}

//Build character class optional nfa
NFA build_character_class_optional_nfa(char* str)
{
	return build_optional_nfa(build_character_class_nfa(str));
}


// Build and return the disjunction (OR) of two given NFAs
NFA build_or_nfa(NFA nfa1, NFA nfa2)
{
    STATE new_start = new_state();
    STATE new_accept = new_state();
    char * regex = concat(get_regex(nfa1),concat("|",get_regex(nfa2)));
    add_epsilon_move(new_start, get_start_state(nfa1));
    add_epsilon_move(new_start, get_start_state(nfa2));
    add_epsilon_move(get_accept_state(nfa1), new_accept);
    add_epsilon_move(get_accept_state(nfa2), new_accept);
    free_nfa(nfa1);
    free_nfa(nfa2);
    return new_nfa(seq_num, regex, new_start, new_accept);
}

// Build and return the concatenation of two NFAs
NFA build_concat_nfa(NFA first, NFA last)
{
    STATE start = get_start_state(first);
    STATE accept = get_accept_state(last);
    char * regex = concat(get_regex(first),get_regex(last));
    add_epsilon_move(get_accept_state(first), get_start_state(last));
    free_nfa(first);
    free_nfa(last);
    return new_nfa(seq_num, regex, start, accept);
}

// Build and return the Kleene *-closure of an NFA
NFA build_star_nfa(NFA nfa)
{
    STATE old_start = get_start_state(nfa);
    STATE new_start = new_state();
    STATE old_accept = get_accept_state(nfa);
    char * regex = concat(get_regex(nfa),"*");
    free_nfa(nfa);
    add_epsilon_move(new_start, old_start);
    add_epsilon_move(old_accept, new_start);
    return new_nfa(seq_num, regex, new_start, new_start);
}

// Build and return the plus + of an NFA
NFA build_plus_nfa(NFA nfa)
{
	STATE old_start = get_start_state(nfa);
	STATE old_accept = get_accept_state(nfa);
	char * regex = concat(get_regex(nfa),"+");
	free_nfa(nfa);
	add_epsilon_move(old_accept,old_start);
	return new_nfa(seq_num, regex, old_start, old_accept);	
}

// Build and return optional ? NFA
NFA build_optional_nfa(NFA nfa)
{
	STATE old_start = get_start_state(nfa);
	STATE new_start = new_state();
	STATE old_accept = get_accept_state(nfa);
	STATE new_accept = new_state();
	char * regex = concat(get_regex(nfa),"?");
	free_nfa(nfa);
	add_epsilon_move(new_start, old_start);
	add_epsilon_move(new_start, new_accept);
	add_epsilon_move(old_accept, new_accept);
	return new_nfa(seq_num, regex, new_start, new_accept);
}

// Build string NFA
NFA build_string_nfa(char* str)
{
	char* regex = concat("\"",concat(str,"\""));
	int i =0,j,len,k=0,flag;
	char backslash_char;
	STATE start = new_state();
	STATE accept[strlen(str)+1];
	
	for(j=0; j<=strlen(str)+1; j++)
	{
		accept[j] = new_state();
	}
	if(str[0] == '\\')
	{	
		if(str[1] == 'n'){
				backslash_char = '\n';
				//printf("backslash character %c\n",backslash_char);
			}
			else if(str[1] == 't'){
				backslash_char = '\t';
				//printf("backslash character %c\n",backslash_char);
			}
			else if(str[1] == 'r'){
				backslash_char = '\r';
				//printf("backslash character %c\n",backslash_char);
			}
			else if(str[1] == '\\'){
				backslash_char = '\\';
				//printf("backslash character %c\n",backslash_char);
			}
			else{
				backslash_char = str[1];
				//printf("backslash character %c\n",backslash_char);
			}
		make_transition(start,backslash_char,accept[0]);
		add_epsilon_move(accept[0],accept[1]);
		k=2;
	}
	else
	{
		make_transition(start,str[0],accept[0]);
		k=1;
	}
	len = strlen(str);
	
	for(k; k<len; k++)
	{	//printf("k=%d\n",k);
		if(str[k] == '\\')
		{
			if(str[k+1] == 'n'){
				backslash_char = '\n';
				//printf("backslash character %c\n",backslash_char);
			}
			else if(str[k+1] == 't'){
				backslash_char = '\t';
				//printf("backslash character %c\n",backslash_char);
			}
			else if(str[k+1] == 'r'){
				backslash_char = '\r';
				//printf("backslash character %c\n",backslash_char);
			}
			else if(str[k+1] == '\\'){
				backslash_char = '\\';
				//printf("backslash character %c\n",backslash_char);
			}
			else{
				backslash_char = str[k+1];
				//printf("backslash character %c\n",backslash_char);
			}
			make_transition(accept[k-1],backslash_char,accept[k]);
			add_epsilon_move(accept[k],accept[k+1]);
			//printf("nfa for character %c = %d\n",backslash_char,k);
			k++;
		}
		else
		{
			make_transition(accept[k-1],str[k],accept[k]);
			//printf("nfa for character %c = %d\n",str[k],k);
		}
	}
	return new_nfa(seq_num, regex, start, accept[k-1]);
}

// Build character class NFA
NFA build_character_class_nfa(char* str)
{
	int i,j=0,k,len = strlen(str),flag=0,int_after_hyphen, int_before_hyphen;
	char char_after_hyphen,char_before_hyphen,backslash_char;
	char * regex = concat("[",concat(str,"]"));
	//printf("regex = %s\n",regex);
	
	NFA first_nfa;
	NFA second_nfa;
	
	if(str[j] == '\\')
			{
				if(str[j+1] == 'n')
					backslash_char = '\n';
				else if(str[j+1] == 't')
					backslash_char = '\t';
				else if(str[j+1] == 'r')
					backslash_char = '\r';
				else
					backslash_char = str[j+1];
				first_nfa = build_basic_nfa(backslash_char);
				j=2;
			}
			else
			{
				first_nfa = build_basic_nfa(str[0]);
				j=1;
			}
	
	
	for(j;j<len;j++)
	{
		if(str[j] == '-')
		{	
			if(j==len-1)
			{
				second_nfa = build_basic_nfa(str[j]);
				first_nfa = build_or_nfa(first_nfa,second_nfa);
			}
			else
			{
			//printf("has hyphen\n");
			flag = 1;
			char_after_hyphen = str[j+1];
			char_before_hyphen = str[j-1];
			int_after_hyphen = char_after_hyphen;
			int_before_hyphen = char_before_hyphen;
			//printf("char b= %c, int b = %d, char a = %c int a = %d \n",char_before_hyphen, int_before_hyphen, char_after_hyphen, int_after_hyphen);
			//first_nfa = build_basic_nfa(char_before_hyphen);
			for(k=int_before_hyphen+1; k<=int_after_hyphen; k++)
			{
				second_nfa = build_basic_nfa(k);
				//printf("nfa for %c\n",k);
				first_nfa = build_or_nfa(first_nfa,second_nfa);
			}
			}
		}
		else
		{
			if(str[j] == '\\')
			{
				if(str[j+1] == 'n')
					backslash_char = '\n';
				else if(str[j+1] == 't')
					backslash_char = '\t';
				else if(str[j+1] == 'r')
					backslash_char = '\r';
				else
					backslash_char = str[j+1];
				second_nfa = build_basic_nfa(backslash_char);
				first_nfa = build_or_nfa(first_nfa, second_nfa);
				j++;
			}
			else
			{
			second_nfa = build_basic_nfa(str[j]);
			//printf("nfa for %c\n",str[j]);
			first_nfa = build_or_nfa(first_nfa, second_nfa);
			}
		}
		
	}
	set_regex(first_nfa,regex);
	return first_nfa;
}

//Build nfa for literal character
NFA build_literal_character_nfa(int c)
{
	STATE start = new_state();
    STATE accept;
	char * regex = (char*)malloc(sizeof(char));
    if (c == '\0') // want to return a one-state NFA for the empty string
        return new_nfa(seq_num, "\"\"", start, start);

        // else, build an NFA to accept a single symbol
    accept = new_state();
    make_transition(start, c, accept);
	if(c=='\"')
	{
	regex = concat("\\",char_to_string(c));
	}
	else
	{
	regex = char_to_string(c);
	}
    return new_nfa(seq_num, regex, start, accept);
}

// Build and return an NFA that accepts a single symbol c
// (or the empty string if c=='\0')
NFA build_basic_nfa(int c)
{
    STATE start = new_state();
    STATE accept;

    if (c == '\0') // want to return a one-state NFA for the empty string
        return new_nfa(seq_num, "\"\"", start, start);

        // else, build an NFA to accept a single symbol
    accept = new_state();
    make_transition(start, c, accept);
    return new_nfa(seq_num, char_to_string(c), start, accept);
}

// Called if there is a syntax error
int yyerror(char *s)
{
    fprintf(stderr, "%s\n", s);
    return 0;
}


// Return the concatenation of two strings
char * concat(const char * str1, const char * str2)
{
    int l1 = strlen(str1);
    int l2 = strlen(str2);
    char * ret = (char *)malloc(l1+l2+1);
    assert(ret != NULL);
    strcpy(ret, str1);
    strcat(ret, str2);
    return ret;
}

// Return a C-style string constant (without quotes) for the given character
char * char_to_string(int c)
{
    char * ret;

        // Characters that require a preceding backslash to be taken literalliterally
    if (c=='\n'||c=='\r'||c=='\t'||c=='\\'||c=='*'||c=='|'||c=='('||c==')') {
        ret = (char *)malloc(3);
	assert(ret != NULL);
	ret[0] = '\\';
	ret[1] = (c=='\n'?'n':c=='\r'?'r':c=='\t'?'t':c);
	ret[2] = '\0';
    }
    else { // Everything else
        ret = (char *)malloc(2);
        assert(ret != NULL);
        ret[0] = c;
        ret[1] = '\0';
    }
    return ret;
}
