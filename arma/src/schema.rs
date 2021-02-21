table! {
  use diesel::sql_types::*;

  account (uid) {
      uid -> Varchar,
      clan_id -> Nullable<Unsigned<Integer>>,
      name -> Varchar,
      score -> Integer,
      kills -> Unsigned<Integer>,
      deaths -> Unsigned<Integer>,
      locker -> Integer,
      first_connect_at -> Datetime,
      last_connect_at -> Datetime,
      last_disconnect_at -> Nullable<Datetime>,
      total_connections -> Unsigned<Integer>,
  }
}

// table! {
//   use diesel::sql_types::*;

//   clan (id) {
//       id -> Unsigned<Integer>,
//       name -> Varchar,
//       leader_uid -> Varchar,
//       created_at -> Datetime,
//   }
// }

// table! {
//   use diesel::sql_types::*;

//   clan_map_marker (id) {
//       id -> Unsigned<Integer>,
//       clan_id -> Unsigned<Integer>,
//       markerType -> Tinyint,
//       positionArr -> Text,
//       color -> Varchar,
//       icon -> Varchar,
//       iconSize -> Unsigned<Float>,
//       label -> Varchar,
//       labelSize -> Unsigned<Float>,
//   }
// }

// table! {
//   use diesel::sql_types::*;

//   construction (id) {
//       id -> Unsigned<Integer>,
//       class -> Varchar,
//       account_uid -> Varchar,
//       spawned_at -> Datetime,
//       position_x -> Double,
//       position_y -> Double,
//       position_z -> Double,
//       direction_x -> Double,
//       direction_y -> Double,
//       direction_z -> Double,
//       up_x -> Double,
//       up_y -> Double,
//       up_z -> Double,
//       is_locked -> Bool,
//       pin_code -> Varchar,
//       damage -> Nullable<Unsigned<Tinyint>>,
//       territory_id -> Nullable<Unsigned<Integer>>,
//       last_updated_at -> Datetime,
//       deleted_at -> Nullable<Datetime>,
//   }
// }

// table! {
//   use diesel::sql_types::*;

//   container (id) {
//       id -> Unsigned<Integer>,
//       class -> Varchar,
//       spawned_at -> Datetime,
//       account_uid -> Nullable<Varchar>,
//       is_locked -> Bool,
//       position_x -> Double,
//       position_y -> Double,
//       position_z -> Double,
//       direction_x -> Double,
//       direction_y -> Double,
//       direction_z -> Double,
//       up_x -> Double,
//       up_y -> Double,
//       up_z -> Double,
//       cargo_items -> Text,
//       cargo_magazines -> Text,
//       cargo_weapons -> Text,
//       cargo_container -> Text,
//       last_updated_at -> Datetime,
//       pin_code -> Varchar,
//       territory_id -> Nullable<Unsigned<Integer>>,
//       deleted_at -> Nullable<Datetime>,
//       money -> Unsigned<Integer>,
//       abandoned -> Nullable<Datetime>,
//   }
// }

// table! {
//   use diesel::sql_types::*;

//   player (id) {
//       id -> Unsigned<Integer>,
//       name -> Varchar,
//       account_uid -> Varchar,
//       money -> Unsigned<Integer>,
//       damage -> Unsigned<Double>,
//       hunger -> Unsigned<Double>,
//       thirst -> Unsigned<Double>,
//       alcohol -> Unsigned<Double>,
//       temperature -> Double,
//       wetness -> Unsigned<Double>,
//       oxygen_remaining -> Unsigned<Double>,
//       bleeding_remaining -> Unsigned<Double>,
//       hitpoints -> Varchar,
//       direction -> Double,
//       position_x -> Double,
//       position_y -> Double,
//       position_z -> Double,
//       spawned_at -> Datetime,
//       assigned_items -> Text,
//       backpack -> Varchar,
//       backpack_items -> Text,
//       backpack_magazines -> Text,
//       backpack_weapons -> Text,
//       current_weapon -> Varchar,
//       goggles -> Varchar,
//       handgun_items -> Text,
//       handgun_weapon -> Varchar,
//       headgear -> Varchar,
//       binocular -> Varchar,
//       loaded_magazines -> Text,
//       primary_weapon -> Varchar,
//       primary_weapon_items -> Text,
//       secondary_weapon -> Varchar,
//       secondary_weapon_items -> Text,
//       uniform -> Varchar,
//       uniform_items -> Text,
//       uniform_magazines -> Text,
//       uniform_weapons -> Text,
//       vest -> Varchar,
//       vest_items -> Text,
//       vest_magazines -> Text,
//       vest_weapons -> Text,
//       last_updated_at -> Datetime,
//   }
// }

// table! {
//   use diesel::sql_types::*;

//   player_history (id) {
//       id -> Unsigned<Integer>,
//       account_uid -> Varchar,
//       name -> Varchar,
//       died_at -> Datetime,
//       position_x -> Double,
//       position_y -> Double,
//       position_z -> Double,
//   }
// }

table! {
  use diesel::sql_types::*;

  territory (id) {
      id -> Unsigned<Integer>,
      esm_custom_id -> Nullable<Varchar>,
      owner_uid -> Varchar,
      name -> Varchar,
      position_x -> Double,
      position_y -> Double,
      position_z -> Double,
      radius -> Double,
      level -> Integer,
      flag_texture -> Varchar,
      flag_stolen -> Bool,
      flag_stolen_by_uid -> Nullable<Varchar>,
      flag_stolen_at -> Nullable<Datetime>,
      created_at -> Datetime,
      last_paid_at -> Nullable<Datetime>,
      xm8_protectionmoney_notified -> Bool,
      build_rights -> Varchar,
      moderators -> Varchar,
      esm_payment_counter -> Unsigned<Integer>,
      deleted_at -> Nullable<Datetime>,
  }
}

// table! {
//   use diesel::sql_types::*;

//   vehicle (id) {
//       id -> Unsigned<Integer>,
//       class -> Varchar,
//       spawned_at -> Datetime,
//       account_uid -> Nullable<Varchar>,
//       is_locked -> Bool,
//       fuel -> Unsigned<Double>,
//       damage -> Unsigned<Double>,
//       hitpoints -> Text,
//       position_x -> Double,
//       position_y -> Double,
//       position_z -> Double,
//       direction_x -> Double,
//       direction_y -> Double,
//       direction_z -> Double,
//       up_x -> Double,
//       up_y -> Double,
//       up_z -> Double,
//       cargo_items -> Text,
//       cargo_magazines -> Text,
//       cargo_weapons -> Text,
//       cargo_container -> Text,
//       last_updated_at -> Datetime,
//       pin_code -> Varchar,
//       deleted_at -> Nullable<Datetime>,
//       money -> Unsigned<Integer>,
//       vehicle_texture -> Text,
//       territory_id -> Nullable<Unsigned<Integer>>,
//       nickname -> Varchar,
//   }
// }

// joinable!(clan_map_marker -> clan (clan_id));
// joinable!(construction -> account (account_uid));
// joinable!(construction -> territory (territory_id));
// joinable!(container -> account (account_uid));
// joinable!(container -> territory (territory_id));
// joinable!(player -> account (account_uid));
// joinable!(vehicle -> account (account_uid));
// joinable!(vehicle -> territory (territory_id));

// allow_tables_to_appear_in_same_query!(
//   account,
//   clan,
//   clan_map_marker,
//   construction,
//   container,
//   player,
//   player_history,
//   territory,
//   vehicle,
// );
