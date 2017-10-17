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
