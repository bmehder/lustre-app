/// The stable identity of a note.
///
/// Keeping this distinct from a bare `String` prevents arbitrary text from
/// being passed where a UUID is expected.
pub type NoteId {
  NoteId(String)
}

/// A note in the application's domain.
pub type Note {
  Note(id: NoteId, title: String, body: String)
}
