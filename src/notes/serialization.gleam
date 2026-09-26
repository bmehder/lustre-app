//// The versioned representation used to persist notebooks.

import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import notes/domain.{type Note, Note, NoteId}
import notes/notebook.{type Notebook}

pub const current_version = 1

pub fn decoder() -> Decoder(Notebook) {
  use version <- decode.field("version", decode.int)

  case version {
    1 -> {
      use notes <- decode.field("notes", decode.list(note_decoder()))

      case restore(notebook.new(), notes) {
        Ok(notebook) -> decode.success(notebook)
        Error(_) -> decode.failure(notebook.new(), expected: "valid notes")
      }
    }
    _ -> decode.failure(notebook.new(), expected: "a supported format version")
  }
}

pub fn encode(notebook: Notebook) -> Json {
  json.object([
    #("version", json.int(current_version)),
    #("notes", json.array(notebook.notes(notebook), encode_note)),
  ])
}

fn note_decoder() -> Decoder(Note) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use body <- decode.field("body", decode.string)

  decode.success(Note(id: NoteId(id), title:, body:))
}

fn encode_note(note: Note) -> Json {
  let NoteId(id) = note.id

  json.object([
    #("id", json.string(id)),
    #("title", json.string(note.title)),
    #("body", json.string(note.body)),
  ])
}

fn restore(
  notebook: Notebook,
  notes: List(Note),
) -> Result(Notebook, notebook.Error) {
  case notes {
    [] -> Ok(notebook)
    [note, ..rest] ->
      case notebook.add(notebook, note) {
        Ok(notebook) -> restore(notebook, rest)
        Error(error) -> Error(error)
      }
  }
}
