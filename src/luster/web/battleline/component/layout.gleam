import luster/web/template

pub fn render(body: String) -> String {
  template.new("src/luster/web/battleline/component")
  |> template.from("layout.html")
  |> template.args(replace: "body", with: body)
  |> template.render()
}
