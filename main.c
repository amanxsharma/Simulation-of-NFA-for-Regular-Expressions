/* Baby Lex main function */

/* main.c */

#include <stdio.h>
#include <stdlib.h>
#include "nfa.h"

int yyparse();
static void execute();

int main(int argc, char **argv)
{
    extern FILE *yyin;
    extern int yydebug;
    yydebug = 0;         /* change to 1 to see debugging info */

        // Skip the command name
    --argc;
    ++argv;

    if (argc == 0) {
        printf("Usage: babylex rule_file_name\n");
        exit(0);
    }
    if (argc > 1) {
        fprintf(stderr, "Too many arguments (1 expected)\n");
        exit(1);
    }

    yyin = fopen(*argv, "r");
    if (yyin == NULL) {
        fprintf(stderr, "Cannot open file \"%s\" for reading\n", *argv);
        exit(1);
    }

    printf("Reading specification file ... ");
    yyparse();

    fclose(yyin);

    printf("OK\nExecuting automata ... enter text:\n");
    execute();
    
    return 0;
}

static char * match_fmt = "matches %d: %s";

static void execute()
{
    extern NFA_LIST the_nfa_list;
    STATE_SET ss = execute_init(the_nfa_list);
    int c, char_count = 0;

    print_matches(ss, char_count, stdout, match_fmt);

    while (ss != NULL && (c = getchar()) != EOF) {
        ss = execute_transition(ss, c);
        print_matches(ss, ++char_count, stdout, match_fmt);
    }

    if (ss == NULL)
        printf("No more matches\n");
    else
        printf("EOF reached\n");

    free_state_set(ss);
}
