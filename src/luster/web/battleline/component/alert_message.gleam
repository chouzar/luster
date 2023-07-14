import luster/web/plant
import nakai
import nakai/html.{Text, div, span}
import nakai/html/attrs

pub type Alert {
  Info
  Warning
  Success
  Error
}

pub fn new(message: String, alert: Alert) -> plant.Template {
  let color = case alert {
    Info -> "info"
    Warning -> "warning"
    Success -> "success"
    Error -> "error"
  }

  div([attrs.class("alert " <> color)], [span([], [Text(message)])])
  |> nakai.to_inline_string()
  |> plant.raw()
}
