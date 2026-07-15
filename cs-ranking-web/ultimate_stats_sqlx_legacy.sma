#include <amxmodx>
#include <cstrike>
#include <sqlx>

#define MAXP 32

new Handle:g_Db;
new bool:g_Ready;
new g_Kills[MAXP + 1], g_Deaths[MAXP + 1], g_Hs[MAXP + 1], g_Tk[MAXP + 1], g_Joined[MAXP + 1];
new g_Steam[MAXP + 1][36], g_Ip[MAXP + 1][16];
new g_Host, g_User, g_Pass, g_Name;

public plugin_init()
{
    register_plugin("UltimateStats SQLX", "1.0", "Sufficit");
    register_event("DeathMsg", "on_death", "a");
    g_Host = register_cvar("ultimate_stats_host", "127.0.0.1");
    g_User = register_cvar("ultimate_stats_user", "ultimate_stats");
    g_Pass = register_cvar("ultimate_stats_pass", "");
    g_Name = register_cvar("ultimate_stats_db", "ultimate_stats");
}

public plugin_cfg()
{
    server_cmd("exec addons/amxmodx/configs/ultimate_stats.cfg");
    set_task(1.0, "connect_db");
}

public connect_db()
{
    new host[64], user[64], pass[64], name[64];
    get_pcvar_string(g_Host, host, charsmax(host));
    get_pcvar_string(g_User, user, charsmax(user));
    get_pcvar_string(g_Pass, pass, charsmax(pass));
    get_pcvar_string(g_Name, name, charsmax(name));
    g_Db = SQL_MakeDbTuple(host, user, pass, name);
    SQL_ThreadQuery(g_Db, "on_connect", "SELECT 1");
}

public on_connect(fail, Handle:query, error[], errornum, data[], size)
{
    if (fail != TQUERY_SUCCESS) { log_amx("[UltimateStats] SQL failed %d: %s", errornum, error); set_task(30.0, "connect_db"); return; }
    g_Ready = true;
    log_amx("[UltimateStats] MySQL connected");
}

public client_connect(id)
{
    g_Kills[id] = g_Deaths[id] = g_Hs[id] = g_Tk[id] = 0;
    g_Joined[id] = get_systime();
    g_Steam[id][0] = 0;
}

public client_authorized(id)
{
    get_user_authid(id, g_Steam[id], charsmax(g_Steam[]));
    get_user_ip(id, g_Ip[id], charsmax(g_Ip[]), 1);
}

public client_disconnect(id)
{
    if (g_Ready && !is_user_bot(id) && containi(g_Steam[id], "STEAM_") == 0) save(id);
}

public on_death()
{
    new killer = read_data(1), victim = read_data(2);
    if (victim > 0 && victim <= MAXP) g_Deaths[victim]++;
    if (killer > 0 && killer <= MAXP && killer != victim) { g_Kills[killer]++; if (read_data(3)) g_Hs[killer]++; if (cs_get_user_team(killer) == cs_get_user_team(victim)) g_Tk[killer]++; }
}

public save(id)
{
    new nick[32], q[768], now = get_systime(), duration = now - g_Joined[id];
    get_user_name(id, nick, charsmax(nick));
    replace_all(nick, charsmax(nick), "'", "''");
    formatex(q, charsmax(q), "INSERT INTO ultimate_stats (name,steamid,ip,kills,deaths,hs_kills,team_kills,connects,`time`,first_visit,last_visit) VALUES ('%s','%s','%s',%d,%d,%d,%d,1,%d,%d,%d) ON DUPLICATE KEY UPDATE name=VALUES(name),ip=VALUES(ip),kills=kills+VALUES(kills),deaths=deaths+VALUES(deaths),hs_kills=hs_kills+VALUES(hs_kills),team_kills=team_kills+VALUES(team_kills),connects=connects+1,`time`=`time`+VALUES(`time`),last_visit=VALUES(last_visit)", nick,g_Steam[id],g_Ip[id],g_Kills[id],g_Deaths[id],g_Hs[id],g_Tk[id],duration,now,now);
    SQL_ThreadQuery(g_Db, "on_query", q);
}

public on_query(fail, Handle:query, error[], errornum, data[], size)
{
    if (fail != TQUERY_SUCCESS) log_amx("[UltimateStats] SQL write failed %d: %s", errornum, error);
}
