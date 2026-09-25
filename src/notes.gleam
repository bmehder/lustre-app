import gleam/int
import gleam/list
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{text}
import lustre/event
import notes/domain.{type Note, NoteId}
import notes/notebook.{type Notebook}

pub fn main() -> Nil {
  let app = lustre.simple(init, update, view)

  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

type Model {
  Model(notebook: Notebook, title: String, body: String)
}

type Msg {
  TitleChanged(String)
  BodyChanged(String)
  NoteSubmitted
}

fn init(_flags: Nil) -> Model {
  Model(notebook: notebook.new(), title: "", body: "")
}

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    TitleChanged(title) -> Model(..model, title:)
    BodyChanged(body) -> Model(..model, body:)
    NoteSubmitted -> {
      let id = NoteId(random_uuid())

      case notebook.create(model.notebook, id, model.title, model.body) {
        Ok(updated_notebook) ->
          Model(notebook: updated_notebook, title: "", body: "")
        Error(_) -> model
      }
    }
  }
}

fn view(model: Model) -> Element(Msg) {
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
      html.form(
        [event.on_submit(fn(_) { NoteSubmitted }), attribute.class("space-y-4")],
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
              attribute.value(model.title),
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
                attribute.value(model.body),
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
  let notes = notebook.all(notebook)

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

fn note_count(notes: List(Note)) -> String {
  case list.length(notes) {
    1 -> "1 note"
    count -> int.to_string(count) <> " notes"
  }
}

@external(javascript, "./notes_ffi.mjs", "randomUUID")
fn random_uuid() -> String
