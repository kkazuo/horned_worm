open Core
open Async
open Cohttp
open Cohttp_async


module Http_context = struct
  module Client = Cohttp_async.Client
  module Body = Cohttp_async.Body

  type t =
    {          conn : Socket.Address.Inet.t
    ;       request : Cohttp.Request.t
    ;          body : Body.t
    ;      response : Cohttp.Response.t
    ; response_body : Body.t
    ;       cookies : Cookie.cookie list
    ;    set_cookie : Cookie.Set_cookie_hdr.t String.Map.t
    }

  let conn t = t.conn
  let request t = t.request
  let body t = t.body
  let cookies t = t.cookies
  let response t = t.response
  let response_body t = t.response_body

  let cookie ~key t =
    Option.(
      List.find t.cookies ~f:(fun (k, _) -> String.equal key k)
      >>| snd)
end

module Http_task = struct
  type t = Http_context.t option Deferred.t
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
        x next ctx >>= fun t ->
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


let path_p p : Web_part.t =
  filter_p @@ fun ctx ->
  p Uri.(path (Request.uri ctx.request))


let path expect : Web_part.t =
  path_p @@ String.equal expect


let path_ci expect =
  path_p @@ String.Caseless.equal expect


let path_starts prefix : Web_part.t =
  path_p @@ String.is_prefix ~prefix


let path_starts_ci prefix : Web_part.t =
  path_p @@ String.Caseless.is_prefix ~prefix


let path_regex pattern : Web_part.t =
  let re = Re.compile (Re.Posix.re pattern) in
  path_p @@ Re.execp re


let path_scanf format scanner : Web_part.t =
  fun next ctx ->
    let path = Uri.path (Request.uri ctx.request) in
    begin
      try
        Scanf.sscanf path format scanner
      with
      | Scanf.Scan_failure _
      | End_of_file
        -> fun _ _ -> Web_part.fail
    end next ctx


let meth verb : Web_part.t =
  filter_p @@ fun ctx ->
  Poly.equal verb ctx.request.meth


let host hostname : Web_part.t =
  filter_p @@ fun ctx ->
  let headers = Request.headers ctx.request in
  match Header.get headers "Host" with
  | Some v -> String.Caseless.equal hostname v
  | None   -> false


let log (log:'a Logs.log) msgf : Web_part.t =
  fun next ctx ->
    log (msgf ctx);
    next ctx


let set_status status_code : Web_part.t =
  fun next ctx ->
    next { ctx with response = { ctx.response with status = status_code }}


let set_encoding encoding : Web_part.t =
  fun next ctx ->
    next { ctx with response = { ctx.response with encoding = encoding }}


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


let use_cookie : Web_part.t =
  fun next ctx ->
    let cookies =
      ctx.request
      |> Request.headers
      |> Cookie.Cookie_hdr.extract
      |> List.map ~f:(fun (key, value) ->
          (Uri.pct_decode key, Uri.pct_decode value)) in
    next { ctx with cookies = cookies }


let set_cookie ?expiration ?path ?domain ?secure ?http_only
    key value : Web_part.t =
  fun next ctx ->
    let key = Uri.pct_encode ~component:`Query_key key in
    let value = Uri.pct_encode ~component:`Query_value value in
    let data = Cookie.Set_cookie_hdr.make
        ?expiration ?path ?domain ?secure ?http_only (key, value) in
    next { ctx with set_cookie = Map.set ~key ~data ctx.set_cookie }


let serialize_set_cookie set_cookie response =
  if Map.is_empty set_cookie
  then response
  else
    let headers =
      Map.fold set_cookie
        ~init:Response.(headers response)
        ~f:(fun ~key ~data hs ->
            let _ = key in
            let key, data = Cookie.Set_cookie_hdr.serialize data in
            Header.replace hs key data) in
    { response with headers = headers }


let respond_body body : Web_part.t =
  fun next ctx ->
    next { ctx with response_body = body }


let respond_string body : Web_part.t =
  respond_body (`String body)


let respond_strings body : Web_part.t =
  respond_body (`Strings body)


let respond_file fname : Web_part.t =
  fun next ctx ->
    let headers = Response.headers ctx.response in
    Server.respond_with_file ~headers fname >>= fun (res, body) ->
    next { ctx with response = res; response_body = body }


let browse docroot : Web_part.t =
  fun next ctx ->
    let uri = Request.uri ctx.request in
    let path = Server.resolve_local_file ~docroot ~uri in
    respond_file path
      next ctx


let browse_file docroot fname : Web_part.t =
  let uri = Uri.of_string fname in
  let path = Server.resolve_local_file ~docroot ~uri in
  respond_file path


let text body =
  set_header_unless_exists "Content-Type" "text/plain; charset=utf-8"
  >=> respond_string body


let texts body =
  set_header_unless_exists "Content-Type" "text/plain; charset=utf-8"
  >=> respond_strings body


let json ?(len = 128) ?(std = false) json : Web_part.t =
  fun next ctx ->
    let body = Yojson.(to_string ~len ~std json) in
    set_header_unless_exists "Content-Type" "application/json; charset=utf-8"
      next { ctx with response_body = `String body }


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
        String.Set.of_list List.(map ~f:String.lowercase a) in
      fun x ->
        String.Set.mem allowed String.(lowercase x)
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


(*
let websocket : Web_part.t =
  meth `GET >=>
  fun next ctx ->
    let hs = Request.headers ctx.request in
    match ( Cohttp.Header.get hs "sec-websocket-key"
          , Cohttp.Header.get hs "upgrade" ) with
    | Some key, Some upgrade when String.Caseless.equal upgrade "websocket" ->
      let r, w = Pipe.create () in
      Pipe.close w;
      begin
        set_status `Switching_protocols >=>
        set_encoding Transfer.Unknown >=>
        set_header "connection" "upgrade" >=>
        set_header "upgrade" "websocket" >=>
        set_header "Sec-WebSocket-Accept" Ws.(accept ~key) >=>
        respond_body Body.(of_pipe r)
      end next ctx
    | _ -> Web_part.fail
*)


let web_server (app:Web_part.t) port () =
  let not_handled =
    set_status `Not_found >=>
    text "Not found" in
  let accept = fun ctx -> return (Some ctx) in

  let callback ~body conn request =
    (* setup fresh context *)
    let ctx : Http_context.t =
      { conn = conn
      ; request = request
      ; body = body
      ; response = Response.make ()
      ; response_body = `Empty
      ; cookies = []
      ; set_cookie = String.Map.empty
      } in
    let app = choose [ app; not_handled ] in

    (* run web app *)
    app accept ctx >>= fun result ->

    (* return response *)
    match result with
    | Some ctx ->
      let response = serialize_set_cookie ctx.set_cookie ctx.response in
      return (response, ctx.response_body)

    | None -> Failure "Not handled" |> raise
  in

  Server.create
    ~on_handler_error:`Ignore
    Tcp.(Where_to_listen.of_port port) callback >>= fun _ ->
  Deferred.never ()


let run_web_server app =
  Logs.set_reporter (Logs_fmt.reporter ());
  Command.(
    run @@ async_spec ~summary:"Start Web app"
      Spec.(
        empty
        +> flag "-p" (optional_with_default 5000 int)
          ~doc:"int Listening port (default 5000)"
      )
      (web_server app))
