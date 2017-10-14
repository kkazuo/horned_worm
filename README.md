# Horned_worm

A functional Web app server.

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
