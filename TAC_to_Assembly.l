%{
#include "a3.tab.h"
#include <stdlib.h>
void yyerror(char *);
%}

%%

[ \t]               ;    // Ignore whitespace
[\n\r]               { yylineno++; }
\'[^']\'     { yylval.str_type = strdup(yytext); return CHAR_EXP;}
\'\\[abfnrt0v\\'\"\?]\'     { yylval.str_type = strdup(yytext); return CHAR_EXP;}
"L"[0-9]+     { yylval.int_type = atoi(yytext+1); return LABEL;}
"t"[0-9]+       {yylval.int_type = atoi(yytext+1); return TEMP;}
"if"            { return IF; }
"goto"          { return GOTO;}
"param"[0-9]+   {yylval.int_type = atoi(yytext+5); return PARAM;}
"return"         {return RETURN;}
[0-9]+           { yylval.int_type = atoi(yytext); return NUMBER; }
"retval"        {return RETVAL;}
"printf"        {return PRINT;}
"not"           {return NOT;}
"call"          {return CALL;}
[a-zA-Z_][a-zA-Z0-9_]* { yylval.str_type = strdup(yytext); return IDENTIFIER; }
"("              { return LPAREN; }
")"              { return RPAREN; }
"\["              { return LRECT; }
"\]"              { return RRECT; }
"=="             { return EQUALCHECK;  }
"<="             {  return LEQ; }
"!="              { return NEQ; }
"="              {  return EQ; }
">="             { return GEQ;  }
"+"              { return ADD; }
"-"              { return SUB; }
"*"              { return MUL;  }
"\/"             { return DIV; }
"<"              { return LESSER; }
":"              {return COLON;}
">"              { return GREATER; }
\"[^\"]*\"            { yylval.str_type = strdup(yytext); return TEXT; }
.                { printf("%d\n", yylineno); exit(418);}

%%

int yywrap() {
    return 1;
}
