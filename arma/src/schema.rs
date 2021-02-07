table! {
  territory {
    id -> Integer,
    esm_custom_id -> Text,
    owner_uid -> Nullable<Text>,
    name -> Text,
    position_x -> Double,
    position_y -> Double,
    radius -> Double,
    level -> Integer,
    flag_texture -> Text,
    flag_stolen -> Timestamp,
    flag_stolen_by_uid -> Nullable<Text>,
    flag_stolen_at -> Nullable<Timestamp>,
    created_at -> Timestamp,
    last_paid_at -> Nullable<Timestamp>,
    xm8_protectionmoney_notified -> Bool,
    build_rights -> Text,
    moderators -> Text,
    esm_payment_counter -> Integer,
    deleted_at -> Timestamp,
  }
}
