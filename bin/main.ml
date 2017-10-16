open Core
open Async
open Horned_worm

let app =
  meth `GET >=> path "/" >=> text "hello, world"

let () =
  Logs.set_reporter (Logs_fmt.reporter ());

  Command.(
    run @@ async ~summary:"Start Web app"
      Spec.(
        empty
        +> flag "-p" (optional_with_default 5000 int)
          ~doc:"int Listening port"
      )
      (web_server app))
