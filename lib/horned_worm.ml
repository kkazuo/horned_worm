open Lwt
open Lwt_io
open Lwt.Infix
open Cohttp
open Cohttp_lwt
open Cohttp_lwt_unix


module Http_context = struct
  type t =
    {          conn : Server.conn
    ;       request : Cohttp.Request.t
    ;          body : Cohttp_lwt_body.t
    ;      response : Cohttp.Response.t
    ; response_body : Cohttp_lwt_body.t
    }

  let conn t = t.conn
  let request t = t.request
  let body t = t.body
  let response t = t.response
  let response_body t = t.response_body
end

module Http_task = struct
  type t = Http_context.t option Lwt.t
end

module Http_handler = struct
  type t = Http_context.t -> Http_task.t
end

module Web_part = struct
  type t = Http_handler.t -> Http_context.t -> Http_task.t

  let fail = return None
end


let compose a b =
  fun next ctx ->
    a (b next) ctx


let ( >=> ) = compose


let choose options : Web_part.t =
  fun next ctx ->
    let rec f = function
      | [] -> Web_part.fail
      | x :: xs ->
        let%lwt t = x next ctx in
        match t with
        | Some _ -> return t
        | None   -> f xs
    in
    f options


let filter_p p : Web_part.t =
  fun next ctx ->
    if p ctx then
      next ctx
    else
      Web_part.fail


let path ?(compare = String.compare) expect : Web_part.t =
  filter_p @@ fun ctx ->
  let path = Uri.path (Request.uri ctx.request) in
  compare path expect == 0


let path_ci =
  path ~compare:BatString.icompare


let path_starts prefix : Web_part.t =
  filter_p @@ fun ctx ->
  let path = Uri.path (Request.uri ctx.request) in
  BatString.starts_with path prefix


let path_regex pattern : Web_part.t =
  let re = Re.compile (Re_posix.re pattern) in
  filter_p @@ fun ctx ->
  let path = Uri.path (Request.uri ctx.request) in
  Re.execp re path


let path_scanf format scanner : Web_part.t =
  fun next ctx ->
    let path = Uri.path (Request.uri ctx.request) in
    begin
      try
        Scanf.sscanf path format scanner
      with
      | Scanf.Scan_failure _
      | End_of_file
        -> fun n c -> Web_part.fail
    end next ctx


let meth verb : Web_part.t =
  filter_p @@ fun ctx ->
  verb = Request.meth ctx.request


let host hostname : Web_part.t =
  filter_p @@ fun ctx ->
  let headers = Request.headers ctx.request in
  match Header.get headers "Host" with
  | Some v -> BatString.icompare v hostname = 0
  | None   -> false


let log (log:'a Logs.log) msgf : Web_part.t =
  fun next ctx ->
    log (msgf ctx);
    next ctx


let set_status status_code : Web_part.t =
  fun next ctx ->
    next { ctx with response = { ctx.response with status = status_code }}


let set_header key value : Web_part.t =
  fun next ctx ->
    let headers = Response.headers ctx.response in
    let headers = Header.replace headers key value in
    next { ctx with response = { ctx.response with headers = headers }}


let set_header_unless_exists key value : Web_part.t =
  fun next ctx ->
    let headers = Response.headers ctx.response in
    let headers = Header.add_unless_exists headers key value in
    next { ctx with response = { ctx.response with headers = headers }}


let add_header key value : Web_part.t =
  fun next ctx ->
    let headers = Response.headers ctx.response in
    let headers = Header.add headers key value in
    next { ctx with response = { ctx.response with headers = headers }}


let set_mime_type mime_type : Web_part.t =
  set_header "Content-Type" mime_type


let x_frame_options value : Web_part.t =
  let value = match value with
    | `DENY -> "DENY"
    | `SAMEORIGIN -> "SAMEORIGIN"
    | `ALLOW_FROM site -> "ALLOW-FROM " ^ site
  in
  set_header "X-Frame-Options" value


let respond_string body : Web_part.t =
  fun next ctx ->
    next { ctx with response_body = `String body }


let respond_strings body : Web_part.t =
  fun next ctx ->
    next { ctx with response_body = `Strings body }


let respond_file fname : Web_part.t =
  fun next ctx ->
    let headers = Response.headers ctx.response in
    let%lwt res, body = Server.respond_file ~headers ~fname () in
    next { ctx with response = res; response_body = body }


let browse root_path : Web_part.t =
  fun next ctx ->
    let path = Server.resolve_file root_path (Request.uri ctx.request) in
    respond_file path
      next ctx


let browse_file root_path fname : Web_part.t =
  let uri = Uri.of_string fname in
  let path = Server.resolve_file root_path uri in
  respond_file path


let text body =
  set_header_unless_exists "Content-Type" "text/plain; charset=utf-8"
  >=> respond_string body


let texts body =
  set_header_unless_exists "Content-Type" "text/plain; charset=utf-8"
  >=> respond_strings body


let json ?(len = 128) ?(std = false) json : Web_part.t =
  fun next ctx ->
    let once = ref true in
    let stream = Lwt_stream.from_direct @@ fun () ->
      if !once then begin
        once := false;
        Some Yojson.(to_string ~len ~std json)
      end else
        None
    in
    set_header_unless_exists "Content-Type" "application/json; charset=utf-8"
      next { ctx with response_body = `Stream stream }


let secure_headers : Web_part.t =
  x_frame_options `SAMEORIGIN
  >=> set_header "Referrer-Policy" "same-origin"
  >=> set_header "X-Xss-Protection" "1; mode=block"
  >=> set_header "X-Content-Type-Options" "nosniff"
  >=> set_header "Content-Security-Policy"
    "default-src https: data: 'unsafe-inline' 'unsafe-eval'"
  >=> set_header "Strict-Transport-Security"
    "max-age=31536000; includeSubDomains"


module Cors_config = struct
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

  let default =
    { allowed_origin = Any
    ; allow_cookies = true
    ; max_age = Some 3600
    ; expose_headers = None
    }
end


let simple_cors ?(config = Cors_config.default) : Web_part.t =
  let allowed =
    match config.allowed_origin with
    | Any -> fun _ -> true
    | OneOf a ->
      let allowed =
        BatSet.String.of_list(BatList.map BatString.lowercase_ascii a) in
      fun x ->
        BatSet.String.mem (BatString.lowercase_ascii x) allowed
    | Predicate f -> f
  in
  let max_age =
    match config.max_age with
    | Some s -> compose (set_header "Access-Control-Max-Age" (string_of_int s))
    | None   -> fun x -> x
  in
  let expose_headers =
    match config.expose_headers with
    | Some hs -> compose (set_header "Access-Control-Expose-Headers" hs)
    | None    -> fun x -> x
  in
  fun next ctx ->
    let headers = Request.(headers ctx.request) in
    match Header.get headers "Origin" with
    | None -> next ctx
    | Some origin ->
        if allowed origin then
          let parts =
            set_header "Access-Control-Allow-Origin" origin
            >=> set_header "Access-Control-Allow-Credentials"
              (if config.allow_cookies then "true" else "false")
          in
          let parts =
            match ( Header.get headers "Access-Control-Request-Method"
                  , Request.meth ctx.request ) with
            | Some ms, `OPTIONS ->
              set_header "Access-Control-Allow-Methods" ms >=> parts
            | _ -> parts
          in
          let parts =
            match Header.get headers "Access-Control-Request-Headers" with
            | Some hs ->
              set_header "Access-Control-Allow-Headers" hs >=> parts
            | None -> parts
          in
          max_age (expose_headers parts) next ctx
        else
          next ctx


let web_server ?(port = 5000) (app:Web_part.t) =
  let response =
    set_status `Not_found >=>
    text "Not found" in
  let accept = fun ctx -> return (Some ctx) in
  let callback conn request body =
    let ctx : Http_context.t =
      { conn = conn
      ; request = request
      ; body = body
      ; response = Response.make ()
      ; response_body = `Empty
      } in
    let%lwt result = app accept ctx in
    match result with
    | Some ctx -> return (ctx.response, ctx.response_body)
    | None     ->
      let%lwt result = response accept ctx in
      match result with
      | Some ctx -> return (ctx.response, ctx.response_body)
      | None     -> Failure "Not handled" |> raise
  in
  Server.create ~mode:(`TCP (`Port port)) (Server.make ~callback ())
