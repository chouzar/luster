// TODO: What to fit in the context?
// * Different types on the parameters received from the router.
//   * Param decoding could happen in this module.
//   * Param decoding could happen depending on the header.
//     * Form data should be decoded accordingly.
// * Game state already loaded from store.
// * Different actions decoded from the parameters received from the router.
//   * Show(state: GameState, player_id: String).
//     | DrawCard(GameState, player_id: String).
pub type Context {
  None
}
