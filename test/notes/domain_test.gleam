import notes/domain.{Note, NoteId}

pub fn note_can_be_described_test() {
  let note =
    Note(
      id: NoteId("0199abcd-1234-7abc-8def-0123456789ab"),
      title: "Hello",
      body: "My first note",
    )

  assert note.title == "Hello"
  assert note.body == "My first note"
}
