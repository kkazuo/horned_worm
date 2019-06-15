open Async


module Http_context : sig
  module Client : module type of Cohttp_async.Client
  module Body : module type of Cohttp_async.Body

  type t

  val conn : t -> Socket.Address.Inet.t
  val request : t -> Cohttp.Request.t
  val body : t -> Body.t
  val cookies : t -> Cohttp.Cookie.cookie list
  val cookie : key:string -> t -> string option
  val response : t -> Cohttp.Response.t
  val response_body : t -> Body.t
end

module Http_task : sig
  type t = Http_context.t option Deferred.t
end

module Http_handler : sig
  type t = Http_context.t -> Http_task.t
end

module Web_part : sig
  type t = Http_handler.t -> Http_context.t -> Http_task.t

  val fail : Http_task.t
end

module Cors_config : sig
  type origin =
    | Any
    | OneOf of string list
    | Predicate of (string -> bool)

  type t =
    { allowed_origin : origin
    ;  allow_cookies : bool
    ;        max_age : int option
    ; expose_headers : string option
    }

  val default : t
end

val compose : ('a -> 'b -> 'c) -> ('d -> 'a) -> 'd -> 'b -> 'c
val ( >=> ) : ('a -> 'b -> 'c) -> ('d -> 'a) -> 'd -> 'b -> 'c

val choose : Web_part.t list -> Web_part.t
val filter_p : (Http_context.t -> bool) -> Web_part.t
val path_p : (string -> bool) -> Web_part.t
val path : string -> Web_part.t
val path_ci : string -> Web_part.t
val path_starts : string -> Web_part.t
val path_starts_ci : string -> Web_part.t
val path_regex : string -> Web_part.t
val path_scanf :
  ('a, Scanf.Scanning.in_channel, 'b, 'c -> Web_part.t, 'a -> 'd, 'd) format6
  -> 'c -> Web_part.t
val meth : Cohttp.Code.meth -> Web_part.t
val host : string -> Web_part.t
val log : 'a Logs.log -> (Http_context.t -> ('a, unit) Logs.msgf) -> Web_part.t
val set_status : Cohttp.Code.status_code -> Web_part.t
val set_encoding : Cohttp.Transfer.encoding -> Web_part.t
val set_header : string -> string -> Web_part.t
val set_header_unless_exists : string -> string -> Web_part.t
val add_header : string -> string -> Web_part.t
val set_mime_type : string -> Web_part.t
val x_frame_options :
  [< `ALLOW_FROM of string | `DENY | `SAMEORIGIN ] -> Web_part.t

val use_cookie : Web_part.t
val set_cookie :
  ?expiration:Cohttp.Cookie.expiration ->
  ?path:string ->
  ?domain:string ->
  ?secure:bool ->
  ?http_only:bool ->
  string -> string -> Web_part.t

val respond_string : string -> Web_part.t
val respond_strings : string list -> Web_part.t
val respond_file : string -> Web_part.t
val respond_body : Http_context.Body.t -> Web_part.t

val browse : string -> Web_part.t
val browse_file : string -> string -> Web_part.t

val text : string -> Web_part.t
val texts : string list -> Web_part.t
val json : ?len:int -> ?std:bool -> Yojson.t -> Web_part.t

val simple_cors : ?config:Cors_config.t -> Web_part.t
val secure_headers : Web_part.t

val web_server : Web_part.t -> int -> unit -> unit Deferred.t
val run_web_server : Web_part.t -> unit
