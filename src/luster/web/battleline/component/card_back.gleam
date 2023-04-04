import luster/web/plant.{Layout, Raw, Template}

pub type Background {
  Clouds
  Diamonds
}

pub fn new(back: Background) -> Template {
  let background = case back {
    Clouds -> "clouds"
    Diamonds -> "diamonds"
  }

  Layout(
    path: "src/luster/web/battleline/component/card_back.html",
    contents: [#("background", Raw(background))],
  )
}
