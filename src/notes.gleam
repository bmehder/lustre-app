import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{text}
import lustre/event
import notes/domain.{type Note, type NoteId, Note, NoteId}
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
    draft: Draft,
    editing: Option(NoteId),
    submission_error: Option(SubmissionError),
    persistence_status: PersistenceStatus,
  )
}

type Draft {
  Draft(title: String, body: String)
}

pub type GenerationError {
  CouldNotGenerateNoteId
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
  NoteGenerationFailed(GenerationError)
  UserRequestedNoteEdit(NoteId)
  UserCancelledNoteEdit
  UserRequestedNoteDeletion(NoteId)
  UserConfirmedNoteDeletion(NoteId)
  LocalStorageReturnedNotebook(local_storage.LoadResult(Notebook))
  LocalStorageSaved(local_storage.SaveResult)
}

// LUSTRE LIFECYCLE ------------------------------------------------------------

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  #(
    Model(
      notebook: notebook.new(),
      draft: empty_draft(),
      editing: None,
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
        draft: Draft(..model.draft, title:),
        submission_error: None,
      ),
      effect.none(),
    )
    UserChangedDraftBody(body) -> #(
      Model(..model, draft: Draft(..model.draft, body:), submission_error: None),
      effect.none(),
    )
    UserSubmittedDraft ->
      case model.editing {
        None -> #(
          Model(..model, submission_error: None),
          generate_note(model.draft),
        )
        Some(id) ->
          case
            notebook.update(
              model.notebook,
              Note(id:, title: model.draft.title, body: model.draft.body),
            )
          {
            Ok(updated_notebook) -> #(
              Model(
                notebook: updated_notebook,
                draft: empty_draft(),
                editing: None,
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
            draft: empty_draft(),
            editing: None,
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
            draft: Draft(title: note.title, body: note.body),
            editing: Some(id),
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
      Model(
        ..model,
        draft: empty_draft(),
        editing: None,
        submission_error: None,
      ),
      effect.none(),
    )
    UserRequestedNoteDeletion(id) -> #(
      model,
      confirmation.ask(
        "Delete this note? This cannot be undone.",
        on_confirmation: UserConfirmedNoteDeletion(id),
      ),
    )
    UserConfirmedNoteDeletion(id) ->
      case notebook.delete(model.notebook, id) {
        Ok(updated_notebook) -> #(
          case model.editing == Some(id) {
            True ->
              Model(
                ..model,
                notebook: updated_notebook,
                draft: empty_draft(),
                editing: None,
              )
            False -> Model(..model, notebook: updated_notebook)
          },
          save_notebook(updated_notebook),
        )
        Error(_) -> #(model, effect.none())
      }
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
  html.section(
    [
      attribute.class(
        "self-start rounded-3xl bg-amber-300 p-7 shadow-sm lg:sticky lg:top-10",
      ),
    ],
    [
      html.p(
        [
          attribute.class(
            "mb-2 text-xs font-bold uppercase tracking-[0.2em] text-amber-900/60",
          ),
        ],
        [text("A quiet place for ideas")],
      ),
      html.h1([attribute.class("mb-7 text-4xl font-black tracking-tight")], [
        text("Notes"),
      ]),
      case model.editing {
        None -> element.none()
        Some(_) ->
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
              attribute.value(model.draft.title),
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
                attribute.value(model.draft.body),
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
              [text(submit_label(model.editing))],
            ),
            cancel_edit_button(model.editing),
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
        html.div(
          [attribute.class("grid gap-4 sm:grid-cols-2")],
          list.map(notes, note_card),
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

fn submit_label(editing: Option(NoteId)) -> String {
  case editing {
    None -> "Save note"
    Some(_) -> "Update note"
  }
}

fn cancel_edit_button(editing: Option(NoteId)) -> Element(Msg) {
  case editing {
    None -> element.none()
    Some(_) ->
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
    case random_note_id() {
      Ok(id) ->
        dispatch(NoteGenerated(Note(id:, title: draft.title, body: draft.body)))
      Error(error) -> dispatch(NoteGenerationFailed(error))
    }
  })
}

fn random_note_id() -> Result(NoteId, GenerationError) {
  random_uuid_value()
  |> decode.run(decode.string)
  |> result.map(NoteId)
  |> result.map_error(fn(_) { CouldNotGenerateNoteId })
}

@external(javascript, "./notes_ffi.mjs", "randomUUID")
fn random_uuid_value() -> Dynamic
