import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import notes/domain.{type Note, type NoteId}

// TYPES -----------------------------------------------------------------------

/// The collection of notes managed by the application.
pub opaque type Notebook {
  Notebook(notes: List(Note))
}

/// The ways a notebook operation can fail.
pub type Error {
  EmptyTitle
  DuplicateNoteId(NoteId)
  NoteNotFound(NoteId)
}

// PUBLIC OPERATIONS -----------------------------------------------------------

/// Create an empty notebook.
pub fn new() -> Notebook {
  Notebook(notes: [])
}

/// Return the notes in creation order.
pub fn notes(notebook: Notebook) -> List(Note) {
  notebook.notes
}

/// Add a note to the end of the notebook.
pub fn add(notebook: Notebook, note: Note) -> Result(Notebook, Error) {
  case string.trim(note.title) {
    "" -> Error(EmptyTitle)
    _ ->
      case find_in(notebook.notes, note.id) {
        Some(_) -> Error(DuplicateNoteId(note.id))
        None -> Ok(Notebook(notes: list.append(notebook.notes, [note])))
      }
  }
}

/// Find a note by its identifier.
pub fn find(notebook: Notebook, id: NoteId) -> Result(Note, Error) {
  case find_in(notebook.notes, id) {
    Some(note) -> Ok(note)
    None -> Error(NoteNotFound(id))
  }
}

/// Replace the title and body of an existing note.
pub fn update(notebook: Notebook, note: Note) -> Result(Notebook, Error) {
  case string.trim(note.title) {
    "" -> Error(EmptyTitle)
    _ ->
      case replace_in(notebook.notes, note) {
        Some(notes) -> Ok(Notebook(notes:))
        None -> Error(NoteNotFound(note.id))
      }
  }
}

/// Remove a note from the notebook.
pub fn delete(notebook: Notebook, id: NoteId) -> Result(Notebook, Error) {
  case remove_from(notebook.notes, id) {
    Some(notes) -> Ok(Notebook(notes:))
    None -> Error(NoteNotFound(id))
  }
}

// PRIVATE LIST OPERATIONS -----------------------------------------------------

fn find_in(notes: List(Note), id: NoteId) -> Option(Note) {
  case notes {
    [] -> None
    [note, ..] if note.id == id -> Some(note)
    [_, ..rest] -> find_in(rest, id)
  }
}

fn replace_in(notes: List(Note), replacement: Note) -> Option(List(Note)) {
  case notes {
    [] -> None
    [note, ..rest] if note.id == replacement.id -> Some([replacement, ..rest])
    [note, ..rest] ->
      case replace_in(rest, replacement) {
        Some(updated_rest) -> Some([note, ..updated_rest])
        None -> None
      }
  }
}

fn remove_from(notes: List(Note), id: NoteId) -> Option(List(Note)) {
  case notes {
    [] -> None
    [note, ..rest] if note.id == id -> Some(rest)
    [note, ..rest] ->
      case remove_from(rest, id) {
        Some(updated_rest) -> Some([note, ..updated_rest])
        None -> None
      }
  }
}
