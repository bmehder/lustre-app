import lustre
import notes/app
import timetravel

pub fn main() -> Nil {
  let application = timetravel.application(app.init, app.update, app.view)
  let assert Ok(_) = lustre.start(application, "#app", Nil)
  Nil
}
