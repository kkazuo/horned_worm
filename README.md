# Horned_worm

A functional Web app server.

Greatly inspired by Suave.IO and GIRAFFE of F#, this is OCaml implementation.


> Sphingids are some of the faster flying insects; some are capable of flying at over 5.3 m/s (12 miles per hour). --- [Wikipedia](https://en.wikipedia.org/wiki/Sphingidae)


## Web Parts

### path

    let app =
      path "/hello"
      >=> text "hello, world"

### path_ci

    let app =
      path_ci "/hello"
      >=> text "hello, world"

### path_starts

    let app =
      path_starts "/hello/"
      >=> text "hello, world"

### path_regex

    let app =
      path_regex "/hello/wo{3}rld"
      >=> text "hello, world"

### path_scanf

    let app =
      path_scanf "/%d/%d" begin fun x y ->
        text @@ Printf.sprintf "hello, %d" (x + y)
      end

### meth

    let app =
      meth `GET
      >=> text "hello, world"

### filter_p

    let app =
      filter_p (fun ctx -> true)
      >=> text "text."

### choose

    let app =
      choose
        [ meth `GET
          >=> choose
            [ path "/a" >=> text "hello, GET a"
            ; path "/b" >=> text "hello, GET b"
            ]
        ; meth `POST >=> text "hello, POST"
        ]

### log

    let app =
      log Logs.err (fun ctx m -> m "error message.")
      >=> text "text."

### set_mime_type

    let app =
      set_mime_type "text/plain; charset=utf-8"
      >=> text "text."

### set_status

    let app =
      set_status `Bad_request
      >=> text "text."

### set_header

    let app =
      set_header "x-test" "my test header"
      >=> text "text."

### set_header_unless_exists

    let app =
      set_header_unless_exists "x-test" "my test header"
      >=> text "text."

### add_header

    let app =
      add_header "x-test" "my test header"
      >=> text "text."

### browse

    let app =
      browse "/etc"

### browse_file

    let app =
      browse_file "/etc" "/hosts"

### text

    let app =
      text "hello, world."

### texts

    let app =
      texts [ "hello"
            ; ", world."
            ]

### json

    let app =
      json Yojson.(`Assoc [ "hello", `String "world"
                          ; "key", `Int 1 ])

### respond_string

    let app =
      respond_string "string"

### respond_strings

    let app =
      respond_strings [ "string"; "string" ]

### respond_file

    let app =
      respond_file "/etc/hosts"

### simple_cors

    let app =
      simple_cors
      >=> text "text."

### secure_headers

    let app =
      secure_headers
      >=> text "text."


### web_server

- ?port:int  Listening port. default is 5000
- Web_part.t Web app

```
let () =
  Logs.set_reporter (Logs_fmt.reporter ());
  Lwt_main.run (web_server ~port:5000 app)
```

## Compose your own parts

```
let yourapp : Web_part.t =
  fun next ctx ->
    (* your work here *)
    if (* should continue *) then
      let modified_ctx = ctx in
      begin
        set_header "a" "b"
        >=> set_header "x" "y"
      end next modified_ctx
    else
      Web_part.fail
```


## How to start

Example:

    open Horned_worm

    let app =
      text "hello, world"

    let () =
      Logs.set_reporter (Logs_fmt.reporter ());

      Lwt_main.run (web_server app)

## Install

    opam install horned_worm

## Status

- alpha

Todo:

- more predefined Web parts.
- needs query parm receiver.
