open Horned_worm

let app =
  respond_string `OK "hello, world"

let () =
  Logs.set_reporter (Logs_fmt.reporter ());

  Lwt_main.run (web_server app)
