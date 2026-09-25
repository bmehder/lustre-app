import gleam/list
import notes/domain.{NoteId}
import notes/notebook

const first_id = "0199abcd-1234-7abc-8def-0123456789ab"

const second_id = "0199abcd-1234-7abc-8def-0123456789ac"

pub fn notes_can_be_created_and_found_test() {
  let id = NoteId(first_id)
  let assert Ok(notebook) =
    notebook.new()
    |> notebook.create(id, "Hello", "My first note")
  let assert Ok(note) = notebook.find(notebook, id)

  assert note.title == "Hello"
  assert note.body == "My first note"
}

pub fn notes_remain_in_creation_order_test() {
  let assert Ok(notebook) =
    notebook.new()
    |> notebook.create(NoteId(first_id), "First", "")
  let assert Ok(notebook) =
    notebook.create(notebook, NoteId(second_id), "Second", "")

  assert notebook.all(notebook)
    |> list.map(fn(note) { note.title })
    == ["First", "Second"]
}

pub fn duplicate_identifiers_are_rejected_test() {
  let id = NoteId(first_id)
  let assert Ok(notebook) = notebook.create(notebook.new(), id, "First", "")

  assert notebook.create(notebook, id, "Duplicate", "")
    == Error(notebook.DuplicateNoteId(id))
}

pub fn notes_can_be_updated_test() {
  let id = NoteId(first_id)
  let assert Ok(notebook) = notebook.create(notebook.new(), id, "Old", "Body")
  let assert Ok(notebook) = notebook.update(notebook, id, "New", "Updated")
  let assert Ok(note) = notebook.find(notebook, id)

  assert note.title == "New"
  assert note.body == "Updated"
}

pub fn notes_can_be_deleted_test() {
  let id = NoteId(first_id)
  let assert Ok(notebook) = notebook.create(notebook.new(), id, "Hello", "")
  let assert Ok(notebook) = notebook.delete(notebook, id)

  assert notebook.find(notebook, id) == Error(notebook.NoteNotFound(id))
}

pub fn missing_notes_cannot_be_changed_test() {
  let id = NoteId(first_id)

  assert notebook.update(notebook.new(), id, "Missing", "")
    == Error(notebook.NoteNotFound(id))
  assert notebook.delete(notebook.new(), id) == Error(notebook.NoteNotFound(id))
}
