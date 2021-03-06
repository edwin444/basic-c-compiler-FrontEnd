%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "table.h"

table ** constant_table;

int yylex(void);
void yyerror(char *);
void check_type(int, int);
void append_global_args_encoding(char);
char mapper_datatype(int);
char *string_rev(char *);


// links scanner code  
#include "lex.yy.c"

int isFunc = 0;
int isDecl = 0;
int curr_datatype;

int func_return_type;

int flag_args = 0;
char global_args_encoding[500] = {'\0'};
int args_encoding_idx = 0;
%}

%union {
	char * str;
	table * table_ptr;
	int datatype;
};

// TOKEN DECLARATION

%token <str> IDENTIFIER 

// keywords
%token IF ELSE ELSE_IF FOR WHILE CONTINUE BREAK RETURN

// data types
%token INT SHORT LONG_LONG LONG CHAR SIGNED UNSIGNED FLOAT DOUBLE VOID

// logical opertors
%token BITWISE_AND BITWISE_OR LOGICAL_AND LOGICAL_OR LOGICAL_NOT

// relational operators
%token EQUALS LESS_THAN GREATER_THAN NOT_EQUAL LESS_THAN_EQUAL_TO GREATER_THAN_EQUAL_TO

// constants
%token <table_ptr> INT_CONST STRING_CONST HEX_CONST REAL_CONST CHAR_CONST

// types
%left ','
%right '='
%left LOGICAL_AND
%left LOGICAL_OR 
%left '|'
%left '^'
%left '&'
%left EQUALS NOT_EQUAL
%left '>' '<' LESS_THAN_EQUAL_TO GREATER_THAN_EQUAL_TO
%left ">>" "<<" 
%left '+' '-'
%left '*' '/' '%'
%right '!'
%left '(' ')' '[' ']'

%type <table_ptr> identifier
%type <datatype> arithmetic_expression
%type <datatype> comparison_expression
%type <table_ptr> array


%start begin

%%

/* init production */
begin: 
	begin unit 
	| unit
	;
/* unit derives declaration statements and function blocks */
unit: 
	function
	| declaration
	;


/* Production rule for functions */
function: 
	type		
	identifier	{isDecl = 0; $2->is_func = 1; func_return_type = curr_datatype;}					 
	'(' 		{current_scope_ptr = create_scope(); isFunc = 1; flag_args = 1; args_encoding_idx = 0; global_args_encoding[args_encoding_idx++] = '$';}
	argument_list
	')' 	{isDecl = 0; if (args_encoding_idx > 1) {global_args_encoding[args_encoding_idx++] = '\0'; insert_args_encoding($2, global_args_encoding); args_encoding_idx = 0; flag_args = 0;}}
	block 
	;

/* Production rule for argument list */
argument_list:
	arguments 
	| 
	;
arguments:
	type identifier	
	| type identifier ',' arguments 
	;


/* Production rule for sign or type specifiers */
type: 
	type_specifier	{isDecl = 1;} 
	| sign_specifier type_specifier {isDecl = 1;} 
	;
/* Production rule sign specifiers */
sign_specifier: 
	UNSIGNED
	| SIGNED
	;
/* Production rule data types */
type_specifier: 
	INT	{curr_datatype = INT; append_global_args_encoding('i');}
	| SHORT {curr_datatype = SHORT; append_global_args_encoding('s');}
	| LONG_LONG {curr_datatype = LONG_LONG; append_global_args_encoding('L');}
	| LONG {curr_datatype = LONG; append_global_args_encoding('l');}
	| CHAR {curr_datatype = CHAR; append_global_args_encoding('i');}
	| FLOAT {curr_datatype = FLOAT; append_global_args_encoding('f');}
	| DOUBLE {curr_datatype = DOUBLE; append_global_args_encoding('d');}
	| VOID {curr_datatype = VOID; append_global_args_encoding('v');}
	;


/* production rule for block of code or scope */
block:
		'{'		{if (!isFunc) current_scope_ptr =  create_scope(); isFunc = 0;} 
		segments
		'}'		{current_scope_ptr =  exit_scope();}
	;
segments: 
	segments segment
	|
	;


/* production rule for a C segment */
segment: 
	if_segment 
	| for_segment
	| while_segment
	| func_call
	| declaration
	| expression
	| CONTINUE ';'
	| BREAK ';'
	| RETURN ';' {if (VOID != func_return_type) yyerror("Incorrect return type");}
	| RETURN arithmetic_expression ';'	{if ($2 != func_return_type) yyerror("Incorrect return type");}
	| block
	;

/* if else-if production */
if_segment: 
	IF '(' arithmetic_expression ')' block 
	| IF '(' arithmetic_expression ')' block ELSE block
	| IF '(' arithmetic_expression ')' block else_if_segment 
	;
else_if_segment:
	ELSE_IF '(' arithmetic_expression ')' block else_ifs ELSE block
	;
else_ifs:
	ELSE_IF '(' arithmetic_expression ')' block else_ifs
	|
	;

/* for segment production */
for_segment:
	FOR '(' expression arithmetic_expression ';' assignment_expression ')' block {check_type($4, INT);}
	;

/* while segment production */
while_segment:
	WHILE '(' arithmetic_expression ')' block {check_type($3, INT);}
	;

/* Function call */ 
func_call:
	identifier '=' identifier '(' parameter_list ')' ';' {if ($3->is_func == 0 || (recursiveSearch(current_scope_ptr, $3->lexeme) == NULL)) yyerror("Invalid function call");}
	| type identifier '=' identifier '(' parameter_list ')' ';' {if ($4->is_func == 0 || (recursiveSearch(current_scope_ptr, $4->lexeme) == NULL)) yyerror("Invalid function call");}
	| identifier 
		'('	{flag_args = 1; args_encoding_idx = 0; global_args_encoding[args_encoding_idx++] = '$';} 
		parameter_list
		')' 
		';' {	table *ptr = recursiveSearch(current_scope_ptr, $1->lexeme);
				if (args_encoding_idx > 1) {global_args_encoding[args_encoding_idx++] = '\0'; flag_args = 0;}
				// printf("\n\n\n%s\n\n\n", global_args_encoding);
				if ($1->is_func == 0 || (ptr == NULL)) {
					yyerror("Invalid function call");
				}
				else if (ptr->args_encoding == NULL && args_encoding_idx == 1) { 
				} 
				else if (strcmp(ptr->args_encoding, string_rev(global_args_encoding)) != 0) {
					yyerror("Invalid function call, Arguments mismatch");
				}	
			}
	;
parameter_list: 
	parameters
	|
	;
parameters: 
	arithmetic_expression ',' parameters {append_global_args_encoding(mapper_datatype($1));}
	| arithmetic_expression {append_global_args_encoding(mapper_datatype($1));}
	;


/* declaration statements */
declaration:
	type identifier identifier_lists ';' {isDecl = 0;}
	| type array identifier_lists ';'	{isDecl = 0;}
	;
identifier_lists:
	',' identifier identifier_lists
	| ',' array
	|
	;


/*arithmetic expression production rules*/
arithmetic_expression: 
	arithmetic_expression '+' arithmetic_expression	{check_type($1, $3); $$ = $1;}
	| arithmetic_expression '-' arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression '*' arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression '/' arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression '^' arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression '%' arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression LOGICAL_AND arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression LOGICAL_OR arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression '&' arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression '|' arithmetic_expression {check_type($1, $3); $$ = $1;}
	| '(' arithmetic_expression ')'	{$$ = $2;} 
	| '!' arithmetic_expression	{$$ = $2;}
	| identifier	{$$ = $1->data_type;}
	| HEX_CONST		{$$ = $1->data_type;}
	| INT_CONST 	{$$ = $1->data_type;}
	| REAL_CONST	{$$ = $1->data_type;}
	| CHAR_CONST	{$$ = $1->data_type;}
	| array	{$$ = $1->data_type;}
	| comparison_expression {$$ = $1;}
	;
comparison_expression:
	arithmetic_expression GREATER_THAN_EQUAL_TO arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression LESS_THAN_EQUAL_TO arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression EQUALS arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression NOT_EQUAL arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression '<' arithmetic_expression {check_type($1, $3); $$ = $1;}
	| arithmetic_expression '>' arithmetic_expression {check_type($1, $3); $$ = $1;}
	;
/*production rules for assignment expression*/
assignment_expression:
	identifier '=' arithmetic_expression
	| array '=' arithmetic_expression
	;
expression:
	assignment_expression ';'
	;


array:
	identifier '[' INT_CONST ']'	{	if (isDecl) {
											if (atoi($3->lexeme) < 1) yyerror("Array size less than 1");
											if ($1 != NULL) $1->dimension = atoi($3->lexeme);
											$$ = $1;
										}
										else {
											if ($1->dimension != 0 && ($1->dimension <= atoi($3->lexeme)|| atoi($3->lexeme) < 0)) 
											{yyerror("Out of bounds");}	
										}
									}
	;

identifier: 
	IDENTIFIER	{	if (isDecl) {
						table * ptr = insert(scope_table[current_scope_ptr].header, $1, IDENTIFIER, curr_datatype);
						if (ptr == NULL) {
							yyerror("Redeclaration of a variable");
							exit(0);
						}
						else {
							$$ = ptr;
						}
						
					}
					else {
						// $$ = search(scope_table[current_scope_ptr].header, $1);
						$$ = recursiveSearch(current_scope_ptr, $1);
						if($$ == NULL) {
							yyerror("Variable not declared");
							exit(0);
						}
					}
				}
	;
%%


int main () {
	init();
	constant_table = create_table();
	scope_table[0].header = create_table();
	scope_table[0].parent = -1;
    yyparse();
    display_scope_table();
	display_const_table(constant_table);
    return 0;
}

void yyerror(char *s) { 
    fprintf(stderr, "Line %d: %s\n", yylineno, s); 
	
}

void check_type(int a, int b) {
	if (a != b) {
		yyerror("Type Mismatch");
	}
}

void append_global_args_encoding(char i) {
	if(flag_args == 1) {
		global_args_encoding[args_encoding_idx++] = i;
		global_args_encoding[args_encoding_idx++] = '$';
	}
}

char mapper_datatype(int datatype) {
	switch(datatype) {
		case INT:
			return 'i';
		case SHORT:
			return 's';
		case LONG_LONG:
			return 'L';
		case LONG:
			return 'l';
		case CHAR:
			return 'i';
		case FLOAT:
			return 'f';
		case DOUBLE:
			return 'd';
		case VOID:
			return 'v';
	}
}

char *string_rev(char *str)
{
      char *p1, *p2;

      if (! str || ! *str)
            return str;
      for (p1 = str, p2 = str + strlen(str) - 1; p2 > p1; ++p1, --p2)
      {
            *p1 ^= *p2;
            *p2 ^= *p1;
            *p1 ^= *p2;
      }
      return str;
}