import lustre
import lustre/element.{type Element}
import lustre/element/html

pub fn main() -> Nil {
  let app = lustre.simple(init, update, view)

  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

fn init(_flags: Nil) -> Nil {
  Nil
}

fn update(model: Nil, _msg: Nil) -> Nil {
  model
}

fn view(_model: Nil) -> Element(Nil) {
  html.main([], [])
}
