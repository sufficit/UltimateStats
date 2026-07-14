/**
 * Coletor SQLX compatível com AMX Mod X 1.9.
 * Registra as estatísticas essenciais usadas pelo ranking web Sufficit.
 */

#include <amxmodx>
#include <cstrike>
#include <sqlx>

#define PLUGIN "UltimateStats Collector"
#define VERSION "1.0"
#define AUTHOR "Sufficit"
#define MAX_PLAYERS 32

new Handle:g_Tuple;
new bool:g_Connected;
new g_Kills[MAX_PLAYERS + 1], g_Deaths[MAX_PLAYERS + 1], g_Headshots[MAX_PLAYERS + 1], g_TeamKills[MAX_PLAYERS + 1];
new g_SteamId[MAX_PLAYERS + 1][36], g_Ip[MAX_PLAYERS + 1][16], g_ConnectTime[MAX_PLAYERS + 1];
new g_MapName[32];

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    get_mapname(g_MapName, charsmax(g_MapName));
    register_event("DeathMsg", "event_death", "a");
    set_task(1.0, "connect_sql");
}

public plugin_end()
{
    if (g_Tuple)
        SQL_FreeHandle(g_Tuple);
}

public client_connect(id)
{
    g_Kills[id] = 0;
    g_Deaths[id] = 0;
    g_Headshots[id] = 0;
    g_TeamKills[id] = 0;
    get_user_authid(id, g_SteamId[id], charsmax(g_SteamId[]));
    get_user_ip(id, g_Ip[id], charsmax(g_Ip[]), 1);
    g_ConnectTime[id] = get_systime();
}

public client_disconnected(id)
{
    if (g_Connected && !is_user_bot(id) && !is_user_hltv(id) && g_SteamId[id][0])
        save_player(id);
}

public event_death()
{
    new killer = read_data(1);
    new victim = read_data(2);

    if (victim > 0 && victim <= MAX_PLAYERS)
        g_Deaths[victim]++;

    if (killer > 0 && killer <= MAX_PLAYERS && killer != victim)
    {
        g_Kills[killer]++;
        if (read_data(3))
            g_Headshots[killer]++;
        if (cs_get_user_team(killer) == cs_get_user_team(victim))
            g_TeamKills[killer]++;
    }
}

public connect_sql()
{
    g_Tuple = SQL_MakeDbTuple("127.0.0.1", "ultimate_stats", "UltimateStats2025!", "ultimate_stats");
    SQL_ThreadQuery(g_Tuple, "on_connection", "SELECT 1");
}

public on_connection(failState, Handle:query, error[], errorCode, data[], dataSize)
{
    if (failState != TQUERY_SUCCESS)
    {
        log_amx("[UltimateStats] MySQL connection failed (%d): %s", errorCode, error);
        set_task(30.0, "connect_sql");
        return;
    }

    g_Connected = true;
    log_amx("[UltimateStats] MySQL connected");

    new queryData[192];
    formatex(queryData, charsmax(queryData), "INSERT INTO ultimate_stats_maps (mapname, plays) VALUES ('%s', 1) ON DUPLICATE KEY UPDATE plays = plays + 1", g_MapName);
    SQL_ThreadQuery(g_Tuple, "ignore_query", queryData);
}

public save_player(id)
{
    new name[32], queryData[768], duration = get_systime() - g_ConnectTime[id];
    get_user_name(id, name, charsmax(name));
    escape_sql(name, charsmax(name));

    formatex(queryData, charsmax(queryData), "INSERT INTO ultimate_stats (name, steamid, ip, kills, deaths, hs_kills, team_kills, connects, `time`, first_visit, last_visit) VALUES ('%s', '%s', '%s', %d, %d, %d, %d, 1, %d, %d, %d) ON DUPLICATE KEY UPDATE name=VALUES(name), ip=VALUES(ip), kills=kills+VALUES(kills), deaths=deaths+VALUES(deaths), hs_kills=hs_kills+VALUES(hs_kills), team_kills=team_kills+VALUES(team_kills), connects=connects+1, `time`=`time`+VALUES(`time`), last_visit=VALUES(last_visit)", name, g_SteamId[id], g_Ip[id], g_Kills[id], g_Deaths[id], g_Headshots[id], g_TeamKills[id], duration, get_systime(), get_systime());
    SQL_ThreadQuery(g_Tuple, "ignore_query", queryData);
}

public ignore_query(failState, Handle:query, error[], errorCode, data[], dataSize)
{
    if (failState != TQUERY_SUCCESS)
        log_amx("[UltimateStats] SQL query failed (%d): %s", errorCode, error);
}

stock escape_sql(value[], length)
{
    replace_all(value, length, "\\", "\\\\");
    replace_all(value, length, "'", "''");
}
