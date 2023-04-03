// TODO: Build a validator module for maps x-spec
// Can be changeset like and based on predicates >-> Accumulates result errors
// If everything passes
// A last parameter could be used to map into a constructor record >-> Accumulates
//   This last parameter could be validated at compile time by using the dynamic type
//let xspec = 
//  Spec(fn(x) {
//    // Variable values could be processed by another function
//    case process(x) {
//      Ok(y) -> Ok(y)
//      Error(_) -> Error(y <> " Must be valid")
//    }
//  })

// Things to spec
// Booleans (predicates)
// Regex
// Loops
// Matches (how?)
// Maps and Lists (how?)

// + Utility functions to validate data.
// Neat error messages that do something like.

// Failure: 
// 43 does not equal 42

// Failure: 
// Schema error
// - x: 43 does not equal 42
// - y: 3 is not greater than
// - z: 
//   - a: not a "dog" got a "cat"

// Probably with options to enable error messages
// Probably with options to disable checks

// Maybe the spec type is unnecesary 
// How does the code below compare to a simple case statement with guards?
// let spec =
//   Schema([
//     #("x", xspec), 
//     #("y", yspec),
//     #("z", Schema([
//       #("a", Spec(fn(a) {
//         greater_than(a, 0) && lesser_than(a, 15)
//       })
//     ]),
//   ])
//fn validate(
//  form: Map(String, String),
//  keys: List(String),
//) -> Result(List(String), Nil) {
//  keys
//  |> list.map(fn(key) { map.get(form, key) })
//  |> result.all()
//}
