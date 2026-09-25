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
    submission_error: Option(SubmissionError),
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

pub type Msg {
  TitleChanged(String)
  BodyChanged(String)
  DraftSubmitted
  NoteGenerated(Result(Note, GenerationError))
}

// LUSTRE LIFECYCLE ------------------------------------------------------------

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  #(
    Model(
      notebook: notebook.new(),
      draft: empty_draft(),
      submission_error: None,
    ),
    effect.none(),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    TitleChanged(title) -> #(
      Model(
        ..model,
        draft: Draft(..model.draft, title:),
        submission_error: None,
      ),
      effect.none(),
    )
    BodyChanged(body) -> #(
      Model(..model, draft: Draft(..model.draft, body:), submission_error: None),
      effect.none(),
    )
    DraftSubmitted -> #(
      Model(..model, submission_error: None),
      generate_note(model.draft),
    )
    NoteGenerated(Error(_)) -> #(
      Model(..model, submission_error: Some(IdGenerationFailed)),
      effect.none(),
    )
    NoteGenerated(Ok(note)) ->
      case notebook.add(model.notebook, note) {
        Ok(updated_notebook) -> #(
          Model(
            notebook: updated_notebook,
            draft: empty_draft(),
            submission_error: None,
          ),
          effect.none(),
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
      form_error(model.submission_error),
      html.form(
        [
          event.on_submit(fn(_) { DraftSubmitted }),
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
              event.on_input(TitleChanged),
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
                event.on_input(BodyChanged),
                attribute.class(
                  "w-full resize-none rounded-xl border-0 bg-white/80 px-4 py-3 text-base leading-7 shadow-sm outline-none placeholder:text-stone-400 focus:ring-2 focus:ring-stone-900",
                ),
              ],
              "",
            ),
          ]),
          html.button(
            [
              attribute.type_("submit"),
              attribute.class(
                "w-full rounded-xl bg-stone-900 px-4 py-3 font-bold text-white transition hover:bg-stone-700 focus:outline-none focus:ring-2 focus:ring-stone-900 focus:ring-offset-2 focus:ring-offset-amber-300",
              ),
            ],
            [text("Save note")],
          ),
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
    [attribute.class("min-h-48 rounded-3xl bg-white p-6 shadow-sm")],
    [
      html.h2(
        [attribute.class("break-words text-xl font-extrabold tracking-tight")],
        [text(note.title)],
      ),
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

// BROWSER INTEROP -------------------------------------------------------------

fn generate_note(draft: Draft) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    random_note_id()
    |> result.map(fn(id) { Note(id:, title: draft.title, body: draft.body) })
    |> NoteGenerated
    |> dispatch
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
