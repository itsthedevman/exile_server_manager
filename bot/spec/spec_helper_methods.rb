def create_request(**params)
  user = ESM::Test.user.discord_user
  command = ESM::Command::Test::BaseV1.new

  ESM::Websocket::Request.new(
    command: command,
    user: user,
    channel: ESM.bot.channel(ESM::Community::ESM::SPAM_CHANNEL),
    parameters: params
  )
end

# Disables the whitelist on admin commands so the tests can use them
def grant_command_access!(community, command)
  community.command_configurations.where(command_name: command).update_all(whitelist_enabled: false)
end

#
# Mimics sending a discord message for a test.
#
# @param message [String, ESM::Embed] The message to "send"
#
def send_discord_message(message)
  ESM::Test.response = message
end

#
# Waits for a message to be sent from the bot to the server
#
# @return [ESM::Message]
#
def wait_for_outbound_message
  message = nil
  wait_for { message = ESM::Test.outbound_server_messages.shift }.to be_truthy
  message.content
end

#
# Waits for a message to be sent from the client to the bot
#
# @return [ESM::Message]
#
def wait_for_inbound_message
  message = nil
  wait_for { message = ESM::Test.inbound_server_messages.shift }.to be_truthy
  message.content
end

def enable_log_printing
  ENV["PRINT_LOG"] = "true"
end

def disable_log_printing
  ENV["PRINT_LOG"] = "false"
end

def spawn_test_user(user, **attrs)
  attributes = {
    damage: 0,
    hunger: 100,
    thirst: 100,
    alcohol: 0,
    oxygen_remaining: 1,
    bleeding_remaining: 0,
    hitpoints: [["face_hub", 0], ["neck", 0], ["head", 0], ["pelvis", 0], ["spine1", 0], ["spine2", 0], ["spine3", 0], ["body", 0], ["arms", 0], ["hands", 0], ["legs", 0], ["body", 0]],
    direction: 0,
    position_x: 0,
    position_y: 0,
    position_z: 0,
    assigned_items: [],
    backpack: "",
    backpack_items: [],
    backpack_magazines: [],
    backpack_weapons: [],
    current_weapon: "",
    goggles: "",
    handgun_items: ["", "", "", ""],
    handgun_weapon: "",
    headgear: "",
    binocular: "",
    loaded_magazines: [],
    primary_weapon: "",
    primary_weapon_items: ["", "", "", ""],
    secondary_weapon: "",
    secondary_weapon_items: [],
    uniform: "",
    uniform_items: [],
    uniform_magazines: [],
    uniform_weapons: [],
    vest: "",
    vest_items: [],
    vest_magazines: [],
    vest_weapons: [],
    account_money: 0,
    account_score: 0,
    account_kills: 0,
    account_deaths: 0,
    clan_id: "",
    clan_name: "",
    temperature: 37,
    wetness: 0,
    account_locker: 0
  }

  attributes.each { |key, value| attributes[key] = attrs[key] || value }

  # Offset the unused values
  data = ["", "", ""] + attributes.values

  sqf = <<~SQF
    private _data = #{data};
    private _pos2D = (call ExileClient_util_world_getAllAirportPositions) select 0;

    _data set [11, _pos2D select 0];
    _data set [12, _pos2D select 1];

    [_data, objNull, "#{user.steam_uid}", 0] call ExileServer_object_player_database_load;
    _createdPlayer = ([_pos2D select 0, _pos2D select 1, 0] nearEntities ["Exile_Unit_Player", 100]) select 0;
    if (isNil "_createdPlayer") exitWith {};

    ESM_TestUser_#{user.steam_uid} = _createdPlayer;
    _createdPlayer allowDamage false;
    _createdPlayer setDamage 0;

    netId _createdPlayer
  SQF

  response = execute_sqf!(sqf)
  expect(response).not_to be_nil

  # Remove the request and response
  ESM::Test.outbound_server_messages.pop
  ESM::Test.inbound_server_messages.pop

  net_id = response.data.result
  expect(net_id).not_to be_nil

  user.connected = true
  net_id
end

def before_connection(&block)
  ESM::Test.callbacks.add_callback(:before_connection, &block)
end
