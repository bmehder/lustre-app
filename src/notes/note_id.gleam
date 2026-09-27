//// Note ID generation for browser-based Notes applications.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import notes/domain.{type NoteId, NoteId}

// TYPES -----------------------------------------------------------------------

pub type Error {
  CouldNotGenerateNoteId
}

// GENERATION ------------------------------------------------------------------

pub fn random() -> Result(NoteId, Error) {
  random_uuid_value()
  |> decode.run(decode.string)
  |> result.map(NoteId)
  |> result.map_error(fn(_) { CouldNotGenerateNoteId })
}

// BROWSER INTEROP -------------------------------------------------------------

@external(javascript, "./note_id_ffi.mjs", "randomUUID")
fn random_uuid_value() -> Dynamic
