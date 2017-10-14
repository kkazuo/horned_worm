# Horned_worm

A functional Web app server.

Greatly inspired by Suave.IO and GIRAFFE of F#, this is OCaml implementation.


## Web Parts

### path

    let app =
      path "/hello"
      >=> respond_string `OK "hello, world"

### path_ci

    let app =
      path_ci "/hello"
      >=> respond_string `OK "hello, world"

### path_starts

    let app =
      path_starts "/hello/"
      >=> respond_string `OK "hello, world"

### path_regex

    let app =
      path_regex "/hello/wo{3}rld"
      >=> respond_string `OK "hello, world"

### path_scanf

    let app =
      path_scanf "/%d/%d" begin fun x y ->
        respond_string `OK @@ Printf.sprintf "hello, %d" (x + y)
      end

### meth

    let app =
      meth `GET
      >=> respond_string `OK "hello, world"

### choose

    let app =
      choose
        [ meth `GET
          >=> choose
            [ path "/a" >=> respond_string `OK "hello, GET a"
            ; path "/b" >=> respond_string `OK "hello, GET b"
            ]
        ; meth `POST >=> respond_string `OK "hello, POST"
        ]


### web_server

- ?port:int  Listening port. default is 5000
- Web_part.t Web app

    let () =
      Logs.set_reporter (Logs_fmt.reporter ());
      Lwt_main.run (web_server ~port:5000 app)


## How to start

Example:

    open Horned_worm

    let app =
      respond_string `OK "hello, world"

    let () =
      Logs.set_reporter (Logs_fmt.reporter ());

      Lwt_main.run (web_server app)

## Install

    opam install horned_worm
