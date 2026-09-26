import gleam/json
import gleam/list
import notes/domain.{Note, NoteId}
import notes/notebook
import notes/serialization

pub fn notebook_round_trips_through_json_test() {
  let first =
    Note(
      id: NoteId("0199abcd-1234-7abc-8def-0123456789ab"),
      title: "First",
      body: "One",
    )
  let second =
    Note(
      id: NoteId("0199abcd-1234-7abc-8def-0123456789ac"),
      title: "Second",
      body: "Two",
    )
  let assert Ok(notebook) = notebook.add(notebook.new(), first)
  let assert Ok(notebook) = notebook.add(notebook, second)

  let encoded = serialization.encode(notebook) |> json.to_string
  let assert Ok(restored) = json.parse(encoded, serialization.decoder())

  assert notebook.notes(restored)
    |> list.map(fn(note) { #(note.title, note.body) })
    == [#("First", "One"), #("Second", "Two")]
}

pub fn unsupported_storage_versions_are_rejected_test() {
  let encoded = "{\"version\":2,\"notes\":[]}"

  let assert Error(_) = json.parse(encoded, serialization.decoder())
}
