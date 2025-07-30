%{
#include "tac.tab.h"
#include <stdlib.h>
void yyerror(char *);
%}

%%

[ \t]               ;    // Ignore whitespace
"/*"([^*]|\*+[^/*])*\*+\/   ;
"//"[^\n]*          ;
[\n\r]               { yylineno++; }
"int"            { return INT; }
"#include<stdio.h>" {return HEADER;}
\'[^']\'     { yylval.str_type = strdup(yytext); return CHAR_EXP;}
\'\\[abfnrt0v\\'\"\?]\'    { yylval.str_type = strdup(yytext); return CHAR_EXP;}
"char"           { return CHAR; }
"while"          { return WHILE; }
"if"            { return IF; }
"return"         {return RETURN;}
"else"            { return ELSE; }
[0-9]+           { yylval.str_type = strdup(yytext); return NUMBER; }
"main"          { return MAIN;}
[a-zA-Z_][a-zA-Z0-9_]* { yylval.str_type = strdup(yytext); return IDENTIFIER; }
","              { return COMMA; }
";"              { return SEMICOLON; }
"("              { return LPAREN; }
")"              { return RPAREN; }
"\["              { return LRECT; }
"\]"              { return RRECT; }
"{"              { return LCURLY; }
"}"              { return RCURLY; }
"=="             { yylval.str_type = strdup(yytext); return EQUALCHECK;  }
"<="             { yylval.str_type = strdup(yytext); return LEQ; }
"!="              {  yylval.str_type = strdup(yytext);return NEQ; }
"="              { return EQ; }
">="             { yylval.str_type = strdup(yytext); return GEQ;  }
"+"              { return ADD; }
"-"              { return SUB; }
"*"              { return MUL;  }
"\/"             { return DIV; }
"&&"             { return AND; }
"||"             { return OR; }
"!"              { return NOT; }
"<"              { yylval.str_type = strdup(yytext); return LESSER; }
">"              { yylval.str_type = strdup(yytext); return GREATER; }
\"[^\"]*\"            { yylval.str_type = strdup(yytext); return TEXT; }
.                { printf("%d\n", yylineno); exit(418);}

%%

int yywrap() {
    return 1;
}
