#pragma semicolon 1

#define COIN_MODEL_PATH "models/coin.mdl"
#define COIN_SOUND_PATH "events/tutor_msg"
#define is_player(%1) !is_user_bot(%1) && !is_user_hltv(%1)
#define STEAMID_SIZE 35

/**
 * Determines whether the database connection settings from sql.cfg will be used.
 */
#define USING_SQL

#include <amxmodx>
#include <amxmisc>
#include <fakemeta_util>
#include <reapi>
#include <sqlx>

new const PLUGIN_NAME[] = "Coins";
new const PLUGIN_VERSION[] = "2.0.3";
new const PLUGIN_AUTHOR[] = "6u3oH && Clay Whitelytning";

const TASK_HUDIFNO = 0xA63;
const SC_HANDLED = 0xA734;
new const Float: ENT_MINSIZE[] = { -2.0, -9.0, -1.0 };
new const Float: ENT_MAXSIZE[] = { 2.0, 7.0, 17.0 };

enum FWD_TYPE
{
  GIVE_COINS_PRE,
  GIVE_COINS_POST,
  COINS_PICKUP_PRE,
  COINS_PICKUP_POST,
  COIN_PULL
};

new cvar_sql_host, 
  cvar_sql_user, 
  cvar_sql_pass, 
  cvar_sql_db, 
  cvar_sql_table,

  cvar_coin_priv_flag,
  cvar_coin_anim_type, 
  cvar_coin_give_kill, 
  cvar_coin_give_kill_head, 
  cvar_coin_give_kill_grenade, 
  cvar_coin_give_kill_knife, 
  cvar_coin_give_kill_flag, 
  cvar_coin_give_alive, 
  cvar_coin_glow_amount,
   
  cvar_coin_pull_enable, 
  cvar_coin_hud_enable, 
  cvar_coin_glow_enable, 
  cvar_coin_clear, 
  cvar_coin_drop_only_killer,
  
  cvar_coin_pull_radius, 
  cvar_coin_anim_time, 
  cvar_coin_glow_color_red, 
  cvar_coin_glow_color_green, 
  cvar_coin_glow_color_blue,
  
  cvar_coin_hud_color_red,
  cvar_coin_hud_color_green,
  cvar_coin_hud_color_blue,
  cvar_coin_hud_position_x,
  cvar_coin_hud_position_y;

new players[MAX_PLAYERS + 1], // Contains the number of coins
    bool:connected[MAX_PLAYERS + 1], // Determines the connection status
    forwards[FWD_TYPE]; 
new Handle: sql_tuple, Handle: sql_connection;

@register_cvars()
{
  cvar_coin_priv_flag = register_cvar("coin_priv_flag", "t");
  cvar_coin_give_kill = register_cvar("coin_give_kill", "1");
  cvar_coin_give_kill_head = register_cvar("coin_give_kill_head", "1");
  cvar_coin_give_kill_knife	= register_cvar("coin_give_kill_knife", "1");
  cvar_coin_give_kill_grenade = register_cvar("coin_give_kill_grenade", "1");
  cvar_coin_give_kill_flag = register_cvar("coin_give_kill_flag", "1");
  cvar_coin_give_alive=	register_cvar("coin_give_alive", "3");
  cvar_coin_drop_only_killer = register_cvar("coin_drop_only_killer", "0");
  cvar_coin_anim_type = register_cvar("coin_anim_type", "1");
  cvar_coin_anim_time = register_cvar("coin_anim_time", "0.5");
  cvar_coin_glow_enable	= register_cvar("coin_glow_enable", "1");
  cvar_coin_glow_color_red = register_cvar("coin_glow_color_red", "255");
  cvar_coin_glow_color_green = register_cvar("coin_glow_color_green", "255");
  cvar_coin_glow_color_blue	= register_cvar("coin_glow_color_blue", "128");
  cvar_coin_glow_amount	= register_cvar("coin_glow_amount", "45");
  cvar_coin_pull_enable	= register_cvar("coin_pull_enable", "1");
  cvar_coin_pull_radius	= register_cvar("coin_pull_radius", "500.0");
  cvar_coin_hud_enable = register_cvar("coin_hud_enable", "1");
  cvar_coin_hud_color_red = register_cvar("coin_hud_color_red", "200");
  cvar_coin_hud_color_green = register_cvar("coin_hud_color_green", "100");
  cvar_coin_hud_color_blue = register_cvar("coin_hud_color_blue", "0");
  cvar_coin_hud_position_x = register_cvar("coin_hud_position_x", "0.01");
  cvar_coin_hud_position_y = register_cvar("coin_hud_position_y", "0.31");
  cvar_coin_clear = register_cvar("coin_clear", "1");

  #if defined USING_SQL
  cvar_sql_host	= register_cvar("amx_sql_host", "127.0.0.1", FCVAR_PROTECTED);
  cvar_sql_db	= register_cvar("amx_sql_db", "amxx", FCVAR_PROTECTED);
  cvar_sql_user	= register_cvar("amx_sql_user", "root", FCVAR_PROTECTED);
  cvar_sql_pass	= register_cvar("amx_sql_pass", "", FCVAR_PROTECTED);
  #else
  cvar_sql_host	= register_cvar("coin_sql_host", "127.0.0.1", FCVAR_PROTECTED);
  cvar_sql_db	= register_cvar("coin_sql_db", "amxx", FCVAR_PROTECTED);
  cvar_sql_user	= register_cvar("coin_sql_user", "root", FCVAR_PROTECTED);
  cvar_sql_pass	= register_cvar("coin_sql_pass", "", FCVAR_PROTECTED);
  #endif
  
  cvar_sql_table = register_cvar("coin_sql_table", "coins", FCVAR_PROTECTED);
}

@register_forwards()
{
  forwards[GIVE_COINS_PRE] = CreateMultiForward("sc_give_coins_pre", ET_STOP, FP_CELL, FP_CELL);
  forwards[GIVE_COINS_POST] = CreateMultiForward("sc_give_coins_post", ET_IGNORE, FP_CELL, FP_CELL);
  forwards[COINS_PICKUP_PRE] = CreateMultiForward("sc_coins_pickup_pre", ET_STOP, FP_CELL, FP_CELL);
  forwards[COINS_PICKUP_POST] = CreateMultiForward("sc_coins_pickup_post", ET_IGNORE, FP_CELL, FP_CELL);
  forwards[COIN_PULL] = CreateMultiForward("sc_coin_pull", ET_STOP, FP_CELL, FP_CELL);
}

@load_config()
{
  new filepath[128];
  get_localinfo("amxx_configsdir", filepath, charsmax(filepath));
  formatex(filepath, charsmax(filepath), "%s/%s", filepath, "coins.cfg");
  server_cmd("exec %s", filepath);
}

public plugin_precache()
{	
  precache_model(COIN_MODEL_PATH);

  new filepath[128];
  format(filepath, charsmax(filepath), "%s.%s", COIN_SOUND_PATH, "wav");
  precache_sound(filepath);
}

public plugin_natives()
{
  register_native("get_user_coins", "@native_get_user_coins");
  register_native("set_user_coins", "@native_set_user_coins");
  register_native("user_drop_coins", "@native_user_drop_coins");
}

public plugin_init()
{
  register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
  register_dictionary("coins.txt");

  @register_cvars();
  @register_forwards();
  @load_config();

  RegisterHookChain(RG_CBasePlayer_Killed, "@CBasePlayer_Killed_Post", true);
  RegisterHookChain(RG_RoundEnd, "@RoundEnd_Post", true);

  if(get_pcvar_bool(cvar_coin_clear)) {
    RegisterHookChain(RG_CSGameRules_CleanUpMap, "@CSGameRules_CleanUpMap", true);
  }
}

public client_putinserver(id)
{
  if (is_player(id)) {
    if(get_pcvar_bool(cvar_coin_hud_enable))
      set_task(1.0, "@show_hud_info", id + TASK_HUDIFNO, .flags = "b");

    players[id] = 0;
    connected[id] = true;
    @sql_read_client(id);
  }
}

public client_disconnected(id)
{
  if(get_pcvar_bool(cvar_coin_hud_enable))
    remove_task(id + TASK_HUDIFNO);

  players[id] = 0;
  connected[id] = false;
}

@RoundEnd_Post(WinStatus: status, ScenarioEventEndRound: event, delay)
{
  if(status == WINSTATUS_TERRORISTS || status == WINSTATUS_CTS) {
    new coin_add_alive = get_pcvar_num(cvar_coin_give_alive);
    if (coin_add_alive) {
      for(new id = 0; id <= MAX_PLAYERS; ++id) {
        if (connected[id] && is_user_alive(id)) {
          set_user_coins(id, players[id] += coin_add_alive);
        }
      }
    }
  }
}

public plugin_cfg()
{
  @connect_database();
}

@connect_database()
{
  new error, data[256], sql_host[32], sql_user[32], sql_pass[32], sql_db[32];
  get_pcvar_string(cvar_sql_host, sql_host, charsmax(sql_host));
  get_pcvar_string(cvar_sql_user, sql_user, charsmax(sql_user));
  get_pcvar_string(cvar_sql_pass, sql_pass, charsmax(sql_pass));
  get_pcvar_string(cvar_sql_db, sql_db, charsmax(sql_db));

  sql_tuple = SQL_MakeDbTuple(sql_host, sql_user, sql_pass, sql_db);
  sql_connection = SQL_Connect(sql_tuple, error, data, charsmax(data));
  
  if(sql_connection == Empty_Handle)
    set_fail_state("[%s] Error connecting to database (mysql)^nError: %s", PLUGIN_NAME, data);
  
  SQL_FreeHandle(sql_connection);
  @check_table();
}

@check_table()
{
  new sql_table[32], data[256];
  get_pcvar_string(cvar_sql_table, sql_table, charsmax(sql_table));

  format(data, charsmax(data), "CREATE TABLE IF NOT EXISTS `%s` \
  (`steamid` varchar(%d) PRIMARY KEY NOT NULL, \
  `count` int NOT NULL)", sql_table, STEAMID_SIZE);
  
  SQL_ThreadQuery(sql_tuple, "@query_func_handler", .query = data);
}

@sql_read_client(id)
{  
  if (connected[id]) {
    new sql_table[32], index[2], data[256];
    get_pcvar_string(cvar_sql_table, sql_table, charsmax(sql_table));

    new authid[STEAMID_SIZE];
    get_user_authid(id, authid, charsmax(authid));
    format(data, charsmax(data), "SELECT count FROM %s WHERE steamid = '%s'", sql_table, authid);

    index[0] = id;
    SQL_ThreadQuery(sql_tuple, "@query_read_handler", data, index, charsmax(index));
  }
}

@query_func_handler(fail_state, Handle: query_handle, error_msg[], error_code, data[], size, Float: queue)
{
  if(fail_state != TQUERY_SUCCESS) {
    server_print("[%s] %s", PLUGIN_NAME, error_msg);
    log_amx("[%s] %s", PLUGIN_NAME, error_msg);
  }	
  SQL_FreeHandle(query_handle);
}

@query_read_handler(fail_state, Handle: query_handle, error_msg[], error_code, data[], size, Float: queue)
{
  if(size && fail_state == TQUERY_SUCCESS) {
    new id = data[0];
    if(connected[id] && SQL_NumResults(query_handle)) {
      players[id] = SQL_ReadResult(query_handle, 0);
    }
  } else {
    server_print("[%s] %s", PLUGIN_NAME, error_msg);
    log_amx("[%s] %s", PLUGIN_NAME, error_msg);
  }
  SQL_FreeHandle(query_handle);
}

bool:@sql_save_client(id)
{
  new bool:result = false;
  if ((result = connected[id])) {
    new sql_table[32], data[256], authid[STEAMID_SIZE];

    get_user_authid(id, authid, charsmax(authid));
    get_pcvar_string(cvar_sql_table, sql_table, charsmax(sql_table));
    format(data, charsmax(data), "REPLACE INTO %s (steamid, count) VALUES ('%s', '%i')", sql_table, authid, players[id]);
    
    SQL_ThreadQuery(sql_tuple, "@query_func_handler", .query = data);
  }
  return result;
}

public plugin_end()
{
  if(sql_tuple) SQL_FreeHandle(sql_tuple);
}

// -----------------------------------------------------------------------------

bool:set_user_coins(id, number)
{   
  new result;
  ExecuteForward(forwards[GIVE_COINS_PRE], result, id, number);

  if(result != SC_HANDLED) {
    ExecuteForward(forwards[GIVE_COINS_POST], result, id, players[id] - number);

    players[id] = number;
    return @sql_save_client(id);
  }
  return false;
}

@show_hud_info(id)
{
  id -= TASK_HUDIFNO;
  if (connected[id] && is_user_alive(id)) {
    set_hudmessage(
      get_pcvar_num(cvar_coin_hud_color_red), 
      get_pcvar_num(cvar_coin_hud_color_green), 
      get_pcvar_num(cvar_coin_hud_color_blue), 
      get_pcvar_float(cvar_coin_hud_position_x), 
      get_pcvar_float(cvar_coin_hud_position_y), .holdtime = 1.0, .channel = 3);
    show_hudmessage(id, "%L: %i", LANG_PLAYER, "MONEY", players[id]);
  }
}

// -----------------------------------------------------------------------------

@CSGameRules_CleanUpMap()
{
  new entity = FM_NULLENT;
  while((entity = rg_find_ent_by_class(entity, "ent_coin"))) {
    if(!is_nullent(entity)) {
      set_entvar(entity, var_flags, FL_KILLME);
    }
  }
}

@CBasePlayer_Killed_Post(victim, killer)
{
  if(connected[killer] && connected[victim] && victim != killer) {
    new coin_kill_head = get_pcvar_num(cvar_coin_give_kill_head);
    new coin_kill_grenade = get_pcvar_num(cvar_coin_give_kill_grenade);
    new coin_kill_knife = get_pcvar_num(cvar_coin_give_kill_knife);
    new coin_kill_flag = get_pcvar_num(cvar_coin_give_kill_flag);
    new coins = get_pcvar_num(cvar_coin_give_kill);
    
    if (get_member(killer, m_LastHitGroup) == HIT_HEAD)
      coins += coin_kill_head;
    
    if (get_member(killer, m_bitsDamageType) & DMG_GRENADE)
      coins += coin_kill_grenade;
    
    new item = get_member(killer, m_pActiveItem);
    if(!is_nullent(item) && get_member(item, m_iId) == WEAPON_KNIFE && killer == get_entvar(victim, var_dmg_inflictor))
      coins += coin_kill_knife;
    
    new string_flags[28];
    get_pcvar_string(cvar_coin_priv_flag, string_flags, charsmax(string_flags));

    new flags = read_flags(string_flags);		
    if (get_user_flags(killer) & flags) {
      coins += coin_kill_flag;
    }

    set_user_coins(victim, players[victim] -= coins);
    for (new i = 0; i < coins; ++i) @sc_create_ent_coin(victim, killer);
  }
}

// -----------------------------------------------------------------------------

@ent_set_glow(entity, color[3])
{
  new Float: render_color[3];
  new Float:coin_glow_amount = get_pcvar_float(cvar_coin_glow_amount);

  IVecFVec(color, render_color);
  
  set_entvar(entity, var_renderfx, kRenderFxGlowShell);
  set_entvar(entity, var_rendercolor, render_color);
  set_entvar(entity, var_rendermode, kRenderNormal);
  set_entvar(entity, var_renderamt, coin_glow_amount);
}

@sc_create_ent_coin(victim, killer)
{
  #define TIME_NEXTTHINK 0.1
  #define RANDOM_ANGLES 180.0
  #define RANDOM_VELOCITY 250.0
  
  new entity, Float: origin[3], Float: angles[3], Float: velocity[3];
  new coin_anim_type = get_pcvar_num(cvar_coin_anim_type);
  new Float:coin_anim_time = get_pcvar_float(cvar_coin_anim_time);

  entity = rg_create_entity("func_wall");
  
  get_entvar(victim, var_origin, origin);
  origin[2] += ENT_MAXSIZE[2];
  
  angles[1] = random_float(-RANDOM_ANGLES, RANDOM_ANGLES);
  
  velocity[0] = random_float(-RANDOM_VELOCITY, RANDOM_VELOCITY);
  velocity[1] = random_float(-RANDOM_VELOCITY, RANDOM_VELOCITY);
  velocity[2] = random_float(-RANDOM_VELOCITY, RANDOM_VELOCITY);
  
  engfunc(EngFunc_SetOrigin, entity, origin);
  engfunc(EngFunc_SetModel, entity, COIN_MODEL_PATH);
  engfunc(EngFunc_SetSize, entity, ENT_MINSIZE, ENT_MAXSIZE);
  
  set_entvar(entity, var_classname, "ent_coin");
  set_entvar(entity, var_solid, SOLID_TRIGGER);
  set_entvar(entity, var_movetype, MOVETYPE_TOSS);
  set_entvar(entity, var_sequence, coin_anim_type);
  set_entvar(entity, var_framerate, coin_anim_time);
  set_entvar(entity, var_angles, angles);
  
  if(get_pcvar_bool(cvar_coin_drop_only_killer) && is_user_connected(killer))
  {
    set_entvar(entity, var_owner, killer);
    set_entvar(entity, var_effects, EF_OWNER_VISIBILITY);
  }

  if(get_pcvar_bool(cvar_coin_glow_enable)) {
    new glow_color[3];

    glow_color[0] = get_pcvar_num(cvar_coin_glow_color_red);
    glow_color[1] = get_pcvar_num(cvar_coin_glow_color_green);
    glow_color[2] = get_pcvar_num(cvar_coin_glow_color_blue);

    @ent_set_glow(entity, glow_color);
  }

  set_entvar(entity, var_velocity, velocity);
  
  if(get_pcvar_bool(cvar_coin_pull_enable))
  {
    SetThink(entity, "@coin_think");
    set_entvar(entity, var_nextthink, get_gametime() + TIME_NEXTTHINK);
  }
  
  SetTouch(entity, "@coin_touch");
  
  #undef TIME_NEXTTHINK
  #undef RANDOM_ANGLES
  #undef RANDOM_VELOCITY
}

@coin_think(entity)
{
  #define UP_ORIGIN 10
  #define TIME_NEXTTHINK 0.1
  #define VELOCITY_MUL 999.0
  
  new Float:coin_pull_radius = get_pcvar_float(cvar_coin_pull_radius);
  static Float: game_time; game_time = get_gametime();
  set_entvar(entity, var_nextthink, game_time + TIME_NEXTTHINK);
  
  static id, Float: origin_start[3], Float: origin_end[3], Float: velocity[3], Float: min_dist, Float: temp, index_pull, owner;
  
  get_entvar(entity, var_origin, origin_start); origin_start[2] += UP_ORIGIN;
  id = index_pull = FM_NULLENT;
  min_dist = coin_pull_radius;
  owner = get_entvar(entity, var_owner);
  
  new string_flags[28];
  get_pcvar_string(cvar_coin_priv_flag, string_flags, charsmax(string_flags));

  new flags = read_flags(string_flags);
  while((id = engfunc(EngFunc_FindEntityInSphere, id, origin_start, coin_pull_radius))) {
    if(!is_user_alive(id) || !(get_user_flags(id) & flags) || (get_pcvar_bool(cvar_coin_drop_only_killer) && id != owner))
      continue;
  
    get_entvar(id, var_origin, origin_end);
    
    if(!fm_is_ent_visible(id, entity))
      continue;
    
    temp = get_distance_f(origin_start, origin_end);
    if(temp < min_dist)
    {
      min_dist = temp;
      index_pull = id;
    }
  }

  if(!is_user_alive(index_pull))
    return;
  
  static result;
  ExecuteForward(forwards[COIN_PULL], result, index_pull, entity);
  
  if(result != SC_HANDLED) {
    get_entvar(index_pull, var_origin, origin_end);
    
    xs_vec_sub(origin_end, origin_start, velocity);
    xs_vec_normalize(velocity, velocity);
    xs_vec_mul_scalar(velocity, VELOCITY_MUL, velocity);
      
    set_entvar(entity, var_velocity, velocity);
  }
  
  #undef UP_ORIGIN
  #undef TIME_NEXTTHINK
  #undef VELOCITY_MUL
}

@coin_touch(entity, id)
{
  #define TIME_NEXTTCHEK 0.1

  if(!is_user_connected(id))
    return;
  
  static Float: game_time, Float: next_time[MAX_PLAYERS+1];
  game_time = get_gametime();
  
  if(next_time[id] < game_time) {
    next_time[id] = game_time + TIME_NEXTTCHEK;
  
    if(get_pcvar_bool(cvar_coin_drop_only_killer) && get_entvar(entity, var_owner) != id)
      return;
  
    static result;
    ExecuteForward(forwards[COINS_PICKUP_PRE], result, id, entity);
    
    if(result != SC_HANDLED) {
      if (set_user_coins(id, ++players[id]))
        client_cmd(id, "spk %s", COIN_SOUND_PATH);
      
      SetThink(entity, "");
      SetTouch(entity, "");
      set_entvar(entity, var_flags, FL_KILLME);
      
      ExecuteForward(forwards[COINS_PICKUP_POST], result, id, entity);
    }
  }
  
  #undef TIME_NEXTTCHEK
}

// -----------------------------------------------------------------------------

/**
 * Returns the number of coins the player has (-1 if the player is not found).
 * @return int
 */
@native_get_user_coins()
{ 
  new id = get_param(1);
  return connected[id] ? players[id] : -1;
}

/**
 * Sets the specified number of coins.
 * @return bool
 */
bool:@native_set_user_coins()
{ 
  new id = get_param(1);
  new count = get_param(2);
  return set_user_coins(id, count); 
}

/**
 * Drops the player a certain number of coins.
 * @return bool
 */
bool:@native_user_drop_coins()
{
  new id = get_param(1);
  new count = get_param(2);
  new bool:result = false;

  if ((result = set_user_coins(id, count))) {  
    for(new coin = 0; coin < count; ++coin) {
      @sc_create_ent_coin(id, 0);
    }
  }
  return result;
}