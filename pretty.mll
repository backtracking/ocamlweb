(*
 * ocamlweb - A WEB-like tool for ocaml
 * Copyright (C) 1999 Jean-Christophe FILLIATRE
 * 
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation.
 * 
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 * See the GNU General Public License version 2 for more details
 * (enclosed in the file GPL).
 *)

(* $Id$ *)

{

  open Printf
  open Output

  let comment_depth = ref 0

  let bracket_depth = ref 0

  let first_char lexbuf = Lexing.lexeme_char lexbuf 0

  let count_spaces s =
    let c = ref 0 in
    for i = 0 to String.length s - 1 do
      if s.[i] = '\t' then
	c := !c + (8 - (!c mod 8))
      else
	incr c
    done;
    !c

  let user_math_mode = ref false

  let user_math () =
    if not !user_math_mode then begin
      user_math_mode := true;
      enter_math ()
    end else begin
      user_math_mode := false;
      leave_math ()
    end

  let check_user_math s =
    if !user_math_mode then output_string s else output_string ("\\"^s)

}

let space = [' ' '\t']
let lowercase = ['a'-'z' '\223'-'\246' '\248'-'\255' '_']
let uppercase = ['A'-'Z' '\192'-'\214' '\216'-'\222']
let identchar = 
  ['A'-'Z' 'a'-'z' '_' '\192'-'\214' '\216'-'\246' '\248'-'\255' '\'' '0'-'9']
let identifier = (lowercase | uppercase) identchar*
let latex_special = 
    ' ' | '^' | '%' | '&' | '$' | '{' | '}'  (* TeX reserved chars *)
  | '*' | "->" | "<-" | "<=" | ">=" | "<>"   (* math symbols *)

(************************************************************************)
(* CODE                                                                 *)
(************************************************************************)

(* pretty-print of code, at beginning of line... *)
rule pr_code = parse
  | space* { let n = count_spaces (Lexing.lexeme lexbuf) in indentation n;
	     pr_code_inside lexbuf; pr_code lexbuf }
  | eof    { leave_math () }
   
(* ...and inside the line *)
and pr_code_inside = parse
  | '\n' { () }
  | identifier
         { output_ident (Lexing.lexeme lexbuf); pr_code_inside lexbuf }
  | "(*" { output_bc (); comment_depth := 1;
	   pr_comment lexbuf; pr_code_inside lexbuf }
  | latex_special  
         { output_latex_special (Lexing.lexeme lexbuf); pr_code_inside lexbuf }
  | eof  { () }
  | _    { output_char (first_char lexbuf); pr_code_inside lexbuf }

(* comments *)
and pr_comment = parse
  | "(*" { output_bc (); incr comment_depth; pr_comment lexbuf }
  | "*)" { output_ec (); decr comment_depth;
           if !comment_depth > 0 then pr_comment lexbuf }
  | '['  { bracket_depth := 1; escaped_code lexbuf; pr_comment lexbuf }
  | eof  { () }
  | '$'  { user_math(); pr_comment lexbuf }
  | '_' | '^' { check_user_math (Lexing.lexeme lexbuf); pr_comment lexbuf }
  | _    { output_char (first_char lexbuf); pr_comment lexbuf }

(* escaped code *)
and escaped_code = parse
  | '[' { output_char '['; incr bracket_depth; escaped_code lexbuf }
  | ']' { decr bracket_depth; 
	  if !bracket_depth > 0 then begin
	    output_char ']'; escaped_code lexbuf
          end else
	    if not !user_math_mode then leave_math () }
  | identifier
         { output_ident (Lexing.lexeme lexbuf); escaped_code lexbuf }
  | latex_special  
         { output_latex_special (Lexing.lexeme lexbuf); escaped_code lexbuf }
  | eof  { if not !user_math_mode then leave_math () }
  | _    { output_char (first_char lexbuf); escaped_code lexbuf }


(************************************************************************)
(* DOCUMENTATION                                                        *)
(************************************************************************)

(* pretty-print of documentation (output `as it', except for quotations *)
and pr_doc = parse
  | '[' { bracket_depth := 1; escaped_code lexbuf; pr_doc lexbuf }
  | '$' { user_math(); pr_doc lexbuf }
  | '_' | '^' { check_user_math (Lexing.lexeme lexbuf); pr_doc lexbuf }
  | eof { () }
  | _   { output_char (first_char lexbuf); pr_doc lexbuf }

{

  let pretty_print_code s =
    reset_pretty ();
    pr_code (Lexing.from_string s)

  let pretty_print_doc s =
    pr_doc (Lexing.from_string s)

}