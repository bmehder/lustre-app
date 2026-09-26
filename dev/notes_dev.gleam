import lustre
import notes
import timetravel

pub fn main() -> Nil {
  let app = timetravel.application(notes.init, notes.update, notes.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
