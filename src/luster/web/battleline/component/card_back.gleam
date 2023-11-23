import nakai
import nakai/html
import nakai/html/attrs
import luster/web/plant
import gleam/io

pub type Background {
  Clouds
  Diamonds
}

// pub fn new(back: Background) -> plant.Template {
//   let background = case back {
//     Clouds -> "clouds"
//     Diamonds -> "diamonds"
//   }
// 
//   plant.lay(
//     from: "src/luster/web/battleline/component/card_back.html",
//     with: [#("background", plant.raw(background))],
//   )
// }

pub fn new(back: Background) -> plant.Template {
  let background = case back {
    Clouds -> "clouds"
    Diamonds -> "diamonds"
  }

  html.div([attrs.class("card back " <> background)], [])
  |> nakai.to_inline_string()
  |> plant.raw()
}
