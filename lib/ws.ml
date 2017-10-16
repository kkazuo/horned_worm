open Core
open Async

let accept ~key =
  let guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11" in
  let ctx = Sha1.init () in
  Sha1.update_string ctx key;
  Sha1.update_string ctx guid;
  B64.encode Sha1.(to_bin (finalize ctx))
