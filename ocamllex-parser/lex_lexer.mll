(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

(* $Id$ *)

(* The lexical analyzer for lexer definitions. Bootstrapped! *)

{
open Lex_syntax
open Lex_parser

(* Auxiliaries for the lexical analyzer *)

let brace_depth = ref 0
and comment_depth = ref 0

exception Lexical_error of string * int * int

let string_buffer = Buffer.create 256
let reset_string_buffer () = Buffer.reset string_buffer
let store_string_char c = Buffer.add_char string_buffer c
let get_stored_string () = Buffer.contents string_buffer

let char_for_backslash = function
    'n' -> '\n'
  | 't' -> '\t'
  | 'b' -> '\b'
  | 'r' -> '\r'
  | c   -> c

let char_for_decimal_code lexbuf i =
  Char.chr(100 * (Char.code(Lexing.lexeme_char lexbuf i) - 48) +
               10 * (Char.code(Lexing.lexeme_char lexbuf (i+1)) - 48) +
                    (Char.code(Lexing.lexeme_char lexbuf (i+2)) - 48))

let line_num = ref 1
let line_start_pos = ref 0

let handle_lexical_error fn lexbuf =
  let line = !line_num
  and column = Lexing.lexeme_start lexbuf - !line_start_pos in
  try
    fn lexbuf
  with Lexical_error(msg, _, _) ->
    raise(Lexical_error(msg, line, column))

let cur_loc lexbuf =
  { start_pos = Lexing.lexeme_start_p lexbuf;
    end_pos = Lexing.lexeme_end_p lexbuf;
    start_line = !line_num;
    start_col = Lexing.lexeme_start lexbuf - !line_start_pos }

}

rule main = parse
    [' ' '\013' '\009' '\012' ] +
    { main lexbuf }
  | '\010'
    { line_start_pos := Lexing.lexeme_end lexbuf;
      incr line_num;
      main lexbuf }
  | "(*"
    { comment_depth := 1;
      handle_lexical_error comment lexbuf;
      main lexbuf }
  | ['A'-'Z' 'a'-'z'] ['A'-'Z' 'a'-'z' '\'' '_' '0'-'9'] *
    { match Lexing.lexeme lexbuf with
        "rule" -> Trule
      | "parse" -> Tparse
      | "and" -> Tand
      | "eof" -> Teof
      | "let" -> Tlet
      | s ->
	  let l = cur_loc lexbuf in
	  (*i
	  Printf.eprintf "ident '%s' occurs at (%d,%d)\n"
	    s l.start_pos l.end_pos;
	  i*)
	  Tident (s,l) }
  | '"'
    { reset_string_buffer();
      handle_lexical_error string lexbuf;
      Tstring(get_stored_string()) }
  | "'" [^ '\\'] "'"
    { Tchar(Char.code(Lexing.lexeme_char lexbuf 1)) }
  | "'" '\\' ['\\' '\'' 'n' 't' 'b' 'r'] "'"
    { Tchar(Char.code(char_for_backslash (Lexing.lexeme_char lexbuf 2))) }
  | "'" '\\' ['0'-'9'] ['0'-'9'] ['0'-'9'] "'"
    { Tchar(Char.code(char_for_decimal_code lexbuf 2)) }
  | '{'
    { let n1 = Lexing.lexeme_end_p lexbuf
      and l1 = !line_num
      and s1 = !line_start_pos in
      brace_depth := 1;
      let n2 = handle_lexical_error action lexbuf in
      Taction({start_pos = n1; end_pos = n2;
               start_line = l1; start_col = n1.Lexing.pos_cnum - s1}) }
  | '='  { Tequal }
  | '|'  { Tor }
  | '_'  { Tunderscore }
  | '['  { Tlbracket }
  | ']'  { Trbracket }
  | '*'  { Tstar }
  | '?'  { Tmaybe }
  | '+'  { Tplus }
  | '('  { Tlparen }
  | ')'  { Trparen }
  | '^'  { Tcaret }
  | '-'  { Tdash }
  | eof  { Tend }
  | _
    { raise(Lexical_error
             ("illegal character " ^ String.escaped(Lexing.lexeme lexbuf),
              !line_num, Lexing.lexeme_start lexbuf - !line_start_pos)) }

and action = parse
    '{'
    { incr brace_depth;
      action lexbuf }
  | '}'
    { decr brace_depth;
      if !brace_depth = 0 then Lexing.lexeme_start_p lexbuf else action lexbuf }
  | '"'
    { reset_string_buffer();
      string lexbuf;
      reset_string_buffer();
      action lexbuf }
  | "'" [^ '\\'] "'"
    { action lexbuf }
  | "'" '\\' ['\\' '\'' 'n' 't' 'b' 'r'] "'"
    { action lexbuf }
  | "'" '\\' ['0'-'9'] ['0'-'9'] ['0'-'9'] "'"
    { action lexbuf }
  | "(*"
    { comment_depth := 1;
      comment lexbuf;
      action lexbuf }
  | eof
    { raise (Lexical_error("unterminated action", 0, 0)) }
  | '\010'
    { line_start_pos := Lexing.lexeme_end lexbuf;
      incr line_num;
      action lexbuf }
  | _
    { action lexbuf }

and string = parse
    '"'
    { () }
  | '\\' [' ' '\013' '\009' '\012'] * '\010' [' ' '\013' '\009' '\012'] *
    { line_start_pos := Lexing.lexeme_end lexbuf;
      incr line_num;
      string lexbuf }
  | '\\' ['\\' '"' 'n' 't' 'b' 'r']
    { store_string_char(char_for_backslash(Lexing.lexeme_char lexbuf 1));
      string lexbuf }
  | '\\' ['0'-'9'] ['0'-'9'] ['0'-'9']
    { store_string_char(char_for_decimal_code lexbuf 1);
      string lexbuf }
  | eof
    { raise(Lexical_error("unterminated string", 0, 0)) }
  | '\010'
    { store_string_char '\010';
      line_start_pos := Lexing.lexeme_end lexbuf;
      incr line_num;
      string lexbuf }
  | _
    { store_string_char(Lexing.lexeme_char lexbuf 0);
      string lexbuf }

and comment = parse
    "(*"
    { incr comment_depth; comment lexbuf }
  | "*)"
    { decr comment_depth;
      if !comment_depth = 0 then () else comment lexbuf }
  | '"'
    { reset_string_buffer();
      string lexbuf;
      reset_string_buffer();
      comment lexbuf }
  | "''"
      { comment lexbuf }
  | "'" [^ '\\' '\''] "'"
      { comment lexbuf }
  | "'\\" ['\\' '\'' 'n' 't' 'b' 'r'] "'"
      { comment lexbuf }
  | "'\\" ['0'-'9'] ['0'-'9'] ['0'-'9'] "'"
      { comment lexbuf }
  | eof
    { raise(Lexical_error("unterminated comment", 0, 0)) }
  | '\010'
    { line_start_pos := Lexing.lexeme_end lexbuf;
      incr line_num;
      comment lexbuf }
  | _
    { comment lexbuf }
