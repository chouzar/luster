import luster/web/plant

pub type Background {
  Clouds
  Diamonds
}

pub fn new(back: Background) -> plant.Template {
  let background = case back {
    Clouds -> "clouds"
    Diamonds -> "diamonds"
  }

  plant.lay(
    from: "src/luster/web/battleline/component/card_back.html",
    with: [#("background", plant.raw(background))],
  )
}
