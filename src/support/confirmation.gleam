//// A small Lustre effect for browser confirmation dialogs.

import lustre/effect.{type Effect}

pub fn ask(
  question: String,
  on_confirmation on_confirmation: message,
  on_cancellation on_cancellation: message,
) -> Effect(message) {
  effect.from(fn(dispatch) {
    case confirm(question) {
      True -> dispatch(on_confirmation)
      False -> dispatch(on_cancellation)
    }
  })
}

@external(javascript, "./confirmation_ffi.mjs", "confirm")
fn confirm(question: String) -> Bool
