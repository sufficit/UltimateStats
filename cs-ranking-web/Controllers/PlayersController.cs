using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using System.Data;

namespace CSRanking.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PlayersController : ControllerBase
{
    private readonly ILogger<PlayersController> _logger;
    private readonly IConfiguration _config;
    private readonly string _connectionString;

    public PlayersController(ILogger<PlayersController> logger, IConfiguration config)
    {
        _logger = logger;
        _config = config;
        _connectionString = BuildConnectionString();
    }

    private string BuildConnectionString()
    {
        var dbHost = _config.GetValue<string>("Database:Host") ?? "localhost";
        var dbPort = _config.GetValue<int>("Database:Port");
        var dbName = _config.GetValue<string>("Database:Database");
        var dbUser = _config.GetValue<string>("Database:Username");
        var dbPass = _config.GetValue<string>("Database:Password");

        return $"Server={dbHost};Port={dbPort};Database={dbName};User Id={dbUser};Password={dbPass};SslMode=None;";
    }

    private int GetRankmin()
    {
        try
        {
            var rankminValue = _config.GetValue<int>("Ranking:MinKills", 10);

            // Buscar do banco de dados se não estiver no config
            using var connection = new MySqlConnection(_connectionString);
            connection.Open();

            var command = new MySqlCommand("SELECT CAST(setting_value AS UNSIGNED) FROM ultimate_stats_settings WHERE setting_key = 'rankmin'", connection);
            var result = command.ExecuteScalar();

            if (result != null && result != DBNull.Value)
            {
                rankminValue = Convert.ToInt32(result);
            }
            
            return rankminValue;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erro ao buscar rankmin do banco");
            return 10; // Default value
        }
    }

    private string GetTimeFilterCondition(string timeFilter)
    {
        return timeFilter switch
        {
            "1h" => "AND DATE_SUB(NOW(), INTERVAL 1 HOUR) <= last_played",
            "5h" => "AND DATE_SUB(NOW(), INTERVAL 5 HOUR) <= last_played",
            "1d" => "AND DATE_SUB(NOW(), INTERVAL 1 DAY) <= last_played",
            "7d" => "AND DATE_SUB(NOW(), INTERVAL 7 DAY) <= last_played",
            "all" => "",
            _ => "AND DATE_SUB(NOW(), INTERVAL 1 HOUR) <= last_played" // Default: 1h
        };
    }

    [HttpGet]
    [HttpGet("{id}")]
    public async Task<IActionResult> GetPlayers(int? id = null, string? timeFilter = null)
    {
        try
        {
            timeFilter = string.IsNullOrEmpty(timeFilter) ? "1h" : timeFilter;
            var rankmin = GetRankmin();
            var timeFilterCondition = GetTimeFilterCondition(timeFilter);

            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();

            if (id.HasValue)
            {
                // Buscar jogador específico
                var command = new MySqlCommand(
                    @"SELECT id, steamid, name, kills, deaths, hs_kills, 
                             ROUND(CAST(kills AS DECIMAL) / GREATEST(deaths, 1), 2) AS kdr,
                             ROUND(skill, 0) AS skill, 
                             ROUND((hs_kills * 100.0 / GREATEST(kills, 1)), 2) AS hs_percent,
                             time, last_played
                      FROM ultimate_stats 
                      WHERE id = @id", connection);
                command.Parameters.AddWithValue("@id", id.Value);

                using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
                if (await reader.ReadAsync())
                {
                    DateTime? lastPlayed = null;
                    if (!reader.IsDBNull("last_played"))
                    {
                        lastPlayed = reader.GetDateTime("last_played");
                    }

                    var player = new
                    {
                        id = reader.GetInt32("id"),
                        steamid = reader.GetString("steamid"),
                        name = reader.GetString("name"),
                        kills = reader.GetInt32("kills"),
                        deaths = reader.GetInt32("deaths"),
                        hs_kills = reader.GetInt32("hs_kills"),
                        kdr = reader.GetDecimal("kdr"),
                        skill = reader.GetDecimal("skill"),
                        hs_percent = reader.GetDecimal("hs_percent"),
                        time = reader.GetInt32("time"),
                        last_played = lastPlayed
                    };

                    return Ok(new { success = true, data = player });
                }
                else
                {
                    return NotFound(new { success = false, error = "Jogador não encontrado" });
                }
            }
            else
            {
                // Buscar todos os jogadores com filtros
                var command = new MySqlCommand(
                    $@"SELECT id, steamid, name, kills, deaths, hs_kills,
                              ROUND(CAST(kills AS DECIMAL) / GREATEST(deaths, 1), 2) AS kdr,
                              ROUND(skill, 0) AS skill,
                              ROUND((hs_kills * 100.0 / GREATEST(kills, 1)), 2) AS hs_percent,
                              time, last_played
                       FROM ultimate_stats
                       WHERE kills >= @rankmin
                       {timeFilterCondition}
                       ORDER BY skill DESC
                       LIMIT 100", connection);
                command.Parameters.AddWithValue("@rankmin", rankmin);

                using var reader = await command.ExecuteReaderAsync();
                var players = new List<object>();

                while (await reader.ReadAsync())
                {
                    DateTime? lastPlayed = null;
                    if (!reader.IsDBNull("last_played"))
                    {
                        lastPlayed = reader.GetDateTime("last_played");
                    }

                    players.Add(new
                    {
                        id = reader.GetInt32("id"),
                        steamid = reader.GetString("steamid"),
                        name = reader.GetString("name"),
                        kills = reader.GetInt32("kills"),
                        deaths = reader.GetInt32("deaths"),
                        hs_kills = reader.GetInt32("hs_kills"),
                        kdr = reader.GetDecimal("kdr"),
                        skill = reader.GetDecimal("skill"),
                        hs_percent = reader.GetDecimal("hs_percent"),
                        time = reader.GetInt32("time"),
                        last_played = lastPlayed
                    });
                }

                return Ok(new { success = true, data = players, timeFilter = timeFilter });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erro ao buscar jogadores");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    [HttpGet("search")]
    public async Task<IActionResult> SearchPlayers(string query, string? timeFilter = null)
    {
        try
        {
            timeFilter = string.IsNullOrEmpty(timeFilter) ? "1h" : timeFilter;
            var rankmin = GetRankmin();
            var timeFilterCondition = GetTimeFilterCondition(timeFilter);

            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();

            var command = new MySqlCommand(
                $@"SELECT id, steamid, name, kills, deaths, hs_kills,
                          ROUND(CAST(kills AS DECIMAL) / GREATEST(deaths, 1), 2) AS kdr,
                          ROUND(skill, 0) AS skill,
                          ROUND((hs_kills * 100.0 / GREATEST(kills, 1)), 2) AS hs_percent,
                          time, last_played
                   FROM ultimate_stats
                   WHERE kills >= @rankmin
                   {timeFilterCondition}
                   AND name LIKE CONCAT('%', @query, '%')
                   ORDER BY skill DESC
                   LIMIT 50", connection);
            command.Parameters.AddWithValue("@rankmin", rankmin);
            command.Parameters.AddWithValue("@query", query);

            using var reader = await command.ExecuteReaderAsync();
            var players = new List<object>();

            while (await reader.ReadAsync())
            {
                DateTime? lastPlayed = null;
                if (!reader.IsDBNull("last_played"))
                {
                    lastPlayed = reader.GetDateTime("last_played");
                }

                players.Add(new
                {
                    id = reader.GetInt32("id"),
                    steamid = reader.GetString("steamid"),
                    name = reader.GetString("name"),
                    kills = reader.GetInt32("kills"),
                    deaths = reader.GetInt32("deaths"),
                    hs_kills = reader.GetInt32("hs_kills"),
                    kdr = reader.GetDecimal("kdr"),
                    skill = reader.GetDecimal("skill"),
                    hs_percent = reader.GetDecimal("hs_percent"),
                    time = reader.GetInt32("time"),
                    last_played = lastPlayed
                });
            }

            return Ok(new { success = true, data = players });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erro ao buscar jogadores");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    [HttpPost("clear")]
    public async Task<IActionResult> ClearDatabase()
    {
        try
        {
            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();

            // Limpar tabelas com DELETE (para não quebrar constraints)
            var commands = new[]
            {
                "DELETE FROM ultimate_stats_kills",
                "DELETE FROM ultimate_stats_maps",
                "DELETE FROM ultimate_stats_sessions",
                "DELETE FROM ultimate_stats_weapons",
                "DELETE FROM ultimate_stats"
            };

            foreach (var cmdText in commands)
            {
                var command = new MySqlCommand(cmdText, connection);
                await command.ExecuteNonQueryAsync();
            }

            return Ok(new { success = true, message = "Banco de dados limpo com sucesso" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erro ao limpar banco de dados");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    [HttpGet("stats")]
    public async Task<IActionResult> GetStats()
    {
        try
        {
            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();

            var command = new MySqlCommand(
                @"SELECT 
                    COUNT(*) as total_players,
                    SUM(kills) as total_kills,
                    SUM(deaths) as total_deaths,
                    SUM(hs_kills) as total_hs,
                    ROUND(AVG(kills / GREATEST(deaths, 1)), 2) as avg_kdr,
                    ROUND(AVG(skill), 0) as avg_skill
                 FROM ultimate_stats", connection);

            using var reader = await command.ExecuteReaderAsync(CommandBehavior.SingleRow);
            if (await reader.ReadAsync())
            {
                var stats = new
                {
                    total_players = reader.GetInt64("total_players"),
                    total_kills = reader.GetInt64("total_kills"),
                    total_deaths = reader.GetInt64("total_deaths"),
                    total_hs = reader.GetInt64("total_hs"),
                    avg_kdr = reader.GetDecimal("avg_kdr"),
                    avg_skill = reader.GetDecimal("avg_skill")
                };

                return Ok(new { success = true, data = stats });
            }

            return Ok(new { success = true, data = new { total_players = 0, total_kills = 0, total_deaths = 0, total_hs = 0, avg_kdr = 0, avg_skill = 0 } });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erro ao buscar estatísticas");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    [HttpGet("weapons")]
    public async Task<IActionResult> GetWeapons()
    {
        try
        {
            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();

            var command = new MySqlCommand(
                @"SELECT 
                    weapon,
                    SUM(kills) as total_kills,
                    SUM(deaths) as total_deaths,
                    SUM(hs) as total_hs,
                    COUNT(DISTINCT player_id) as total_players
                 FROM ultimate_stats_weapons
                 GROUP BY weapon
                 ORDER BY total_kills DESC", connection);

            using var reader = await command.ExecuteReaderAsync();
            var weapons = new List<object>();

            while (await reader.ReadAsync())
            {
                weapons.Add(new
                {
                    weapon = reader.GetString("weapon"),
                    total_kills = reader.GetInt64("total_kills"),
                    total_deaths = reader.GetInt64("total_deaths"),
                    total_hs = reader.GetInt64("total_hs"),
                    total_players = reader.GetInt64("total_players")
                });
            }

            return Ok(new { success = true, data = weapons });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erro ao buscar estatísticas de armas");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }
}