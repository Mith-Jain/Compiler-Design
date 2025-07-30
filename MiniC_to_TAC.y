%{
    #include <stdio.h>
    #include <iostream> 
    #include <string>
    #include <cstring>
    #include <vector>
    #include <set>
    #include <map> 
    #include <stack> 
    #include <fstream>
    #include <sstream> 
    using namespace std;
    struct ExprNode {
        string name;
        stringstream buildup;
        ExprNode(string n){
            name = n;
        }
        void write(){
            cout << buildup.str();
            buildup.str("");
            buildup.clear();
        }
    };
    map<string, vector<int>> info;
    struct ArgList {
        vector<ExprNode*> arguments;
        ArgList() {}
    }; 
    struct CondNode {
        string condition;
        bool op;
        bool not_;
        int left_label;
        int right_label;
        CondNode* left;
        CondNode* right;
        CondNode* parent;
        CondNode(string _ = "", bool l = false){
            op = l;
            condition = _ ;
            left = nullptr;
            right = nullptr;
            parent = nullptr;
            not_ = false;
        }
    };

    struct IfNode {
        int true_label;
        int false_label;
        int next_label; 
        IfNode(int a, int b, int c){
            true_label = a;
            false_label = b;
            next_label = c;
        }
    } ;

    struct WhileNode {
        int while_label;
        int true_label; 
        int false_label;
        WhileNode(int a = 0, int b = 0, int c = 0){
            while_label = a;
            true_label = b;
            false_label = c;
        }
    };

	void yyerror(const char *);
	int yylex(void);
    extern int yylineno;
    map<string, int> global_table_char;
    vector<string> global_table;
    map<string, int> local_char;
    vector<string> local;
    bool is_global = true;
    char* empty_string = "";
    char* minus_symbol = "-";
    int count = 1;
    int param = 1;
    vector<string> arguments;
    int label_count = 1;
    stack<string> formisc;
    ofstream file;

    char* concat_strings(char* str1, char* str2, char* str3) {
        size_t total_length = strlen(str1) + strlen(str2) + strlen(str3) + 1; 
        char* result = (char*)malloc(total_length * sizeof(char));
        if (result == NULL) {
            printf("Memory allocation failed\n");
            exit(1);  
        }
        strcpy(result, str1);
        strcat(result, str2);
        strcat(result, str3);
        return result;
    }

    void write_params(vector<ExprNode*>& arguments, stringstream& is){
        int c = 1;
        for(ExprNode* i : arguments){
            is << (i -> buildup).str();
        }
        for(ExprNode* i : arguments){
            is << "param" << c << " = " << i -> name << endl;
            c++;
        }
    }

    void assign_labels(CondNode* root, int true_label, int false_label){
        // cout << "Assigning for " << root -> condition << endl;
        if(root -> not_){
            root -> left_label = false_label;
            root -> right_label = true_label;
        }
        else{
            root -> left_label = true_label;
            root -> right_label = false_label;
        }
        // cout << root -> left_label << ' ' << root -> right_label << endl;
        if(! (root -> op)) return;
        if(root -> condition == "&&"){
            label_count++;
            assign_labels(root -> left, label_count-1, root -> right_label);
            assign_labels(root -> right, root -> left_label, root -> right_label);
        }
        else{
            label_count++;
            assign_labels(root -> left, root -> left_label, label_count-1);
            assign_labels(root -> right, root -> left_label, root -> right_label);
        }
    }

    void while_short_circuit(CondNode* root){
        if(!(root -> op)){
            cout << root -> condition << endl;
            // if(root -> not_) {
            //     cout << "t" << 0  << " = not t" << 0 << endl;
            // }
            cout << "if (t" << 0 << ") goto L" << root -> left_label << endl;
            cout << "goto L" << root -> right_label << endl;
        }
        if(root -> op){
            while_short_circuit(root -> left);
        }
        if((root -> parent) && (root -> parent) -> left == root){
            if((root -> parent) -> condition == "&&"){
                if(!root -> not_ ) cout << "L" << (root -> left_label) << ":\n";
                else cout << "L" << (root -> right_label) << ":\n";
                while_short_circuit((root -> parent) -> right);
            }  
            else if((root -> parent) -> condition == "||"){
                if(!root -> not_ ) cout << "L" << (root -> right_label) << ":\n";
                else cout << "L" << (root -> left_label) << ":\n";
                while_short_circuit((root -> parent) -> right);
            }
        }
    }

    map<string, int> num_params;

    void update_local_info(char* s){
        file << "function " << string(s) << endl;
        for(auto i : local_char) file << "c " << i.first << " " << i.second << endl;
        for(string& i : local) file << "i " << i << endl;
        file << "t " << count-1 << endl;
        local_char.clear();
        local.clear();
        count = 1;
    }
%}

%token INT CHAR WHILE IF RETURN ELSE HEADER
%token COMMA SEMICOLON LCURLY RCURLY LPAREN RPAREN LRECT RRECT 
%token EQ  MAIN NOT AND OR
%left ADD SUB
%left MUL DIV 
%left OR
%left AND
%nonassoc NOT

%union{
    char* str_type;
    int int_type;
    struct ArgList* arg_type;
    struct CondNode* cond_type;
    struct WhileNode* while_type;
    struct IfNode* if_type;
    struct ExprNode* expr_type;
}
%token <str_type> IDENTIFIER TEXT NUMBER LEQ GEQ EQUALCHECK LESSER GREATER NEQ CHAR_EXP
%type <while_type> while_header
%type <str_type> integer function_naming
%type <if_type> if_header if_part if_else_part
%type <arg_type> argument_list
%type <cond_type> condexpression
%type <expr_type> expression function_call base_condition

%%

program : HEADER program_ {}
        ;

program_: global_declaration program_ {}
        | function program_ {}
        | main {}
    ;

global_declaration: INT IDENTIFIER SEMICOLON {global_table.push_back(string($2)); file << "g " << string($2) << "\n";}
                    | CHAR IDENTIFIER LRECT integer RRECT SEMICOLON {global_table_char[string($2)] = atoi($4); file << "gc " << $2 << " " << string($4) << "\n";}
                    ;

function_naming: INT IDENTIFIER LPAREN {cout << $2 << ":" << endl; $$ = $2;}
                ;

function: function_naming parameter_list_helper RPAREN LCURLY lines RCURLY {update_local_info($1);}
          | function_naming RPAREN LCURLY lines RCURLY {update_local_info($1); local_char.clear(); local.clear(); count = 1;}
            ;

parameter_list_helper: parameter_list {param = 1;}
            ;

mains: MAIN {cout << "main:\n"; num_params["main"] = 0;}

main: INT mains LPAREN RPAREN LCURLY lines RCURLY {update_local_info("main");}
        ;

declaration: INT IDENTIFIER {local.push_back(string($2));}
            | CHAR IDENTIFIER LRECT integer RRECT {local_char[string($2)] = atoi($4);}
            ;

function_call: 
    IDENTIFIER LPAREN argument_list RPAREN {$$ = new ExprNode(""); write_params($3->arguments, $$ -> buildup); num_params[string($1)] = $3->arguments.size(); ($$ -> buildup) << "call " << $1 << endl; free($3);}
    |  IDENTIFIER LPAREN RPAREN {$$ = new ExprNode(""); ($$ -> buildup) << "call " << $1 << endl;  num_params[string($1)] = 0;}
    ;

argument_list:
    TEXT {$$ = new ArgList(); ExprNode* temp = new ExprNode($1); ($$ -> arguments).push_back(temp);}
    | expression {$$ = new ArgList(); ($$ -> arguments).push_back($1);}
    | argument_list COMMA expression {($$ -> arguments).push_back($3); }
    |  argument_list COMMA TEXT {ExprNode* temp = new ExprNode($3); ($$ -> arguments).push_back(temp);}
    ;

parameter_list:
      INT IDENTIFIER {cout << $2 << " = param" << param << endl; param++;}
    | CHAR IDENTIFIER LRECT RRECT {cout << $2 << " = param" << param << endl; param++;}
    | parameter_list COMMA INT IDENTIFIER {cout << $4 << " = param" << param << endl; param++;}
    | parameter_list COMMA CHAR IDENTIFIER LRECT RRECT {cout << $4 << " = param" << param << endl; param++; }
    ;

lines:  line lines  {}
        | line {}
       ;

line: 
    declaration SEMICOLON {}
    | assignment SEMICOLON {}
    | return_stmt SEMICOLON 
    | while_loop {}
    | if_stmt {}
    | function_call SEMICOLON {$1 -> write();}
    ;

if_header: IF LPAREN condexpression RPAREN {$$ = new IfNode(label_count, label_count+1, label_count+2); label_count+=3; assign_labels($3, label_count-3, label_count-2); while_short_circuit($3); cout << "L" << $$ -> true_label << ":\n";}
        ;

if_part: if_header LCURLY lines RCURLY {$$ = $1; $$ -> next_label =  $$ -> false_label; cout << "goto L" << $$ -> false_label << endl; cout << "L" << $$ -> false_label << ":\n";}
        | if_header LCURLY RCURLY {$$ = $1; $$ -> next_label =  $$ -> false_label; cout << "goto L" << $$ -> false_label << endl; cout << "L" << $$ -> false_label << ":\n";}
        ;

if_else_part: if_header LCURLY lines RCURLY ELSE {$$ = $1; cout << "goto L" << $1 -> next_label << endl; cout << "L" << $$ -> false_label << ":\n";}
            | if_header LCURLY RCURLY ELSE {$$ = $1; cout << "goto L" << $1 -> next_label << endl; cout << "L" << $$ -> false_label << ":\n";}
            ;
if_stmt:
    if_part {}
    | if_else_part LCURLY lines RCURLY {cout << "goto L" << $1 -> next_label << endl << "L"<< $1 -> next_label << ":\n";}
    | if_else_part LCURLY RCURLY {cout << "goto L" << $1 -> next_label << endl << "L"<< $1 -> next_label << ":\n";}
    ;

return_stmt: 
    RETURN expression {$2 -> write(); cout << "retval = " << $2 -> name << endl; cout << "return" << endl;}
    ;

assignment: IDENTIFIER EQ expression {$3 -> write(); cout << $1 << " = "  << $3 -> name << endl;}
    | IDENTIFIER LRECT expression RRECT EQ IDENTIFIER LRECT expression RRECT {
    $8 -> write();
    cout << "t" << count << " = " << $6 << "[" << $8 -> name << "]\n";
    $3 -> write();
    cout << $1 << "[" << $3 -> name << "] = t" << count << endl;
    count++;
    }
    | IDENTIFIER LRECT expression RRECT EQ CHAR_EXP {
        $3 -> write();
    cout << $1 << "[" << $3 -> name << "] = " << $6 << endl; 
    }
                ;

expression: IDENTIFIER {$$ = new ExprNode(string($1));}
            | SUB IDENTIFIER {$$ = new ExprNode(string("-") + string($2));}
            | integer {$$ = new ExprNode(string($1));}
            | LPAREN expression RPAREN{$$ = $2;}
            | expression DIV expression {$$ = new ExprNode(""); ($$ -> buildup) << ($1 -> buildup).str() << ($3 -> buildup).str() << "t" << count << " = " << $1-> name << " / " << $3-> name << endl; $$ -> name = "t" + to_string(count); count++; }
            | expression MUL expression {$$ = new ExprNode(""); ($$ -> buildup)  << ($1 -> buildup).str() << ($3 -> buildup).str() << "t" << count << " = " << $1-> name << " * " << $3-> name << endl; $$ -> name = "t" + to_string(count); count++; }
            | expression SUB expression {$$ = new ExprNode(""); ($$ -> buildup) << ($1 -> buildup).str() << ($3 -> buildup).str() << "t" << count << " = " << $1-> name << " - " << $3-> name << endl; $$ -> name = "t" + to_string(count); count++; }
            | expression ADD expression {$$ = new ExprNode(""); ($$ -> buildup) << ($1 -> buildup).str() << ($3 -> buildup).str() << "t" << count << " = " << $1 -> name << " + " << $3-> name << endl; $$ -> name = "t" + to_string(count); count++; }
            | function_call {$$ = $1; ($$ -> buildup) << "t" << count << " = " << "retval\n"; $$ -> name = "t" + to_string(count); count++;}
            ;


integer: NUMBER {$$ = $1;}
        | ADD NUMBER {$$ = $2;}
        | SUB NUMBER {
            char* combined = new char[strlen($2)+2];
            strcpy(combined, minus_symbol);
            strcat(combined, $2);
            $$ = combined;
        }
        ;

condexpression:
    base_condition {$$ = new CondNode(($1 -> buildup).str(), 0);}
    | LPAREN condexpression RPAREN {$$ = $2;}
    | NOT condexpression {$$ = $2; $$ -> not_ = true;}
    | condexpression AND condexpression {$$ = new CondNode("&&", 1); $$ -> left = $1; $$ -> right = $3; $1 -> parent = $$; $3 -> parent = $$;}
    | condexpression OR condexpression {$$ = new CondNode("||", 1); $$ -> left = $1; $$ -> right = $3; $1 -> parent = $$; $3 -> parent = $$;}
    ;



base_condition: 
        expression EQUALCHECK expression {$$ = new ExprNode(""); ($$ -> buildup) << ($1 -> buildup).str() << ($3 -> buildup).str() << "t0 = " << $1 -> name << $2 << $3 -> name << endl;}
        | expression LEQ expression {$$ = new ExprNode(""); ($$ -> buildup) << ($1 -> buildup).str() << ($3 -> buildup).str() << "t0 = " << $1 -> name << $2 << $3 -> name << endl;}
        | expression GEQ expression {$$ = new ExprNode(""); ($$ -> buildup) << ($1 -> buildup).str() << ($3 -> buildup).str() << "t0 = " << $1 -> name << $2 << $3 -> name << endl;}
        | expression LESSER expression {$$ = new ExprNode(""); ($$ -> buildup) << ($1 -> buildup).str() << ($3 -> buildup).str() << "t0 = " << $1 -> name << $2 << $3 -> name << endl;}
        | expression GREATER expression {$$ = new ExprNode(""); ($$ -> buildup) << ($1 -> buildup).str() << ($3 -> buildup).str() << "t0 = " << $1 -> name << $2 << $3 -> name << endl;}
        | expression NEQ expression {$$ = new ExprNode(""); ($$ -> buildup) << ($1 -> buildup).str() << ($3 -> buildup).str() << "t0 = " << $1 -> name << $2 << $3 -> name << endl;}
        ;

while_helper: WHILE {cout << "L" << label_count << ":" << endl;}

while_header:
    while_helper LPAREN condexpression RPAREN { 
    int temp = label_count+1;
    $$ = new WhileNode(label_count, label_count+1, label_count+2); 
    label_count += 3;
    assign_labels($3, label_count-2, label_count-1);
    while_short_circuit($3);
    cout << "L" << temp << ":\n";
    }
    ; 


while_loop: while_header LCURLY lines RCURLY {cout << "goto L" << $1 -> while_label << endl <<  "L" << $1 -> false_label << ":\n";}
    ;

%%


void yyerror(const char* s) {
    printf("%s\n", s);
    exit(1);
}
    
int main(){
    file.open("info.txt");
    yyparse();
    for(auto i : num_params) file << "p " << i.first << ' ' << i.second << endl;
    file.close();
    return 0;
}

