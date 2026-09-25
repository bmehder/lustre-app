import gleam/list
import notes/domain.{type Note, Note, NoteId}
import notes/notebook

const first_id = "0199abcd-1234-7abc-8def-0123456789ab"

const second_id = "0199abcd-1234-7abc-8def-0123456789ac"

fn note(id: String, title: String, body: String) -> Note {
  Note(id: NoteId(id), title:, body:)
}

pub fn notes_can_be_created_and_found_test() {
  let id = NoteId(first_id)
  let assert Ok(notebook) =
    notebook.new()
    |> notebook.add(note(first_id, "Hello", "My first note"))
  let assert Ok(note) = notebook.find(notebook, id)

  assert note.title == "Hello"
  assert note.body == "My first note"
}

pub fn notes_remain_in_creation_order_test() {
  let assert Ok(notebook) =
    notebook.new()
    |> notebook.add(note(first_id, "First", ""))
  let assert Ok(notebook) =
    notebook.add(notebook, note(second_id, "Second", ""))

  assert notebook.notes(notebook)
    |> list.map(fn(note) { note.title })
    == ["First", "Second"]
}

pub fn duplicate_identifiers_are_rejected_test() {
  let id = NoteId(first_id)
  let assert Ok(notebook) =
    notebook.add(notebook.new(), note(first_id, "First", ""))

  assert notebook.add(notebook, note(first_id, "Duplicate", ""))
    == Error(notebook.DuplicateNoteId(id))
}

pub fn notes_require_a_non_empty_title_test() {
  assert notebook.add(notebook.new(), note(first_id, "   ", "Body"))
    == Error(notebook.EmptyTitle)
}

pub fn notes_can_be_updated_test() {
  let id = NoteId(first_id)
  let assert Ok(notebook) =
    notebook.add(notebook.new(), note(first_id, "Old", "Body"))
  let assert Ok(notebook) =
    notebook.update(notebook, note(first_id, "New", "Updated"))
  let assert Ok(note) = notebook.find(notebook, id)

  assert note.title == "New"
  assert note.body == "Updated"
}

pub fn notes_cannot_be_updated_to_an_empty_title_test() {
  let assert Ok(notebook) =
    notebook.add(notebook.new(), note(first_id, "Title", "Body"))

  assert notebook.update(notebook, note(first_id, "", "Updated"))
    == Error(notebook.EmptyTitle)
}

pub fn notes_can_be_deleted_test() {
  let id = NoteId(first_id)
  let assert Ok(notebook) =
    notebook.add(notebook.new(), note(first_id, "Hello", ""))
  let assert Ok(notebook) = notebook.delete(notebook, id)

  assert notebook.find(notebook, id) == Error(notebook.NoteNotFound(id))
}

pub fn missing_notes_cannot_be_changed_test() {
  let id = NoteId(first_id)

  assert notebook.update(notebook.new(), note(first_id, "Missing", ""))
    == Error(notebook.NoteNotFound(id))
  assert notebook.delete(notebook.new(), id) == Error(notebook.NoteNotFound(id))
}
