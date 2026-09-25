import gleam/list
import gleam/result
import notes/domain.{type Note, type NoteId, Note}

/// The collection of notes managed by the application.
pub opaque type Notebook {
  Notebook(notes: List(Note))
}

/// The ways a notebook operation can fail.
pub type Error {
  DuplicateNoteId(NoteId)
  NoteNotFound(NoteId)
}

/// Create an empty notebook.
pub fn new() -> Notebook {
  Notebook(notes: [])
}

/// Return the notes in creation order.
pub fn all(notebook: Notebook) -> List(Note) {
  notebook.notes
}

/// Add a note to the end of the notebook.
pub fn create(
  notebook: Notebook,
  id: NoteId,
  title: String,
  body: String,
) -> Result(Notebook, Error) {
  case find_note(notebook.notes, id) {
    Ok(_) -> Error(DuplicateNoteId(id))
    Error(_) ->
      Ok(
        Notebook(notes: list.append(notebook.notes, [Note(id:, title:, body:)])),
      )
  }
}

/// Find a note by its identifier.
pub fn find(notebook: Notebook, id: NoteId) -> Result(Note, Error) {
  find_note(notebook.notes, id)
  |> result.map_error(fn(_) { NoteNotFound(id) })
}

/// Replace the title and body of an existing note.
pub fn update(
  notebook: Notebook,
  id: NoteId,
  title: String,
  body: String,
) -> Result(Notebook, Error) {
  case replace_note(notebook.notes, id, title, body) {
    Ok(notes) -> Ok(Notebook(notes:))
    Error(_) -> Error(NoteNotFound(id))
  }
}

/// Remove a note from the notebook.
pub fn delete(notebook: Notebook, id: NoteId) -> Result(Notebook, Error) {
  case remove_note(notebook.notes, id) {
    Ok(notes) -> Ok(Notebook(notes:))
    Error(_) -> Error(NoteNotFound(id))
  }
}

fn find_note(notes: List(Note), id: NoteId) -> Result(Note, Nil) {
  case notes {
    [] -> Error(Nil)
    [note, ..] if note.id == id -> Ok(note)
    [_, ..rest] -> find_note(rest, id)
  }
}

fn replace_note(
  notes: List(Note),
  id: NoteId,
  title: String,
  body: String,
) -> Result(List(Note), Nil) {
  case notes {
    [] -> Error(Nil)
    [note, ..rest] if note.id == id -> Ok([Note(id:, title:, body:), ..rest])
    [note, ..rest] -> {
      use updated_rest <- result.map(replace_note(rest, id, title, body))
      [note, ..updated_rest]
    }
  }
}

fn remove_note(notes: List(Note), id: NoteId) -> Result(List(Note), Nil) {
  case notes {
    [] -> Error(Nil)
    [note, ..rest] if note.id == id -> Ok(rest)
    [note, ..rest] -> {
      use updated_rest <- result.map(remove_note(rest, id))
      [note, ..updated_rest]
    }
  }
}
