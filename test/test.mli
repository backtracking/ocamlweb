(* HEADER QUI DEVRAIT �TRE IGNOR� !! *)

(*i $Id$ i*)

(*s D�clarations de types. *)

type t = int

type t = int * int

type t = int -> int

type 'a t = 'a -> 'a

type 'a t =
  | A
  | B of 'a
  | C of foo -> bar
  | D of foo * (bar -> bar)


