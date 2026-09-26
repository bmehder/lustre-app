//// A small Lustre effect for browser confirmation dialogs.

import lustre/effect.{type Effect}

pub fn ask(
  question: String,
  on_confirmation message: message,
) -> Effect(message) {
  effect.from(fn(dispatch) {
    case confirm(question) {
      True -> dispatch(message)
      False -> Nil
    }
  })
}

@external(javascript, "./confirmation_ffi.mjs", "confirm")
fn confirm(question: String) -> Bool
