/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr = string_buf;

/*
 * Flags used as state
 */
int LayerComment = 0;
bool errorInString = false;


 int getStringLen()
 {
   return string_buf_ptr - string_buf ;
 }

 bool bufOverflow()
 {
   return getStringLen()+strlen(yytext) >= MAX_STR_CONST;
 }


%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
ARROW           <-
LE              <=
WS   [ \t\f\r\v]+
DIGIT  [0-9]

/*
 * State definition
 */
%Start COMMENT
%Start STRING
%Start ESCAPE


%%

  /*
   *  String constants (C syntax)
   *  Escape sequence \c is accepted for all characters c. Except for 
   *  \n \t \b \f, the result is c.
   */
<INITIAL>\"     { 
                  BEGIN STRING; 
                  errorInString = false;
                }
<STRING>\\   { BEGIN ESCAPE; }

<STRING><<EOF>> {
                  errorInString = true;
                  BEGIN 0;
                  cool_yylval.error_msg = "EOF in string constant";
                  return ERROR;
                }

<STRING>\0  {
              errorInString = true;
              if (bufOverflow())
              {
                cool_yylval.error_msg = "String constant too long";
                return ERROR;
              }
              cool_yylval.error_msg = "String contains null character";
              return ERROR; 
            }

<STRING>\n  {  
              BEGIN 0;
              if(!errorInString)
              {
                errorInString = true;
                curr_lineno++;
                if (bufOverflow())
                {
                  cool_yylval.error_msg = "String constant too long";
                  return ERROR;
                }
                cool_yylval.error_msg = "Unterminated string constant";
                string_buf_ptr = string_buf;
                return ERROR;
              }
            }

<STRING>\"  {
              BEGIN 0;
              int stringLen = getStringLen();
              string_buf_ptr = string_buf;
              if (!errorInString)
              {
                string_buf[stringLen] = '\0';
                cool_yylval.symbol = stringtable.add_string(string_buf, stringLen);
                return STR_CONST;
              }
            }

<STRING>[^\n\0\\"]+   {
              if (bufOverflow())
              {
                errorInString = true;
                cool_yylval.error_msg = "String constant too long";
                return ERROR;
              }

              strcpy(string_buf_ptr, yytext);
              string_buf_ptr += strlen(yytext);
            }

<ESCAPE>[btnf]  {
                  BEGIN STRING;
                  if (bufOverflow())
                  {
                    errorInString = true;
                    cool_yylval.error_msg = "String constant too long";
                    return ERROR;
                  }

                  switch (yytext[0])
                  {
                    case 'b': *string_buf_ptr = '\b'; break;
                    case 't': *string_buf_ptr = '\t'; break;
                    case 'n': *string_buf_ptr = '\n'; break;
                    case 'f': *string_buf_ptr = '\f'; break;
                  }

                  string_buf_ptr++;
                }

<ESCAPE>\0  {
              BEGIN STRING;
              errorInString = true;
              if (bufOverflow())
              {
                cool_yylval.error_msg = "String constant too long";
                return ERROR;
              }
              cool_yylval.error_msg = "String contains null character";
              return ERROR; 
            }

<ESCAPE>[^btnf\0]   { 
              BEGIN STRING;
              if (yytext[0] == '\n')
              {
                curr_lineno++;
              }
              if (bufOverflow())
              {
                errorInString = true;
                cool_yylval.error_msg = "String constant too long";
                return ERROR;
              }

              *string_buf_ptr = yytext[0];
              string_buf_ptr++;
            }


  /*
   * Single line comments
   */

<INITIAL>--.*       ;
		 
  /*
   *  Nested comments
   */
"(*"  {
        if (LayerComment == 0)
        {
          BEGIN COMMENT; 
        }
        ++LayerComment; 
      }

"*)"    {
          if (LayerComment == 0)
          {
            cool_yylval.error_msg = "Unmatched *)";
            return ERROR;
          }
          else
          {
            --LayerComment;
            if (LayerComment == 0)
            {
              BEGIN 0;
            }
          }
        }

<COMMENT>[^(*\n]+   ;
<COMMENT>\(       ;
<COMMENT>\*      ;

  /*
   * EOF
   */
<COMMENT><<EOF>>    {
                      BEGIN 0;
                      cool_yylval.error_msg = "EOF in comment";
                      return ERROR;
                    }

  /*
   * Keywords are case-insensitive except for the values true and false,
   * which must begin with a lower-case letter.
   */

<INITIAL>[cC][lL][aA][sS][sS]     { return CLASS; }
<INITIAL>[eE][lL][sS][eE]      { return ELSE; }
<INITIAL>[fF][iI]        { return FI; }
<INITIAL>[iI][fF]        { return IF; }
<INITIAL>[iI][nN]        { return IN; }
<INITIAL>[iI][nN][hH][eE][rR][iI][tT][sS]  { return INHERITS; }
<INITIAL>[iI][sS][vV][oO][iI][dD]    { return ISVOID; }
<INITIAL>[lL][eE][tT]       { return LET; }
<INITIAL>[lL][oO][oO][pP]      { return LOOP; }
<INITIAL>[pP][oO][oO][lL]      { return POOL; }
<INITIAL>[tT][hH][eE][nN]      { return THEN; }
<INITIAL>[wW][hH][iI][lL][eE]     { return WHILE; }
<INITIAL>[cC][aA][sS][eE]      { return CASE; }
<INITIAL>[eE][sS][aA][cC]      { return ESAC; }
<INITIAL>[nN][eE][wW]       { return NEW; }
<INITIAL>[oO][fF]        { return OF; }
<INITIAL>[nN][oO][tT]       { return NOT; }
<INITIAL>t[rR][uU][eE]      {
        cool_yylval.boolean = true;
        return BOOL_CONST;
      } 
<INITIAL>f[aA][lL][sS][eE]     { 
            cool_yylval.boolean = false;
            return BOOL_CONST; 
          } 


  /*
   * Integers
   */
<INITIAL>{DIGIT}+  {
            cool_yylval.symbol = inttable.add_string(yytext);
            return INT_CONST;
          }

  /*
   * Object identifiers
   */
<INITIAL>[a-z][0-9a-zA-Z_]*  {
                      cool_yylval.symbol = idtable.add_string(yytext);
                      return OBJECTID;
                    }

  /*
   * Type identifiers
   */
<INITIAL>[A-Z][0-9a-zA-Z_]*  {
                      cool_yylval.symbol = idtable.add_string(yytext);
                      return TYPEID;
                    }
                    

  /*
   * self and selftype are treated as normal identifier in this phase
   */

  /*
   *  The single-character operators.
   */
[-+*/.@~<={}():;,]     { return yytext[0]; }



  /*
   *  The multiple-character operators.
   */
<INITIAL>{DARROW}		{ return DARROW; }
<INITIAL>{ARROW}     { return ASSIGN; }
<INITIAL>{LE}        { return LE; }


  /*
   * New lines and white spaces
   */ 
\n			{ curr_lineno++;}		 
{WS}+       ;	


  /*
   * Unrecognized character
   */
.     {
        cool_yylval.error_msg = yytext;
        return ERROR;
      }
%%