%{
    #include <iostream> 
    #include <string>
    #include <cstring>
    #include <vector>
    #include <sstream> 
    #include <set>
    #include <fstream>
    #include <unordered_map>
    #include <stack> 
    using namespace std;

    void yyerror(const char *);
	int yylex(void);
    
    struct function_info{ 
        unordered_map<string, int> ints;
        unordered_map<string, pair<int, int>> chars;
        int temporaries;
        int total_char;
        int arity;
        function_info(){}
    };

    unordered_map<string, int> global_char;
    vector<string> globals;
    unordered_map<string, function_info*> info;

    string op, cur_func;
    vector<string> texts;

    vector<string> print_count;

    void prologue(char* s){
        cur_func = string(s);
        struct function_info* cur = info[cur_func];
        printf(".globl %s \n %s: \n", s, s);
        cout << "pushl %" << "ebp\n";  
        cout << "movl %" << "esp, %" << "ebp\n"; 
        
        cout << "subl $" << cur -> total_char + 4 * cur -> temporaries + (cur -> ints).size() * 4  << ", %" << "esp\n";

    }

    void write_data(){
        if(texts.size()){
            cout << ".data\n";
            for(int i = 0; i < texts.size(); i++){
                cout << "fmt" << i + 1 << ":\t.asciz " << texts[i] << "\n"; 
            }
        }
    }

    ifstream file;
    unordered_map<string, int> func_params;
    // SIMILAR FOR CHAR ARRAYS, NEED TO DISCUSS

    int find_offset(char* s){
        // local_int, then temporaries, then local_char_arrays
        string a = string(s);
        struct function_info* cur = info[cur_func];
        if(func_params.find(a) != func_params.end()){
            return 8 + 4*(func_params[a]);
        }
        if((cur -> ints).find(a) == (cur -> ints).end()){
            return (-4 * (cur -> ints).size()  - 4* cur -> temporaries - (cur -> chars)[a].second);
        }
        else return -(cur -> ints)[a] * 4;
    }

    string charval(char* s){
        string ss = string(s);
        if(ss == "'\\0'") ss = "0";
        return ss;
    }

    int text_count = 1;

    int find_temp_offset(int t){
        struct function_info* cur = info[cur_func];
        return -(cur ->ints).size() * 4 - t * 4;
    }

    string rel;
    vector<string> tokens;

    void tokenise(string& line){ 
        istringstream cout(line);
        string token;
        while(cout >> token) tokens.push_back(token);
    }

    void param_handler(string id, int param_index){
        func_params[id] = param_index;
        return;
    }

    void process_info(){
        file.open("info.txt");
        string line;
        struct function_info* cur;
        struct function_info* printf_temp = new function_info();
        info["printf"] = printf_temp;
        int intc = 1, charc = 1, cdone = 0;
        while(getline(file, line)){
            tokenise(line);
            if(tokens[0] == "function") {info[tokens[1]] = new function_info(); cur = info[tokens[1]]; intc = 1, charc = 1, cdone = 0;}
            else if(tokens[0] == "p") info[string(tokens[1])] -> arity = stoi(tokens[2]);
            else if(tokens[0] == "g") globals.push_back(tokens[1]);
            else if(tokens[0] == "gc") global_char[tokens[1]] = stoi(tokens[2]);
            else if(tokens[0] == "i") {cur -> ints[tokens[1]] = intc; intc++;}
            else if(tokens[0] == "c") {cdone += stoi(tokens[2]); cur -> chars[tokens[1]] = {stoi(tokens[2]), cdone}; (cur -> total_char) +=  stoi(tokens[2]); charc++;}
            else if(tokens[0] == "t") cur -> temporaries = stoi(tokens[1]);
            tokens.clear();
        }
        file.close();
    }

    void write_global(){
        if(globals.size() || global_char.size()){
            cout << ".bss\n";
            for(auto i : globals) cout << i << ":\t.space 4\n";
            for(auto i : global_char) cout << i.first << ":\t.space " << i.second << "\n";
        }
        return;
    }

    bool local(char* s){
        string ss = string(s);
        if(func_params.find(ss) != func_params.end()) return true;
        struct function_info* current = info[cur_func];
        if(current->ints.find(ss) != current->ints.end() || current->chars.find(ss) != current->chars.end()) return true;
        return false;
    }

    void flip(){
        if(rel == "je") rel = "jne";
        if(rel == "jge") rel = "jl";
        if(rel == "jle") rel = "jg";
        if(rel == "jne") rel = "je";
        if(rel == "jl") rel = "jge";
        if(rel == "jg") rel = "jle";
    }

    void printing_params(){
        while(print_count.size()){
            cout << print_count.back() << endl;
            print_count.pop_back();
        }
    }
%}

%union{
    char* str_type;
    int int_type;
}

%token IF RETURN ADD SUB MUL DIV EQ NOT COLON LPAREN RPAREN LRECT RRECT RETVAL EQUALCHECK LEQ GEQ LESSER GREATER NEQ GOTO CALL PRINT
%token <str_type> IDENTIFIER TEXT CHAR_EXP
%token <int_type> TEMP NUMBER LABEL PARAM
%type <int_type> integer


%%
program : functions
        ;

functions: function functions
        | function {}
        ;

function: function_header lines return_stmt {}
          | function_header return_stmt {}
        ;

function_call: set_params CALL IDENTIFIER {int temp = 4 * print_count.size(); printing_params(); cout << "call " << $3 << "\n"; cout << "addl\t $" << temp << ", \%esp\n";}
               | CALL IDENTIFIER {int temp = 4 * print_count.size(); printing_params(); cout << "call " << $2 << "\n"; cout << "addl\t $" << temp << ", \%esp\n";}
               | CALL PRINT {int temp = 4 * print_count.size(); printing_params(); cout << "call printf\n"; cout << "addl\t $" << temp << ", \%esp\n";}
               | set_params CALL PRINT {int temp = 4 * print_count.size(); printing_params(); cout << "call printf\n"; cout << "addl\t $" << temp << ", \%esp\n";}
            ;

set_params: set_params PARAM EQ integer {print_count.push_back(string("pushl\t$") + to_string($4));}
            | PARAM EQ integer {print_count.push_back(string("pushl\t$") + to_string($3));}
            | set_params PARAM EQ TEMP {print_count.push_back(string("pushl\t") + to_string(find_temp_offset($4)) + "(\%ebp)");}
            | PARAM EQ TEMP {print_count.push_back(string("pushl\t") + to_string(find_temp_offset($3)) + "(\%ebp)");}
            | set_params PARAM EQ IDENTIFIER {
                string ss = string($4);
                if(func_params.find(ss) != func_params.end()){
                    print_count.push_back(string("pushl\t") + to_string(find_offset($4)) + "(\%ebp)");
                }
                else{
                    struct function_info* current = info[cur_func];
                    if(current->ints.find(ss) != current->ints.end()){
                        print_count.push_back(string("pushl\t") + to_string(find_offset($4)) + "(\%ebp)");
                    }
                    else if(current->chars.find(ss) != current->chars.end()){
                        print_count.push_back(string("leal\t") + to_string(find_offset($4)) + string("(\%ebp), \%eax\n") + string("pushl\t") + "\%eax");
                    }
                    else if(global_char.find(ss) == global_char.end()){
                        print_count.push_back(string("pushl\t") + string($4));
                    }
                    else{
                        print_count.push_back(string("leal\t") + string($4) + string(", \%eax\n") + string("pushl\t") + "\%eax");
                    }
                }
            }
            | PARAM EQ IDENTIFIER {
                string ss = string($3);
                if(func_params.find(ss) != func_params.end()){
                    print_count.push_back(string("pushl\t") + to_string(find_offset($3)) + "(\%ebp)");
                }
                else{
                    struct function_info* current = info[cur_func];
                    if(current->ints.find(ss) != current->ints.end()){
                        print_count.push_back(string("pushl\t") + to_string(find_offset($3)) + "(\%ebp)");
                    }
                    else if(current->chars.find(ss) != current->chars.end()){
                        print_count.push_back(string("leal\t") + to_string(find_offset($3)) + string("(\%ebp), \%eax\n") + string("pushl\t") + "\%eax");
                    }
                    else if(global_char.find(ss) == global_char.end()){
                        print_count.push_back(string("pushl\t") + string($3));
                    }
                    else{
                        print_count.push_back(string("leal\t") + string($3) + string(", \%eax\n") + string("pushl\t") + "\%eax");
                    }
                }
            }
            | set_params PARAM EQ TEXT {texts.push_back(string($4)); print_count.push_back(string("pushl\t$") + "fmt" + to_string(texts.size()));}
            | PARAM EQ TEXT {texts.push_back(string($3)); print_count.push_back(string("pushl\t$") + "fmt" + to_string(texts.size()));}
            ;

function_header: IDENTIFIER COLON {prologue($1); func_params.clear();}
        ;

alu: TEMP EQ TEMP ope TEMP {cout << "movl\t"<< find_temp_offset($3) << "(%" << "ebp), %" << "eax\n"; cout << "movl\t"<< find_temp_offset($5) << "(%" << "ebp), %" << "ebx\n";
                            cout << op << "\t%" << "ebx, %" << "eax\n"; cout << "movl\t%" << "eax, " << find_temp_offset($1) << "(%" << "ebp)\n";}
    | TEMP EQ TEMP ope integer {cout << "movl\t"<< find_temp_offset($3) << "(%" << "ebp), %" << "eax\n";
                            cout << op << "\t$" << $5 << ", %" << "eax\n"; cout << "movl\t%" << "eax, " << find_temp_offset($1) << "(%" << "ebp)\n";}
    | TEMP EQ integer ope TEMP {cout << "movl\t$"<< $3 << ", %" << "eax\n"; cout << "movl\t"<< find_temp_offset($5) << "(%" << "ebp), %" << "ebx\n";
                            cout << op << "\t%" << "ebx, %" << "eax\n"; cout << "movl\t%" << "eax, " << find_temp_offset($1) << "(%" << "ebp)\n";}
    | TEMP EQ integer ope integer {cout << "movl\t$"<< $3 << ", %" << "eax\n";
                            cout << op << "\t$" << $5 << ", %" << "eax\n"; cout << "movl\t%" << "eax, " << find_temp_offset($1) << "(%" << "ebp)\n";}
    | TEMP EQ IDENTIFIER ope integer {if(local($3)) cout << "movl\t"<< find_offset($3) << "(%" << "ebp), %" << "eax\n"; else cout << "movl\t"<< $3 << ", %" << "eax\n";
                            cout << op << "\t$" << $5 << ", %" << "eax\n"; cout << "movl\t%" << "eax, " << find_temp_offset($1) << "(%" << "ebp)\n";}
    | TEMP EQ IDENTIFIER ope TEMP{ if(local($3)) cout << "movl\t"<< find_offset($3) << "(%" << "ebp), %" << "eax\n"; else cout << "movl\t"<< $3 << ", %" << "eax\n"; cout << "movl\t"<< find_temp_offset($5) << "(%" << "ebp), %" << "ebx\n";
                            cout << op << "\t%" << "ebx, %" << "eax\n"; cout << "movl\t%" << "eax, " << find_temp_offset($1) << "(%" << "ebp)\n";}
    | TEMP EQ TEMP ope IDENTIFIER{cout << "movl\t"<< find_temp_offset($3) << "(%" << "ebp), %" << "eax\n"; if(local($5)) cout << "movl\t"<< find_offset($5) << "(%" << "ebp), %" << "ebx\n"; else cout << "movl\t"<< $5 << ", %" << "ebx\n";
                            cout << op << "\t%" << "ebx, %" << "eax\n"; cout << "movl\t%" << "eax, " << find_temp_offset($1) << "(%" << "ebp)\n";}
    | TEMP EQ integer ope IDENTIFIER{cout << "movl\t$"<< $3 << ", %" << "eax\n"; if(local($5)) cout << "movl\t"<< find_offset($5) << "(%" << "ebp), %" << "ebx\n"; else cout << "movl\t"<< $5 << ", %" << "ebx\n";
                            cout << op << "\t%" << "ebx, %" << "eax\n"; cout << "movl\t%" << "eax, " << find_temp_offset($1) << "(%" << "ebp)\n";}
    | TEMP EQ IDENTIFIER ope IDENTIFIER{ if(local($3)) cout << "movl\t"<< find_offset($3) << "(%" << "ebp), %" << "eax\n"; else cout << "movl\t"<< $3 << ", %" << "eax\n";
                            if(local($5)) cout << "movl\t"<< find_offset($5) << "(%" << "ebp), %" << "ebx\n"; else cout << "movl\t"<< $5 << ", %" << "ebx\n";
                            cout << op << "\t%" << "ebx, %" << "eax\n"; cout << "movl\t%" << "eax, " << find_temp_offset($1) << "(%" << "ebp)\n";}
    ;

alu_div: TEMP EQ TEMP DIV TEMP {cout << "movl\t"<< find_temp_offset($3) << "(\%ebp), \%eax\ncltd\nidivl\t" << find_temp_offset($5) << "(\%ebp)\n"; cout << "movl\t \%eax, " << find_temp_offset($1) << "(\%ebp)\n";}
    | TEMP EQ TEMP DIV integer {cout << "movl\t$" << $5 << ", \%ebx\n" << "movl\t"<< find_temp_offset($3) << "(\%ebp), \%eax\ncltd\nidivl\t\%ebx" << "\n"; cout << "movl\t \%eax, " << find_temp_offset($1) << "(\%ebp)\n";}
    | TEMP EQ integer DIV TEMP {cout << "movl\t$"<< $3 << ", \%eax\ncltd\nidivl\t" << find_temp_offset($5) << "(\%ebp)\n"; cout << "movl\t \%eax, " << find_temp_offset($1) << "(\%ebp)\n";}
    | TEMP EQ integer DIV integer {cout << "movl\t$" << $5 << ", \%ebx\n" << "movl\t$"<< $3 << ", \%eax\ncltd\nidivl\t\%ebx" << "\n"; cout << "movl\t \%eax, " << find_temp_offset($1) << "(\%ebp)\n";}
    | TEMP EQ IDENTIFIER DIV integer {cout << "movl\t$" << $5 << ", \%ebx\n"; if(local($3)) cout << "movl\t"<< find_offset($3) << "(\%ebp), \%eax\ncltd\nidivl\t\%ebx"<< "\n"; else cout << "movl\t"<< $3 << ", \%eax\ncltd\nidivl\t\%ebx" << "\n"; cout << "movl\t \%eax, " << find_temp_offset($1) << "(\%ebp)\n";}
    | TEMP EQ IDENTIFIER DIV TEMP {if(local($3)) cout << "movl\t"<< find_offset($3) << "(\%ebp), \%eax\ncltd\nidivl\t" << find_temp_offset($5) << "(\%ebp)\n"; else cout << "movl\t"<< $3 << ", \%eax\ncltd\nidivl\t" << find_temp_offset($5) << "\n"; cout << "movl\t \%eax, " << find_temp_offset($1) << "(\%ebp)\n";}
    | TEMP EQ TEMP DIV IDENTIFIER {if(local($5)) cout << "movl\t"<< find_temp_offset($3) << "(\%ebp), \%eax\ncltd\nidivl\t" << find_offset($5) << "(\%ebp)\n"; else cout << "movl\t"<< find_temp_offset($3) << "(\%ebp), \%eax\ncltd\nidivl\t" << $5 << "\n"; cout << "movl\t \%eax, " << find_temp_offset($1) << "(\%ebp)\n";}
    | TEMP EQ integer DIV IDENTIFIER{if(local($5)) cout << "movl\t$"<< $3 << ", \%eax\ncltd\nidivl\t" << find_offset($5) << "(\%ebp)\n"; else cout << "movl\t$"<< $3 << ", \%eax\ncltd\nidivl\t" << $5 << "\n"; cout << "movl\t \%eax, " << find_temp_offset($1) << "(\%ebp)\n";}
    | TEMP EQ IDENTIFIER DIV IDENTIFIER{if(local($3)) {cout << "movl\t"<< find_offset($3) << "(\%ebp), \%eax\ncltd\nidivl\t"; if(local($5)) cout << find_offset($5) << "(\%ebp)\n"; else cout << $5 << endl;} else {cout << "movl\t"<< $3 << ", \%eax\ncltd\nidivl\t"; if(local($5)) cout << find_offset($5) << "(\%ebp)\n"; else cout << $5 << endl;} cout << "movl\t \%eax, " << find_temp_offset($1) << "(\%ebp)\n";}
    ;

assignment: IDENTIFIER EQ integer {if(local($1)) cout << "movl\t$" << $3 << ", " << find_offset($1) << "(%" << "ebp)\n";
                                    else cout << "movl\t$" << $3 << ", " << $1 << "\n";}
            | IDENTIFIER EQ IDENTIFIER {if(local($1)) {if(local($3)) cout << "movl\t" << find_offset($3) << "(%" << "ebp), \%eax\nmovl\t \%eax,  " << find_offset($1) << "(%" << "ebp)\n";
                                        else cout << "movl\t" << $3 << ", \%eax\nmovl\t \%eax, " << find_offset($1) << "(%" << "ebp)\n";}
                                        else {if(local($3)) cout << "movl\t" << find_offset($3) << "(%" << "ebp), \%eax\nmovl\t \%eax,  " << $1 << "\n";
                                        else cout << "movl\t" << $3 << ", \%eax\nmovl\t \%eax, " << $1 << "\n";}}
            | IDENTIFIER EQ TEMP {if(local($1)) cout << "movl\t" << find_temp_offset($3) << "(%" << "ebp), \%eax\nmovl\t \%eax,  " << find_offset($1) << "(%" << "ebp)\n";
                                    else cout << "movl\t" << find_temp_offset($3) << "(%" << "ebp), \%eax\nmovl\t \%eax,  " << $1 << "\n";}
            | TEMP EQ TEMP {cout << "movl\t" << find_temp_offset($3) << "(%" << "ebp), \%eax\nmovl\t \%eax, " << find_temp_offset($1) << "(%" << "ebp)\n";}
            | TEMP EQ integer {cout << "movl\t$" << $3 << ", " << find_temp_offset($1) << "(%" << "ebp)\n";}
            | TEMP EQ IDENTIFIER {if(local($3)) cout << "movl\t" << find_offset($3) << "(%" << "ebp), \%eax\nmovl\t \%eax, " << find_temp_offset($1) << "(%" << "ebp)\n";
                                    else cout << "movl\t" << $3 << ", " << find_temp_offset($1) << "(%" << "ebp)\n";}
            | IDENTIFIER LRECT NUMBER RRECT EQ CHAR_EXP {
                string ss = string($1);
                if(info[cur_func]->chars.find(ss) != info[cur_func]->chars.end()){
                    cout << "movl\t" << "\%ebp, \%eax\n";
                    cout << "addl\t $" << $3 << ", \%eax\n";
                    cout << "movb\t$" << charval($6) << ", " << find_offset($1) << "(\%eax)\n";
                }
                else if(func_params.find(ss) != func_params.end()){
                    cout << "movl\t" << find_offset($1) << "(\%ebp), \%eax\n";
                    cout << "addl\t $" << $3 << ", \%eax\n";
                    cout << "movb\t$" << charval($6) << ", 0(\%eax)\n";
                } 
                else{
                    cout << "leal\t" << $1 << ", \%eax\n";
                    cout << "addl\t$" << $3 << ", \%eax\n";
                    cout << "movb\t$" << charval($6) << ", 0(\%eax)\n";
                }
            }
            | IDENTIFIER LRECT NUMBER RRECT EQ TEMP {
                string ss = string($1);
                if(info[cur_func]->chars.find(ss) != info[cur_func]->chars.end()){
                    cout << "movl\t\%ebp, \%eax\n";
                    cout << "addl\t $" << $3 << ", \%eax\n";
                    cout << "movb\t" << find_temp_offset($6) << "(\%ebp), \%dl\n";
                    cout << "movb\t\%dl, " << find_offset($1) << "(\%eax)\n";
                }
                else if(func_params.find(ss) != func_params.end()){
                    cout << "movl\t" << find_offset($1) << "(\%ebp), \%eax\n";
                    cout << "addl\t $" << $3 << ", \%eax\n";
                    cout << "movb\t" << find_temp_offset($6) << "(\%ebp), \%dl\n";
                    cout << "movb\t\%dl, " << "0(\%eax)\n";
                } 
                else{
                    cout << "leal\t" << $1 << ", \%eax\n";
                    cout << "addl\t $" << $3 << ", \%eax\n";
                    cout << "movb\t" << find_temp_offset($6) << "(\%ebp), \%dl\n";
                    cout << "movb\t\%dl, 0(\%eax)\n";
                }
            }
            | IDENTIFIER LRECT IDENTIFIER RRECT EQ CHAR_EXP {
                string ss = string($1);
                if(info[cur_func]->chars.find(ss) != info[cur_func]->chars.end()){
                    cout << "movl\t" <<  "\%ebp, \%eax\n";
                    if(local($3)) cout << "movl\t" << find_offset($3) << "(\%ebp), \%ebx\n"; else  cout << "movl\t" << $3 << ", \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t$" << charval($6) << ", " <<  find_offset($1) << "(\%eax)\n";
                }
                else if(func_params.find(ss) != func_params.end()){
                    if(local($3)) cout << "movl\t" << find_offset($3) << "(\%ebp), \%eax\n"; else cout << "movl\t" << $3 << ", \%eax\n";
                    cout << "movl\t" << find_offset($1) << "(\%ebp), \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t$" << charval($6) << ","<< "0(\%eax)\n"; 
                } 
                else{
                    cout << "leal\t" << $1 << ", \%eax\n";
                    if(local($3)) cout << "movl\t" << find_offset($3) << "(\%ebp), \%ebx\n"; else cout << "movl\t" << $3 << ", \%ebx\n"; 
                    cout << "addl\t \%ebx, \%eax\n";
                    cout << "movb\t$" << charval($6) << ", 0(\%eax)\n";
                }
            }
            | IDENTIFIER LRECT IDENTIFIER RRECT EQ TEMP {
                string ss = string($1);
                if(info[cur_func]->chars.find(ss) != info[cur_func]->chars.end()){
                    cout << "movl\t" << "\%ebp, \%eax\n";
                    if(local($3)) cout << "movl\t" << find_offset($3) << "(\%ebp), \%ebx\n"; else  cout << "movl\t" << $3 << ", \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t" << find_temp_offset($6) << "(\%ebp), \%dl\n";
                    cout << "movb\t\%dl, " << find_offset($1) << "(\%eax)\n";
                }
                else if(func_params.find(ss) != func_params.end()){
                    if(local($3)) cout << "movl\t" << find_offset($3) << "(\%ebp), \%eax\n"; else cout << "movl\t" << $3 << ", \%eax\n";
                    cout << "movl\t" << find_offset($1) << "(\%ebp), \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t" << find_temp_offset($6) << "(\%ebp), \%dl\n";
                    cout << "movb\t\%dl, 0(\%eax)\n";
                } 
                else{
                    cout << "leal\t" << $1 << ", \%eax\n";
                    if(local($3)) cout << "movl\t" << find_offset($3) << "(\%ebp), \%ebx\n"; else cout << "movl\t" << $3 << ", \%ebx\n"; 
                    cout << "addl\t \%ebx, \%eax\n";
                    cout << "movb\t" << find_temp_offset($6) << "(\%ebp), \%dl\n";
                    cout << "movb\t\%dl, 0(\%eax)\n";
                }
            }
            | IDENTIFIER LRECT TEMP RRECT EQ CHAR_EXP {
                string ss = string($1);
                if(info[cur_func]->chars.find(ss) != info[cur_func]->chars.end()){
                    cout << "movl\t" << "\%ebp, \%eax\n";
                    cout << "movl\t" << find_temp_offset($3) << "(\%ebp), \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t$" << charval($6) << ", " << find_offset($1) << "(\%eax)\n";
                }
                else if(func_params.find(ss) != func_params.end()){
                    cout << "movl\t" << find_temp_offset($3) << "(\%ebp), \%eax\n";
                    cout << "movl\t" << find_offset($1) << "(\%ebp), \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t$" << charval($6) << ",0(\%eax)\n"; 
                } 
                else{
                    cout << "leal\t" << $1 << ", \%eax\n";
                    cout << "movl\t" << find_temp_offset($3) << "(\%ebp), \%ebx\n"; 
                    cout << "addl\t \%ebx, \%eax\n";
                    cout << "movb\t$" << charval($6) << ", 0(\%eax)\n";
                }
            }
            | IDENTIFIER LRECT TEMP RRECT EQ TEMP {
                string ss = string($1);
                if(info[cur_func]->chars.find(ss) != info[cur_func]->chars.end()){
                    cout << "movl\t" << "\%ebp, \%eax\n";
                    cout << "movl\t" << find_temp_offset($3) << "(\%ebp), \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t" << find_temp_offset($6) << "(\%ebp), \%dl\n";
                    cout << "movb\t\%dl, " << find_offset($1) << "(\%eax)\n";
                }
                else if(func_params.find(ss) != func_params.end()){
                    cout << "movl\t" << find_temp_offset($3) << "(\%ebp), \%eax\n";
                    cout << "movl\t" << find_offset($1) << "(\%ebp), \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t" << find_temp_offset($6) << "(\%ebp), \%dl\n";
                    cout << "movb\t\%dl, 0(\%eax)\n";
                } 
                else{
                    cout << "leal\t" << $1 << ", \%eax\n";
                    cout << "movl\t" << find_temp_offset($3) << "(\%ebp), \%ebx\n"; 
                    cout << "addl\t \%ebx, \%eax\n";
                    cout << "movb\t" << find_temp_offset($6) << "(\%ebp), \%dl\n";
                    cout << "movb\t\%dl, 0(\%eax)\n";
                }
            }
            | TEMP EQ IDENTIFIER LRECT TEMP RRECT {
                string ss = string($3);
                if(info[cur_func]->chars.find(ss) != info[cur_func]->chars.end()){
                    cout << "movl\t" << "\%ebp, \%eax\n";
                    cout << "movl\t" << find_temp_offset($5) << "(\%ebp), \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t" << find_offset($3) << "(\%eax), \%dl\n";
                    cout << "movb\t\%dl, " << find_temp_offset($1) << "(\%ebp)\n";
                }
                else if(func_params.find(ss) != func_params.end()){
                    cout << "movl\t" << find_offset($3) << "(\%ebp), \%eax\n";
                    cout << "movl\t" << find_temp_offset($5) << "(\%ebp), \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t" << "0(\%eax), \%dl\n";
                    cout << "movb\t\%dl, " << find_temp_offset($1) << "(\%ebp)\n";
                } 
                else{
                    cout << "leal\t" << $3 << ", \%eax\n";
                    cout << "movl\t" << find_temp_offset($5) << "(\%ebp), \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t" << "0(\%eax), \%dl\n";
                    cout << "movb\t\%dl, " << find_temp_offset($1) << "(\%ebp)\n";
                }
            }
            | TEMP EQ IDENTIFIER LRECT IDENTIFIER RRECT {
                string ss = string($3);
                if(info[cur_func]->chars.find(ss) != info[cur_func]->chars.end()){
                    cout << "movl\t" << "\%ebp, \%eax\n";
                    if(local($5)) cout << "movl\t" << find_offset($5) << "(\%ebp), \%ebx\n"; else cout << "movl\t" << $5 << ", \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t" << find_offset($3) << "(\%eax), \%dl\n";
                    cout << "movb\t\%dl, " << find_temp_offset($1) << "(\%ebp)\n";
                }
                else if(func_params.find(ss) != func_params.end()){
                    cout << "movl\t" << find_offset($3) << "(\%ebp), \%eax\n";
                    if(local($5)) cout << "movl\t" << find_offset($5) << "(\%ebp), \%ebx\n"; else cout << "movl\t" << $5 << ", \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t" << "0(\%eax), \%dl\n";
                    cout << "movb\t\%dl, " << find_temp_offset($1) << "(\%ebp)\n";
                } 
                else{
                    cout << "leal\t" << $3 << ", \%eax\n";
                    if(local($5)) cout << "movl\t" << find_offset($5) << "(\%ebp), \%ebx\n"; else cout << "movl\t" << $5 << ", \%ebx\n";
                    cout << "addl\t" << "\%ebx, \%eax\n";
                    cout << "movb\t" << "0(\%eax), \%dl\n";
                    cout << "movb\t\%dl, " << find_temp_offset($1) << "(\%ebp)\n";
                }
            }
            | TEMP EQ IDENTIFIER LRECT NUMBER RRECT {
                string ss = string($3);
                if(info[cur_func]->chars.find(ss) != info[cur_func]->chars.end()){
                    cout << "movl\t" << "\%ebp, \%eax\n";
                    cout << "addl\t$" << $5 << ",\%eax\n";
                    cout << "movb\t" << find_offset($3) << "(\%eax), \%dl\n";
                    cout << "movb\t\%dl, " << find_temp_offset($1) << "(\%ebp)\n";
                }
                else if(func_params.find(ss) != func_params.end()){
                    cout << "movl\t" << find_offset($3) << "(\%ebp), \%eax\n";
                    cout << "addl\t$" << $5 << ", \%eax\n";
                    cout << "movb\t" << "0(\%eax), \%dl\n";
                    cout << "movb\t\%dl, " << find_temp_offset($1) << "(\%ebp)\n";
                } 
                else{
                    cout << "leal\t" << $3 << ", \%eax\n";
                    cout << "addl\t$" << $5 << ", \%eax\n";
                    cout << "movb\t" << "0(\%eax), \%dl\n";
                    cout << "movb\t\%dl, " << find_temp_offset($1) << "(\%ebp)\n";
                }
            }
            | IDENTIFIER EQ PARAM {param_handler(string($1), $3-1);}
            | IDENTIFIER EQ RETVAL {if(local($1)) cout << "movl\t\%eax" << ", " << find_offset($1) << "(%" << "ebp)\n"; else cout  << "movl\t\%eax" << ", " << $1 << "\n";}
            | TEMP EQ RETVAL {cout << "movl\t\%eax" << ", " << find_temp_offset($1) << "(%" << "ebp)\n";}
            ;

notting: TEMP EQ NOT TEMP {flip();}
        ;

jump: GOTO LABEL {cout << "jmp\tL" << $2 << endl;}
        ;

condition: integer rel integer {cout << "movl\t$" << $1 << ", %" << "eax\ncmpl\t$" << $3 << ", %" << "eax\n";}
         | IDENTIFIER rel integer {cout << "movl\t" << find_offset($1) << "(%" << "ebp), %" << "eax\ncmpl\t$" << $3 << ", %" << "eax\n";}
         | integer rel IDENTIFIER {cout << "movl\t$" << $1 << ", %" << "eax\ncmpl\t" << find_offset($3) << "(%" << "ebp), %" << "eax\n";}
         | TEMP rel integer {cout << "movl\t" << find_temp_offset($1) << "(%" << "ebp), %" << "eax\ncmpl\t$" << $3 << ", %" << "eax\n";}
         | TEMP rel TEMP {cout << "movl\t" << find_temp_offset($1) << "(%" << "ebp), %" << "eax\ncmpl\t" << find_temp_offset($3) << "(%" << "ebp), %" << "eax\n";}
         | TEMP rel IDENTIFIER {cout << "movl\t" << find_temp_offset($1) << "(%" << "ebp), %" << "eax\ncmpl\t" << find_offset($3) << "(%" << "ebp), %" << "eax\n";}
         | IDENTIFIER rel TEMP {cout << "movl\t" << find_offset($1) << "(%" << "ebp), %" << "eax\ncmpl\t" << find_temp_offset($3) << "(%" << "ebp), %" << "eax\n";}
         | IDENTIFIER rel IDENTIFIER {cout << "movl\t" << find_offset($1) << "(%" << "ebp), %" << "eax\ncmpl\t" << find_offset($3) << "(%" << "ebp), %" << "eax\n";}
         | integer rel TEMP {cout << "movl\t$" << $1 << ", %" << "eax\ncmpl\t" << find_temp_offset($3) << "(%" << "ebp), %" << "eax\n";}
         ;

cond_jump: TEMP EQ condition IF LPAREN TEMP RPAREN GOTO LABEL {cout << rel << "\t L" << $9 << endl;} 
        | TEMP EQ condition notting IF LPAREN TEMP RPAREN GOTO LABEL {cout << rel << "\t L" << $10 << endl;} 
    ;

rel: EQUALCHECK {rel = "je";}
    | LESSER {rel = "jl";}
    | GREATER {{rel = "jg";}}
    | GEQ {rel = "jge";}
    | LEQ {rel = "jle";}
    | NEQ {rel = "jne";}
    ;

ope: ADD {op = "addl";}
    | SUB {op = "subl";}
    | MUL {op = "imull";}
    ;

lines: lines line 
      | line
        ;

line: alu 
    | alu_div
     | label_helper
     | cond_jump
     | jump
     | assignment 
     | function_call
    ;

label_helper: LABEL COLON {cout << "L" << $1 << ":" << endl;}

return_stmt: RETVAL EQ integer RETURN {cout << "movl\t$" << $3 << ", %" << "eax\n"; cout << "leave\nret\n";}
        | RETVAL EQ TEMP RETURN {cout << "movl\t" << find_temp_offset($3) << "(%" << "ebp) , %" << "eax\n"; cout << "leave\nret\n";}
        | RETVAL EQ IDENTIFIER RETURN {if(local($3)) cout << "movl\t" << find_offset($3) << "(%" << "ebp) , %" << "eax\n"; else cout << "movl\t" << $3 << ", \%eax\n"; cout << "leave\nret\n";}
        ;

integer: NUMBER {$$ = $1;}
        | SUB NUMBER {$$ = -$2;}
        ;

%%

void yyerror(const char* s) {
    printf("%s\n", s);
    exit(1);
}
    
int main(){
    process_info();
    write_global();
    cout << ".text\n";
    yyparse();
    write_data();
    return 0;
}