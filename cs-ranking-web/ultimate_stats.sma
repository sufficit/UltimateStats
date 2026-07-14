/**
 * UltimateStats Plugin for AMX Mod X
 * Coleta estatísticas de CS 1.6 e grava no MySQL
 *
 * Autor: Sufficit
 * Versão: 1.0
 */

#include <amxmodx>
#include <amxmisc>
#include <csx>
#include <dbi>

#define PLUGIN "UltimateStats"
#define VERSION "1.0"
#define AUTHOR "Sufficit"

#define MAX_PLAYERS 32

// Configurações MySQL
new sql_host[] = "127.0.0.1"
new sql_user[] = "ultimate_stats"
new sql_pass[] = "UltimateStats2025!"
new sql_db[] = "ultimate_stats"

// Tabelas
new Sql:mysql_connection
new bool:mysql_connected = false
new mysql_error[128]

// Stats temporários
new player_kills[MAX_PLAYERS + 1]
new player_deaths[MAX_PLAYERS + 1]
new player_hs_kills[MAX_PLAYERS + 1]
new player_team_kills[MAX_PLAYERS + 1]
new player_weapon_kills[MAX_PLAYERS + 1][31]
new player_weapon_shots[MAX_PLAYERS + 1][31]
new player_weapon_hits[MAX_PLAYERS + 1][31]
new player_steamid[MAX_PLAYERS + 1][36]
new player_ip[MAX_PLAYERS + 1][16]
new player_connect_time[MAX_PLAYERS + 1]
new player_connects[MAX_PLAYERS + 1]
new map_name[32]
new map_plays = 0

// Arma names (weapon list)
new weapon_names[31][] = {
    "", "p228", "", "scout", "hegrenade", "xm1014", "c4", "mac10",
    "aug", "smokegrenade", "elite", "fiveseven", "ump45", "sg550", "galil",
    "famas", "usp", "glock18", "awp", "mp5navy", "m249", "m3", "m4a1",
    "tmp", "g3sg1", "flashbang", "deagle", "sg552", "ak47", "knife", "p90"
}

// Inicialização
public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    // Eventos
    register_event("HLTV", "event_new_round", "a", "1=0", "2=0")

    // Comandos de console
    register_srvcmd("ultimate_stats_sync", "cmd_sync")
    register_srvcmd("ultimate_stats_test", "cmd_test")

    // Conectar MySQL
    set_task(5.0, "connect_mysql")
    get_mapname(map_name, charsmax(map_name))
}

// Cliente conectado
public client_connect(id)
{
    if (!is_user_bot(id) && !is_user_hltv(id))
    {
        // Reset stats
        player_kills[id] = 0
        player_deaths[id] = 0
        player_hs_kills[id] = 0
        player_team_kills[id] = 0
        for (new i = 0; i <= 30; i++)
        {
            player_weapon_kills[id][i] = 0
            player_weapon_shots[id][i] = 0
            player_weapon_hits[id][i] = 0
        }

        get_user_ip(id, player_ip[id], charsmax(player_ip[]), 1)
        get_user_authid(id, player_steamid[id], charsmax(player_steamid[]))
        player_connect_time[id] = get_systime()
        player_connects[id] = 1
    }
}

// Cliente desconectado
public client_disconnected(id)
{
    if (!is_user_bot(id) && !is_user_hltv(id))
    {
        // Atualizar stats no MySQL
        save_player_stats(id)

        // Registrar sessão
        save_player_session(id)
    }
}

// Evento de nova rodada
public event_new_round()
{
    map_plays++
}

// Client killed
public client_death(killer, victim, wpnindex, hitplace, TK)
{
    if (killer > 0 && killer <= MAX_PLAYERS)
    {
        player_kills[killer]++
        if (hitplace == HIT_HEAD)
            player_hs_kills[killer]++

        if (TK)
            player_team_kills[killer]++

        // Weapon stats
        if (wpnindex > 0 && wpnindex <= 30)
            player_weapon_kills[killer][wpnindex]++
    }

    if (victim > 0 && victim <= MAX_PLAYERS)
    {
        player_deaths[victim]++
    }
}

// Weapon shot
public client_weapon_shot(id, wpnindex)
{
    if (id > 0 && id <= MAX_PLAYERS && wpnindex > 0 && wpnindex <= 30)
        player_weapon_shots[id][wpnindex]++
}

// Weapon hit
public client_weapon_hit(id, victim, wpnindex, hitplace)
{
    if (id > 0 && id <= MAX_PLAYERS && wpnindex > 0 && wpnindex <= 30)
    {
        player_weapon_hits[id][wpnindex]++
    }
}

// Conectar MySQL
public connect_mysql()
{
    mysql_connection = dbi_connect(sql_host, sql_user, sql_pass, sql_db, mysql_error, charsmax(mysql_error))

    if (mysql_connection < SQL_OK)
    {
        log_amx("[UltimateStats] MySQL connection failed: %s", mysql_error)
        set_task(30.0, "connect_mysql")
        return
    }

    mysql_connected = true
    log_amx("[UltimateStats] MySQL connected")

    // Inicializar mapa
    init_map()
}

// Inicializar mapa
public init_map()
{
    if (!mysql_connected)
        return

    new query[256]
    formatex(query, charsmax(query), "INSERT INTO ultimate_stats_maps (mapname, plays) VALUES ('%s', 1) ON DUPLICATE KEY UPDATE plays = plays + 1", map_name)
    dbi_query(mysql_connection, query)
}

// Salvar stats do jogador
public save_player_stats(id)
{
    if (!mysql_connected || player_kills[id] == 0)
        return

    new name[32]
    get_user_name(id, name, charsmax(name))

    new query[1024]
    formatex(query, charsmax(query), "INSERT INTO ultimate_stats (name, steamid, ip, kills, deaths, hs_kills, team_kills, connects, `time`, first_visit, last_visit) VALUES ('%s', '%s', '%s', %d, %d, %d, %d, %d, %d, %d, %d) ON DUPLICATE KEY UPDATE name = VALUES(name), ip = VALUES(ip), kills = kills + VALUES(kills), deaths = deaths + VALUES(deaths), hs_kills = hs_kills + VALUES(hs_kills), team_kills = team_kills + VALUES(team_kills), connects = connects + VALUES(connects), `time` = `time` + VALUES(`time`), last_visit = VALUES(last_visit)",
        name, player_steamid[id], player_ip[id],
        player_kills[id], player_deaths[id], player_hs_kills[id], player_team_kills[id],
        player_connects[id], get_systime() - player_connect_time[id], get_systime(), get_systime()
    )

    dbi_query(mysql_connection, query)

    // Salvar stats de armas
    save_weapon_stats(id)
}

// Salvar stats de armas
public save_weapon_stats(id)
{
    if (!mysql_connected)
        return

    new query[1024]

    // Pegar player_id do MySQL
    new player_id = get_player_id_by_steamid(player_steamid[id])
    if (player_id == 0)
        return

    for (new i = 1; i <= 30; i++)
    {
        if (player_weapon_kills[id][i] > 0 || player_weapon_shots[id][i] > 0 || player_weapon_hits[id][i] > 0)
        {
            new weapon_name[20]
            copy(weapon_name, charsmax(weapon_name), weapon_names[i])

            formatex(query, charsmax(query), "INSERT INTO ultimate_stats_weapons (player_id, weapon, kills, shots, hits) VALUES (%d, '%s', %d, %d, %d) ON DUPLICATE KEY UPDATE kills = kills + VALUES(kills), shots = shots + VALUES(shots), hits = hits + VALUES(hits)", player_id, weapon_name, player_weapon_kills[id][i], player_weapon_shots[id][i], player_weapon_hits[id][i])

            dbi_query(mysql_connection, query)
        }
    }
}

// Salvar sessão
public save_player_session(id)
{
    if (!mysql_connected)
        return

    new player_id = get_player_id_by_steamid(player_steamid[id])
    if (player_id == 0)
        return

    new query[512]
    formatex(query, charsmax(query), "INSERT INTO ultimate_stats_sessions (player_id, connect_time, disconnect_time, duration, ip, hostname) VALUES (%d, %d, %d, %d, '%s', '%s')", player_id, player_connect_time[id], get_systime(), get_systime() - player_connect_time[id], player_ip[id], map_name)

    dbi_query(mysql_connection, query)
}

// Pegar player_id pelo steamid
public get_player_id_by_steamid(steamid[])
{
    new query[256]
    new Result:result
    new player_id = 0

    formatex(query, charsmax(query), "SELECT id FROM ultimate_stats WHERE steamid = '%s'", steamid)
    result = dbi_query(mysql_connection, query)

    if (result > RESULT_NONE && dbi_nextrow(result) > 0)
        dbi_result(result, "id", player_id)

    dbi_free_result(result)
    return player_id
}

// Comando de teste
public cmd_test()
{
    if (mysql_connected)
        server_print("[UltimateStats] MySQL connection OK")
    else
        server_print("[UltimateStats] MySQL connection FAILED")
}

// Comando de sync manual
public cmd_sync()
{
    new count = 0
    for (new i = 1; i <= MAX_PLAYERS; i++)
    {
        if (is_user_connected(i) && !is_user_bot(i) && !is_user_hltv(i))
        {
            save_player_stats(i)
            count++
        }
    }
    server_print("[UltimateStats] Synced %d players", count)
}

// Plugin end
public plugin_end()
{
    if (mysql_connection > SQL_OK)
        dbi_close(mysql_connection)
}
