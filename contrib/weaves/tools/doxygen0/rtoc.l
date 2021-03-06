/*
 * Permission to use, copy, modify, and distribute this software and its
 * documentation under the terms of the GNU General Public License is hereby 
 * granted. No representations are made about the suitability of this software 
 * for any purpose. It is provided "as is" without express or implied warranty.
 * See the GNU General Public License for more details.
 *
 * Ian Martins (ianxm@jhu.edu)
 */

%option debug

	int inCommentLine = 0;			/* in comment line */
	int comment_caller;
	char* yycopy = 0;
	void closeCommentBlock();
ID	[.a-zA-Z][0-9a-zA-Z_.]*
WS	[ \t]*
DEF     (<-)|(=)

%s func funcDef paramList commentBlock
%%

<func>"##"	{				/* end last function */
		  comment_caller = YY_START;
		  fprintf(yyout,"/**");	        /* start new one */
		  BEGIN(commentBlock);
		  inCommentLine = 1;		/* start of comment */
		}

<commentBlock>"##"		{
		  fprintf(yyout,"*/\n/**");	/* close old comment, start new one */
		  inCommentLine = 1;		/* start of comment */
		}

"##"		{				/* first token */
		  comment_caller = YY_START;
		  BEGIN(commentBlock);
		  fprintf(yyout,"/**");
		  inCommentLine = 1;		/* start of comment */
		}

<commentBlock>"#"	{
		  if (inCommentLine)		/* just a symbol in a comment */
		    ECHO;
		  else 				/* part of current comment block */
		  {
		    fprintf(yyout,"*");
		    inCommentLine = 1;
		  }
		}

"#"		{				/* start comment block */
		  fprintf(yyout,"/*");
		  comment_caller = YY_START;
		  BEGIN(commentBlock);
		  inCommentLine = 1;		/* start of comment */
		}

\n		ECHO; inCommentLine = 0;

^({ID}|\"{ID}\") {
		 char *s;
		  if (yycopy) free(yycopy);
		  yycopy = strdup( yytext );

		  if ( (s = strchr(yycopy, '"')) ) *s = ' ';
		  if ( (s = strrchr(yycopy, '"')) ) *s = ' ';
		}

{WS}{DEF}{WS}function {	
		  closeCommentBlock(); 
		  fprintf(yyout,"rets %s", yycopy);
		  BEGIN(funcDef);
		}

<funcDef>\(	{
		  ECHO;
		  BEGIN(paramList);
		}
<paramList>\)	{
		  ECHO;
		  /* fprintf(yyout,"{\n"); */
		  BEGIN(func);
		}
<paramList>{ID}	{
		  fprintf(yyout,"type ");
		  ECHO;
		}
<commentBlock>[0-9a-zA-Z]+	{
		  closeCommentBlock();
		  ECHO;
		}
[0-9a-zA-Z]+	{
		  ECHO;
		}
<<EOF>>		{
		  /* fprintf(yyout,"}\n"); */
		  return(0);
		}

%%

void closeCommentBlock()			/* end comment block */
{
  if (!inCommentLine)
  {
    fprintf(yyout,"*/\n");
    BEGIN(comment_caller);
  }
}

