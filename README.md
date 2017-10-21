# Horned_worm

A functional Web app server.

Greatly inspired by [Suave.IO](https://suave.io) and [GIRAFFE](https://github.com/dustinmoris/Giraffe) of F#, this is OCaml implementation.


> Sphingids are some of the faster flying insects; some are capable of flying at over 5.3 m/s (12 miles per hour). --- [Wikipedia](https://en.wikipedia.org/wiki/Sphingidae)


## Web Parts

### path

```ocaml
let app =
  path "/hello"
  >=> text "hello, world"
```

### path_ci

```ocaml
let app =
  path_ci "/hello"
  >=> text "hello, world"
```

### path_starts

```ocaml
 let app =
   path_starts "/hello/"
   >=> text "hello, world"
```

### path_starts_ci

```ocaml
let app =
  path_starts_ci "/hello/"
  >=> text "hello, world"
```

### path_regex

```ocaml
let app =
  path_regex "/hello/wo{3}rld"
  >=> text "hello, world"
```

### path_scanf

```ocaml
let app =
  path_scanf "/%d/%d" begin fun x y ->
    text @@ Printf.sprintf "hello, %d" (x + y)
  end
```

### meth

```ocaml
let app =
  meth `GET
  >=> text "hello, world"
```

### filter_p

```ocaml
let app =
  filter_p (fun ctx -> true)
  >=> text "text."
```

### path_p

```ocaml
let app =
  path_p (fun path -> true)
  >=> text "text."
```

### choose

```ocaml
let app =
  choose
    [ meth `GET
      >=> choose
        [ path "/a" >=> text "hello, GET a"
        ; path "/b" >=> text "hello, GET b"
        ]
    ; meth `POST >=> text "hello, POST"
    ]
```

### log

```ocaml
let app =
  log Logs.err (fun ctx m -> m "error message.")
  >=> text "text."
```

### set_mime_type

```ocaml
let app =
  set_mime_type "text/plain; charset=utf-8"
  >=> text "text."
```

### set_status

```ocaml
let app =
  set_status `Bad_request
  >=> text "text."
```

### set_header

```ocaml
let app =
  set_header "x-test" "my test header"
  >=> text "text."
```

### set_header_unless_exists

```ocaml
let app =
  set_header_unless_exists "x-test" "my test header"
  >=> text "text."
```

### add_header

```ocaml
 let app =
   add_header "x-test" "my test header"
   >=> text "text."
```

### use_cookie

```ocaml
let app =
  use_cookie
  >=> text "text."
```

### set_cookie

```ocaml
let app =
  set_cookie "key" "value"
  >=> text "text."
```

### browse

```ocaml
let app =
  browse "/etc"
```

### browse_file

```ocaml
let app =
  browse_file "/etc" "/hosts"
```

### text

```ocaml
let app =
  text "hello, world."
```

### texts

```ocaml
let app =
  texts [ "hello"
        ; ", world."
        ]
```

### json

```ocaml
let app =
  json (`Assoc [ "hello", `String "world"
               ; "key", `Int 1 ])
```

### respond_string

```ocaml
let app =
  respond_string "string"
```

### respond_strings

```ocaml
let app =
  respond_strings [ "string"; "string" ]
```

### respond_file

```ocaml
let app =
  respond_file "/etc/hosts"
```

### simple_cors

```ocaml
let app =
  simple_cors
  >=> text "text."
```

### secure_headers

```ocaml
let app =
  secure_headers
  >=> text "text."
```

### web_server

- Web_part.t Web app
- int  Listening port

### run_web_server

- app Web_part.t

Simple Web_part.t runner.


## Compose your own parts

```ocaml
let yourapp : Web_part.t =
  fun next ctx ->
    (* your work here *)
    if (* should continue *) then
      let modified_ctx = ctx in
      begin
        set_header "a" "b" >=>
        set_header "x" "y"
      end next modified_ctx
    else
      Web_part.fail
```


## How to start

Example:

```ocaml
open Core
open Async
open Horned_worm

let app =
  choose
    [ meth `GET >=> choose
        [ path "/" >=> text "hello, world"
        ; path "/cookie" >=> use_cookie >=> begin
            let key = "test" in
            fun next ctx ->
              let v = Option.value Http_context.(cookie ctx ~key)
                  ~default:"hello cookie" in
              begin
                set_cookie key (v ^ "!") >=>
                text v
              end next ctx
          end
        ; path_scanf "/%d/%d" begin fun x y ->
            text (sprintf "%d + %d = %d" x y (x + y))
          end
        ; path_scanf "/json/%s" begin fun s ->
            json (`Assoc ["hello", `String s])
          end
        ]
    ; meth `POST >=> path "/" >=> text "hello, POST"
    ]

let () =
  run_web_server app
```

## Install

    opam install horned_worm

## Status

- alpha

Todo:

- more predefined Web parts.
- needs query parm receiver.
- builtin websocket supports.
