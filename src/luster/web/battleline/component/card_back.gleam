import luster/web/template

pub type Background {
  Clouds
  Diamonds
}

pub fn render(back: Background) {
  let background = case back {
    Clouds -> "clouds"
    Diamonds -> "diamonds"
  }

  template.new("src/luster/web/battleline/component")
  |> template.from("card_back.html")
  |> template.args(replace: "background", with: background)
  |> template.render()
}
