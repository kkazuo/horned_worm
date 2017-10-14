module Http_context : sig
  type t =
    {          conn : Cohttp_lwt_unix.Server.conn
    ;       request : Cohttp.Request.t
    ;          body : Cohttp_lwt_body.t
    ;      response : Cohttp.Response.t
    ; response_body : Cohttp_lwt_body.t
    }
end

module Http_task : sig
  type t = Http_context.t option Lwt.t
end

module Http_handler : sig
  type t = Http_context.t -> Http_task.t
end

module Web_part : sig
  type t = Http_handler.t -> Http_context.t -> Http_task.t
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

val fail : Http_task.t

val compose : ('a -> 'b -> 'c) -> ('d -> 'a) -> 'd -> 'b -> 'c
val ( >=> ) : ('a -> 'b -> 'c) -> ('d -> 'a) -> 'd -> 'b -> 'c

val choose : Web_part.t list -> Web_part.t
val filter_p : (Http_context.t -> bool) -> Web_part.t
val path : ?compare:(string -> string -> int) -> string -> Web_part.t
val path_ci : string -> Web_part.t
val path_starts : string -> Web_part.t
val path_regex : string -> Web_part.t
val path_scanf :
  ('a, Scanf.Scanning.in_channel, 'b, 'c -> Web_part.t, 'a -> 'd, 'd) format6
  -> 'c -> Web_part.t
val meth : Cohttp.Code.meth -> Web_part.t
val host : string -> Web_part.t
val log : 'a Logs.log -> (Http_context.t -> ('a, unit) Logs.msgf) -> Web_part.t
val set_status : Cohttp.Code.status_code -> Web_part.t
val set_header : string -> string -> Web_part.t
val set_header_unless_exists : string -> string -> Web_part.t
val add_header : string -> string -> Web_part.t
val set_mime_type : string -> Web_part.t
val x_frame_options :
  [< `ALLOW_FROM of string | `DENY | `SAMEORIGIN ] -> Web_part.t

val respond_string : Cohttp.Code.status_code -> string -> Web_part.t
val respond_strings : Cohttp.Code.status_code -> string list -> Web_part.t
val respond_file : string -> Web_part.t

val browse : string -> Web_part.t
val browse_file : string -> string -> Web_part.t

val json : ?len:int -> ?std:bool -> Yojson.json -> Web_part.t
val simple_cors : ?config:Cors_config.t -> Web_part.t

val secure_headers : Web_part.t

val web_server : ?port:int -> Web_part.t -> unit Lwt.t