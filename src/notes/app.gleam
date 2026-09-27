import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{text}
import lustre/element/keyed
import lustre/element/svg
import lustre/event
import notes/domain.{type Note, type NoteId, Note, NoteId}
import notes/note_id
import notes/notebook.{type Notebook}
import notes/serialization
import support/confirmation
import support/local_storage

const storage_key = "notes.notebook"

// ENTRY POINT -----------------------------------------------------------------

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)

  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

// MODEL AND MESSAGES ----------------------------------------------------------

pub opaque type Model {
  Model(
    notebook: Notebook,
    editor: Editor,
    submission_error: Option(SubmissionError),
    persistence_status: PersistenceStatus,
  )
}

type Draft {
  Draft(title: String, body: String)
}

type Editor {
  Creating(draft: Draft)
  Editing(id: NoteId, draft: Draft)
}

type SubmissionError {
  IdGenerationFailed
  TitleRequired
  DuplicateId
  SaveFailed
}

type PersistenceStatus {
  Loading
  Ready
  PersistenceFailed
}

pub type Msg {
  UserChangedDraftTitle(String)
  UserChangedDraftBody(String)
  UserSubmittedDraft
  NoteGenerated(Note)
  NoteGenerationFailed(note_id.Error)
  UserRequestedNoteEdit(NoteId)
  UserCancelledNoteEdit
  UserRequestedNoteDeletion(NoteId)
  UserConfirmedNoteDeletion(NoteId)
  UserCancelledNoteDeletion(NoteId)
  LocalStorageReturnedNotebook(local_storage.LoadResult(Notebook))
  LocalStorageSaved(local_storage.SaveResult)
}

// LUSTRE LIFECYCLE ------------------------------------------------------------

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  #(
    Model(
      notebook: notebook.new(),
      editor: empty_editor(),
      submission_error: None,
      persistence_status: Loading,
    ),
    load_notebook(),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserChangedDraftTitle(title) -> #(
      Model(
        ..model,
        editor: update_editor_title(model.editor, title),
        submission_error: None,
      ),
      effect.none(),
    )
    UserChangedDraftBody(body) -> #(
      Model(
        ..model,
        editor: update_editor_body(model.editor, body),
        submission_error: None,
      ),
      effect.none(),
    )
    UserSubmittedDraft ->
      case model.editor {
        Creating(draft) -> #(
          Model(..model, submission_error: None),
          generate_note(draft),
        )
        Editing(id, draft) ->
          case
            notebook.update(
              model.notebook,
              Note(id:, title: draft.title, body: draft.body),
            )
          {
            Ok(updated_notebook) -> #(
              Model(
                notebook: updated_notebook,
                editor: empty_editor(),
                submission_error: None,
                persistence_status: Ready,
              ),
              save_notebook(updated_notebook),
            )
            Error(notebook.EmptyTitle) -> #(
              Model(..model, submission_error: Some(TitleRequired)),
              effect.none(),
            )
            Error(_) -> #(
              Model(..model, submission_error: Some(SaveFailed)),
              effect.none(),
            )
          }
      }
    NoteGenerationFailed(_) -> #(
      Model(..model, submission_error: Some(IdGenerationFailed)),
      effect.none(),
    )
    NoteGenerated(note) ->
      case notebook.add(model.notebook, note) {
        Ok(updated_notebook) -> #(
          Model(
            notebook: updated_notebook,
            editor: empty_editor(),
            submission_error: None,
            persistence_status: Ready,
          ),
          save_notebook(updated_notebook),
        )
        Error(notebook.EmptyTitle) -> #(
          Model(..model, submission_error: Some(TitleRequired)),
          effect.none(),
        )
        Error(notebook.DuplicateNoteId(_)) -> #(
          Model(..model, submission_error: Some(DuplicateId)),
          effect.none(),
        )
        Error(_) -> #(
          Model(..model, submission_error: Some(SaveFailed)),
          effect.none(),
        )
      }
    UserRequestedNoteEdit(id) ->
      case notebook.find(model.notebook, id) {
        Ok(note) -> #(
          Model(
            ..model,
            editor: Editing(
              id:,
              draft: Draft(title: note.title, body: note.body),
            ),
            submission_error: None,
          ),
          effect.none(),
        )
        Error(_) -> #(
          Model(..model, submission_error: Some(SaveFailed)),
          effect.none(),
        )
      }
    UserCancelledNoteEdit -> #(
      Model(..model, editor: empty_editor(), submission_error: None),
      effect.none(),
    )
    UserRequestedNoteDeletion(id) -> #(
      model,
      confirmation.ask(
        "Delete this note? This cannot be undone.",
        on_confirmation: UserConfirmedNoteDeletion(id),
        on_cancellation: UserCancelledNoteDeletion(id),
      ),
    )
    UserConfirmedNoteDeletion(id) ->
      case notebook.delete(model.notebook, id) {
        Ok(updated_notebook) -> #(
          Model(
            ..model,
            notebook: updated_notebook,
            editor: stop_editing_deleted_note(model.editor, id),
          ),
          save_notebook(updated_notebook),
        )
        Error(_) -> #(model, effect.none())
      }
    UserCancelledNoteDeletion(_) -> #(model, effect.none())
    LocalStorageReturnedNotebook(result) -> #(
      case result {
        local_storage.Loaded(notebook) ->
          Model(..model, notebook:, persistence_status: Ready)
        local_storage.Missing -> Model(..model, persistence_status: Ready)
        local_storage.InvalidData | local_storage.LoadUnavailable ->
          Model(..model, persistence_status: PersistenceFailed)
      },
      effect.none(),
    )
    LocalStorageSaved(result) -> #(
      case result {
        local_storage.Saved -> Model(..model, persistence_status: Ready)
        local_storage.WriteFailed | local_storage.SaveUnavailable ->
          Model(..model, persistence_status: PersistenceFailed)
      },
      effect.none(),
    )
  }
}

fn empty_draft() -> Draft {
  Draft(title: "", body: "")
}

fn empty_editor() -> Editor {
  Creating(empty_draft())
}

fn editor_draft(editor: Editor) -> Draft {
  case editor {
    Creating(draft) | Editing(_, draft) -> draft
  }
}

fn update_editor_title(editor: Editor, title: String) -> Editor {
  case editor {
    Creating(draft) -> Creating(Draft(..draft, title:))
    Editing(id, draft) -> Editing(id, Draft(..draft, title:))
  }
}

fn update_editor_body(editor: Editor, body: String) -> Editor {
  case editor {
    Creating(draft) -> Creating(Draft(..draft, body:))
    Editing(id, draft) -> Editing(id, Draft(..draft, body:))
  }
}

fn stop_editing_deleted_note(editor: Editor, deleted_id: NoteId) -> Editor {
  case editor {
    Editing(id, _) if id == deleted_id -> empty_editor()
    _ -> editor
  }
}

// VIEWS -----------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  html.main(
    [attribute.class("min-h-screen bg-stone-100 px-4 py-10 text-stone-900")],
    [
      persistence_notice(model.persistence_status),
      html.div(
        [
          attribute.class(
            "mx-auto grid max-w-5xl gap-8 lg:grid-cols-[22rem_1fr]",
          ),
        ],
        [note_form(model), note_collection(model.notebook)],
      ),
    ],
  )
}

fn note_form(model: Model) -> Element(Msg) {
  let draft = editor_draft(model.editor)

  html.section(
    [
      attribute.class(
        "self-start rounded-3xl bg-amber-300 p-7 shadow-sm lg:sticky lg:top-10",
      ),
    ],
    [
      html.div(
        [attribute.class("mb-2 flex items-center justify-between gap-4")],
        [
          html.p(
            [
              attribute.class(
                "text-xs font-bold uppercase tracking-[0.2em] text-amber-900/60",
              ),
            ],
            [text("A quiet place for ideas")],
          ),
          github_link(),
        ],
      ),
      html.h1([attribute.class("mb-7 text-4xl font-black tracking-tight")], [
        text("Notes"),
      ]),
      case model.editor {
        Creating(_) -> element.none()
        Editing(_, _) ->
          html.p([attribute.class("mb-4 text-sm font-bold text-amber-950")], [
            text("Editing note"),
          ])
      },
      form_error(model.submission_error),
      html.form(
        [
          event.on_submit(fn(_) { UserSubmittedDraft }),
          attribute.class("space-y-4"),
        ],
        [
          html.div([], [
            html.label(
              [
                attribute.for("note-title"),
                attribute.class("mb-2 block text-sm font-bold"),
              ],
              [text("Title")],
            ),
            html.input([
              attribute.id("note-title"),
              attribute.type_("text"),
              attribute.value(draft.title),
              attribute.placeholder("A useful thought"),
              attribute.required(True),
              attribute.autofocus(True),
              event.on_input(UserChangedDraftTitle),
              attribute.class(
                "w-full rounded-xl border-0 bg-white/80 px-4 py-3 text-base shadow-sm outline-none placeholder:text-stone-400 focus:ring-2 focus:ring-stone-900",
              ),
            ]),
          ]),
          html.div([], [
            html.label(
              [
                attribute.for("note-body"),
                attribute.class("mb-2 block text-sm font-bold"),
              ],
              [text("Note")],
            ),
            html.textarea(
              [
                attribute.id("note-body"),
                attribute.value(draft.body),
                attribute.placeholder("Write it down before it disappears…"),
                attribute.rows(7),
                event.on_input(UserChangedDraftBody),
                attribute.class(
                  "w-full resize-none rounded-xl border-0 bg-white/80 px-4 py-3 text-base leading-7 shadow-sm outline-none placeholder:text-stone-400 focus:ring-2 focus:ring-stone-900",
                ),
              ],
              "",
            ),
          ]),
          html.div([attribute.class("flex gap-3")], [
            html.button(
              [
                attribute.type_("submit"),
                attribute.class(
                  "flex-1 rounded-xl bg-stone-900 px-4 py-3 font-bold text-white transition hover:bg-stone-700 focus:outline-none focus:ring-2 focus:ring-stone-900 focus:ring-offset-2 focus:ring-offset-amber-300",
                ),
              ],
              [text(submit_label(model.editor))],
            ),
            cancel_edit_button(model.editor),
          ]),
        ],
      ),
    ],
  )
}

fn note_collection(notebook: Notebook) -> Element(Msg) {
  let notes = notebook.notes(notebook)

  html.section([attribute.class("min-w-0")], [
    html.header([attribute.class("mb-6 flex items-end justify-between gap-4")], [
      html.div([], [
        html.p(
          [
            attribute.class(
              "mb-1 text-xs font-bold uppercase tracking-[0.2em] text-stone-400",
            ),
          ],
          [text("Your notebook")],
        ),
        html.h2([attribute.class("text-3xl font-black tracking-tight")], [
          text("Latest notes"),
        ]),
      ]),
      html.p([attribute.class("text-sm font-semibold text-stone-500")], [
        text(note_count(notes)),
      ]),
    ]),
    case notes {
      [] -> empty_notebook()
      _ ->
        keyed.div(
          [attribute.class("grid gap-4 sm:grid-cols-2")],
          list.map(notes, fn(note) { #(note_key(note.id), note_card(note)) }),
        )
    },
  ])
}

fn empty_notebook() -> Element(Msg) {
  html.div(
    [
      attribute.class(
        "rounded-3xl border-2 border-dashed border-stone-300 px-8 py-20 text-center",
      ),
    ],
    [
      html.p([attribute.class("text-lg font-bold text-stone-700")], [
        text("Nothing here yet"),
      ]),
      html.p([attribute.class("mt-2 text-sm leading-6 text-stone-500")], [
        text("Capture your first thought with the form."),
      ]),
    ],
  )
}

fn note_card(note: Note) -> Element(Msg) {
  html.article(
    [
      attribute.class(
        "flex min-h-48 flex-col rounded-3xl bg-white p-6 shadow-sm",
      ),
    ],
    [
      html.div([attribute.class("flex items-start justify-between gap-4")], [
        html.h2(
          [
            attribute.class(
              "min-w-0 break-words text-xl font-extrabold tracking-tight",
            ),
          ],
          [text(note.title)],
        ),
        html.div([attribute.class("flex shrink-0 gap-1")], [
          html.button(
            [
              attribute.type_("button"),
              attribute.aria_label("Edit " <> note.title),
              attribute.class(
                "rounded-lg px-2 py-1 text-sm font-bold text-stone-400 transition hover:bg-amber-50 hover:text-amber-800 focus:outline-none focus:ring-2 focus:ring-amber-700",
              ),
              event.on_click(UserRequestedNoteEdit(note.id)),
            ],
            [text("Edit")],
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.aria_label("Delete " <> note.title),
              attribute.class(
                "rounded-lg px-2 py-1 text-sm font-bold text-stone-400 transition hover:bg-red-50 hover:text-red-700 focus:outline-none focus:ring-2 focus:ring-red-700",
              ),
              event.on_click(UserRequestedNoteDeletion(note.id)),
            ],
            [text("Delete")],
          ),
        ]),
      ]),
      html.p(
        [
          attribute.class(
            "mt-3 whitespace-pre-wrap break-words leading-7 text-stone-600",
          ),
        ],
        [text(note.body)],
      ),
    ],
  )
}

// VIEW HELPERS ----------------------------------------------------------------

fn github_link() -> Element(Msg) {
  html.a(
    [
      attribute.href("https://github.com/bmehder/lustre-app"),
      attribute.target("_blank"),
      attribute.rel("noreferrer"),
      attribute.aria_label("View Notes on GitHub"),
      attribute.class(
        "rounded-lg p-1 text-amber-950/60 transition hover:bg-amber-200 hover:text-amber-950 focus:outline-none focus:ring-2 focus:ring-stone-900",
      ),
    ],
    [
      svg.svg(
        [
          attribute.attribute("viewBox", "0 0 24 24"),
          attribute.attribute("fill", "currentColor"),
          attribute.aria_hidden(True),
          attribute.class("size-6"),
        ],
        [
          svg.path([
            attribute.attribute(
              "d",
              "M12 .7a11.5 11.5 0 0 0-3.64 22.41c.58.11.79-.25.79-.56v-2.23c-3.22.7-3.9-1.37-3.9-1.37-.53-1.34-1.29-1.7-1.29-1.7-1.05-.72.08-.71.08-.71 1.16.08 1.78 1.2 1.78 1.2 1.04 1.77 2.72 1.26 3.38.96.1-.75.4-1.26.73-1.55-2.57-.29-5.27-1.28-5.27-5.69 0-1.26.45-2.28 1.19-3.09-.12-.29-.52-1.47.11-3.05 0 0 .97-.31 3.16 1.18a10.98 10.98 0 0 1 5.76 0c2.2-1.49 3.16-1.18 3.16-1.18.63 1.58.23 2.76.11 3.05.74.81 1.19 1.83 1.19 3.09 0 4.42-2.71 5.39-5.29 5.68.42.36.79 1.07.79 2.16v3.21c0 .31.21.68.8.56A11.5 11.5 0 0 0 12 .7Z",
            ),
          ]),
        ],
      ),
    ],
  )
}

fn persistence_notice(status: PersistenceStatus) -> Element(Msg) {
  case status {
    Ready -> element.none()
    Loading ->
      html.p(
        [
          attribute.role("status"),
          attribute.class(
            "mx-auto mb-4 max-w-5xl text-sm font-semibold text-stone-500",
          ),
        ],
        [text("Loading saved notes…")],
      )
    PersistenceFailed ->
      html.p(
        [
          attribute.role("alert"),
          attribute.class(
            "mx-auto mb-4 max-w-5xl rounded-xl bg-red-950 px-4 py-3 text-sm font-semibold text-white",
          ),
        ],
        [text("Notes could not be saved in this browser.")],
      )
  }
}

fn submit_label(editor: Editor) -> String {
  case editor {
    Creating(_) -> "Save note"
    Editing(_, _) -> "Update note"
  }
}

fn cancel_edit_button(editor: Editor) -> Element(Msg) {
  case editor {
    Creating(_) -> element.none()
    Editing(_, _) ->
      html.button(
        [
          attribute.type_("button"),
          attribute.class(
            "rounded-xl border-2 border-stone-900 px-4 py-3 font-bold text-stone-900 transition hover:bg-amber-200 focus:outline-none focus:ring-2 focus:ring-stone-900 focus:ring-offset-2 focus:ring-offset-amber-300",
          ),
          event.on_click(UserCancelledNoteEdit),
        ],
        [text("Cancel")],
      )
  }
}

fn form_error(error: Option(SubmissionError)) -> Element(Msg) {
  case error {
    None -> element.none()
    Some(error) ->
      html.p(
        [
          attribute.role("alert"),
          attribute.class(
            "mb-4 rounded-xl bg-red-950 px-4 py-3 text-sm font-semibold text-white",
          ),
        ],
        [text(error_message(error))],
      )
  }
}

fn error_message(error: SubmissionError) -> String {
  case error {
    IdGenerationFailed -> "Could not generate a note ID. Please try again."
    TitleRequired -> "A note needs a title."
    DuplicateId -> "That note already exists. Please try again."
    SaveFailed -> "Could not save the note. Please try again."
  }
}

fn note_count(notes: List(Note)) -> String {
  case list.length(notes) {
    1 -> "1 note"
    count -> int.to_string(count) <> " notes"
  }
}

fn note_key(id: NoteId) -> String {
  let NoteId(value) = id
  value
}

// STORAGE EFFECTS -------------------------------------------------------------

fn load_notebook() -> Effect(Msg) {
  local_storage.load(
    key: storage_key,
    reader: serialization.decoder(),
    writer: serialization.encode,
    to_message: LocalStorageReturnedNotebook,
  )
}

fn save_notebook(notebook: Notebook) -> Effect(Msg) {
  local_storage.save(
    key: storage_key,
    value: notebook,
    reader: serialization.decoder(),
    writer: serialization.encode,
    to_message: LocalStorageSaved,
  )
}

// BROWSER INTEROP -------------------------------------------------------------

fn generate_note(draft: Draft) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    case note_id.random() {
      Ok(id) ->
        dispatch(NoteGenerated(Note(id:, title: draft.title, body: draft.body)))
      Error(error) -> dispatch(NoteGenerationFailed(error))
    }
  })
}
