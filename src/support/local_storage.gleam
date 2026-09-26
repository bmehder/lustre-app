//// An application-agnostic bridge between Varasto and Lustre effects.

import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import lustre/effect.{type Effect}
import varasto

pub type LoadResult(value) {
  Loaded(value)
  Missing
  InvalidData
  LoadUnavailable
}

pub type SaveResult {
  Saved
  WriteFailed
  SaveUnavailable
}

pub fn load(
  key key: String,
  reader reader: Decoder(value),
  writer writer: fn(value) -> Json,
  to_message to_message: fn(LoadResult(value)) -> message,
) -> Effect(message) {
  effect.from(fn(dispatch) {
    let result = case varasto.local() {
      Error(_) -> LoadUnavailable
      Ok(storage) ->
        case varasto.get(varasto.new(storage, reader, writer), key) {
          Ok(value) -> Loaded(value)
          Error(varasto.NotFound) -> Missing
          Error(varasto.DecodeError(_)) -> InvalidData
        }
    }

    // dispatch(to_message(result))
    result |> to_message |> dispatch
  })
}

pub fn save(
  key key: String,
  value value: value,
  reader reader: Decoder(value),
  writer writer: fn(value) -> Json,
  to_message to_message: fn(SaveResult) -> message,
) -> Effect(message) {
  effect.from(fn(dispatch) {
    let result = case varasto.local() {
      Error(_) -> SaveUnavailable
      Ok(storage) ->
        case varasto.set(varasto.new(storage, reader, writer), key, value) {
          Ok(_) -> Saved
          Error(_) -> WriteFailed
        }
    }

    // dispatch(to_message(result))
    result |> to_message |> dispatch
  })
}
