-- CS Ranking - UltimateStats Schema
-- Cria tabelas para ranking, players, armas, mapas e sessões

USE ultimate_stats;

-- Tabela principal de jogadores
CREATE TABLE IF NOT EXISTS ultimate_stats (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(32) NOT NULL,
  steamid VARCHAR(35) NOT NULL UNIQUE,
  ip VARCHAR(16) NOT NULL,
  admin TINYINT(1) NOT NULL DEFAULT 0,
  kills INT NOT NULL DEFAULT 0,
  deaths INT NOT NULL DEFAULT 0,
  hs_kills INT NOT NULL DEFAULT 0,
  assists INT NOT NULL DEFAULT 0,
  revenges INT NOT NULL DEFAULT 0,
  team_kills INT NOT NULL DEFAULT 0,
  shots INT NOT NULL DEFAULT 0,
  hits INT NOT NULL DEFAULT 0,
  damage INT NOT NULL DEFAULT 0,
  rounds INT NOT NULL DEFAULT 0,
  rounds_ct INT NOT NULL DEFAULT 0,
  rounds_t INT NOT NULL DEFAULT 0,
  wins_ct INT NOT NULL DEFAULT 0,
  wins_t INT NOT NULL DEFAULT 0,
  connects INT NOT NULL DEFAULT 0,
  time INT NOT NULL DEFAULT 0,
  gold INT NOT NULL DEFAULT 0,
  silver INT NOT NULL DEFAULT 0,
  bronze INT NOT NULL DEFAULT 0,
  medals INT NOT NULL DEFAULT 0,
  best_kills INT NOT NULL DEFAULT 0,
  best_deaths INT NOT NULL DEFAULT 0,
  best_hs INT NOT NULL DEFAULT 0,
  best_stats INT NOT NULL DEFAULT 0,
  defusions INT NOT NULL DEFAULT 0,
  defused INT NOT NULL DEFAULT 0,
  planted INT NOT NULL DEFAULT 0,
  exploded INT NOT NULL DEFAULT 0,
  skill INT NOT NULL DEFAULT 0,
  h_0 INT NOT NULL DEFAULT 0,  -- Head
  h_1 INT NOT NULL DEFAULT 0,  -- Chest
  h_2 INT NOT NULL DEFAULT 0,  -- Stomach
  h_3 INT NOT NULL DEFAULT 0,  -- Left Arm
  h_4 INT NOT NULL DEFAULT 0,  -- Right Arm
  h_5 INT NOT NULL DEFAULT 0,  -- Left Leg
  h_6 INT NOT NULL DEFAULT 0,  -- Right Leg
  h_7 INT NOT NULL DEFAULT 0,  -- Generic
  first_visit INT NOT NULL DEFAULT 0,
  last_visit INT NOT NULL DEFAULT 0,
  KEY idx_steamid (steamid),
  KEY idx_name (name),
  KEY idx_kills (kills),
  KEY idx_skill (skill),
  KEY idx_admin (admin),
  KEY idx_last_visit (last_visit)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Estatísticas gerais dos jogadores';

-- Tabela de estatísticas de armas por jogador
CREATE TABLE IF NOT EXISTS ultimate_stats_weapons (
  id INT AUTO_INCREMENT PRIMARY KEY,
  player_id INT NOT NULL,
  weapon VARCHAR(20) NOT NULL,
  kills INT NOT NULL DEFAULT 0,
  deaths INT NOT NULL DEFAULT 0,
  hs_kills INT NOT NULL DEFAULT 0,
  team_kills INT NOT NULL DEFAULT 0,
  shots INT NOT NULL DEFAULT 0,
  hits INT NOT NULL DEFAULT 0,
  damage INT NOT NULL DEFAULT 0,
  h_0 INT NOT NULL DEFAULT 0,
  h_1 INT NOT NULL DEFAULT 0,
  h_2 INT NOT NULL DEFAULT 0,
  h_3 INT NOT NULL DEFAULT 0,
  h_4 INT NOT NULL DEFAULT 0,
  h_5 INT NOT NULL DEFAULT 0,
  h_6 INT NOT NULL DEFAULT 0,
  h_7 INT NOT NULL DEFAULT 0,
  UNIQUE KEY uk_player_weapon (player_id, weapon),
  FOREIGN KEY (player_id) REFERENCES ultimate_stats(id) ON DELETE CASCADE,
  KEY idx_player_id (player_id),
  KEY idx_weapon (weapon),
  KEY idx_kills (kills)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Estatísticas de armas por jogador';

-- Tabela de mapas
CREATE TABLE IF NOT EXISTS ultimate_stats_maps (
  id INT AUTO_INCREMENT PRIMARY KEY,
  mapname VARCHAR(32) NOT NULL UNIQUE,
  plays INT NOT NULL DEFAULT 0,
  rounds_ct INT NOT NULL DEFAULT 0,
  rounds_t INT NOT NULL DEFAULT 0,
  wins_ct INT NOT NULL DEFAULT 0,
  wins_t INT NOT NULL DEFAULT 0,
  ct_score INT NOT NULL DEFAULT 0,
  t_score INT NOT NULL DEFAULT 0,
  KEY idx_mapname (mapname),
  KEY idx_plays (plays)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Estatísticas por mapa';

-- Tabela de sessões (logs de conexão)
CREATE TABLE IF NOT EXISTS ultimate_stats_sessions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  player_id INT NOT NULL,
  connect_time INT NOT NULL,
  disconnect_time INT NOT NULL,
  duration INT NOT NULL,
  ip VARCHAR(16) NOT NULL,
  hostname VARCHAR(32) NOT NULL,
  FOREIGN KEY (player_id) REFERENCES ultimate_stats(id) ON DELETE CASCADE,
  KEY idx_player_id (player_id),
  KEY idx_connect_time (connect_time),
  KEY idx_disconnect_time (disconnect_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Histórico de sessões dos jogadores';

-- Tabela de logs de kills
CREATE TABLE IF NOT EXISTS ultimate_stats_kills (
  id INT AUTO_INCREMENT PRIMARY KEY,
  killer_id INT NOT NULL,
  victim_id INT NOT NULL,
  weapon VARCHAR(20) NOT NULL,
  is_hs TINYINT(1) NOT NULL DEFAULT 0,
  kill_time INT NOT NULL,
  mapname VARCHAR(32) NOT NULL,
  team_killer TINYINT(1) NOT NULL DEFAULT 0,
  FOREIGN KEY (killer_id) REFERENCES ultimate_stats(id) ON DELETE CASCADE,
  FOREIGN KEY (victim_id) REFERENCES ultimate_stats(id) ON DELETE CASCADE,
  KEY idx_killer_id (killer_id),
  KEY idx_victim_id (victim_id),
  KEY idx_weapon (weapon),
  KEY idx_kill_time (kill_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Log de kills detalhado';

-- Views úteis
CREATE OR REPLACE VIEW v_top_players AS
SELECT
    id,
    name,
    steamid,
    kills,
    deaths,
    hs_kills,
    IFNULL(kills / NULLIF(deaths, 0), 0) AS kdr,
    skill,
    gold,
    silver,
    bronze,
    medals,
    rounds,
    connects,
    time
FROM ultimate_stats
WHERE kills >= 50
ORDER BY skill DESC;

CREATE OR REPLACE VIEW v_weapon_stats AS
SELECT
    w.weapon,
    SUM(w.kills) AS total_kills,
    SUM(w.hs_kills) AS total_hs,
    COUNT(DISTINCT w.player_id) AS players,
    IFNULL(SUM(w.kills) / NULLIF(SUM(w.shots), 0) * 100, 0) AS accuracy
FROM ultimate_stats_weapons w
GROUP BY w.weapon
ORDER BY total_kills DESC;

CREATE OR REPLACE VIEW v_map_stats AS
SELECT
    mapname,
    plays,
    rounds_ct + rounds_t AS total_rounds,
    wins_ct + wins_t AS total_wins
FROM ultimate_stats_maps
ORDER BY plays DESC;

-- Stored procedures úteis

DELIMITER //

CREATE PROCEDURE sp_update_player_skill(
    IN p_player_id INT
)
BEGIN
    DECLARE v_kills INT;
    DECLARE v_deaths INT;
    DECLARE v_hs_kills INT;
    DECLARE v_time INT;
    DECLARE v_new_skill INT;

    SELECT kills, deaths, hs_kills, `time`
    INTO v_kills, v_deaths, v_hs_kills, v_time
    FROM ultimate_stats
    WHERE id = p_player_id;

    -- Cálculo de skill baseado em kills, deaths, HS e tempo de jogo
    SET v_new_skill = IFNULL(
        (v_kills * 10) +
        (v_hs_kills * 15) -
        (v_deaths * 5) +
        (v_time / 3600 * 2),
        0
    );

    UPDATE ultimate_stats
    SET skill = v_new_skill
    WHERE id = p_player_id;
END //

CREATE PROCEDURE sp_get_player_stats(
    IN p_player_id INT
)
BEGIN
    SELECT
        u.*,
        IFNULL(u.kills / NULLIF(u.deaths, 0), 0) AS kdr,
        IFNULL(u.kills / NULLIF(u.connects, 0), 0) AS avg_kills_per_connect,
        (SELECT SUM(w.kills) FROM ultimate_stats_weapons w WHERE w.player_id = u.id) AS total_weapon_kills
    FROM ultimate_stats u
    WHERE u.id = p_player_id;
END //

CREATE PROCEDURE sp_clean_old_sessions(
    IN p_days INT
)
BEGIN
    DELETE FROM ultimate_stats_sessions
    WHERE disconnect_time < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL p_days DAY));
END //

DELIMITER ;

-- Indices adicionais para performance
CREATE INDEX idx_ultimate_stats_composite ON ultimate_stats(skill, kills, rounds);
CREATE INDEX idx_sessions_composite ON ultimate_stats_sessions(player_id, connect_time);
CREATE INDEX idx_kills_composite ON ultimate_stats_kills(killer_id, victim_id, kill_time);

-- Tabelas de configuração

CREATE TABLE IF NOT EXISTS ultimate_stats_settings (
  setting_key VARCHAR(50) PRIMARY KEY,
  setting_value TEXT NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Configurações do sistema';

INSERT INTO ultimate_stats_settings (setting_key, setting_value) VALUES
('min_rounds_for_ranking', '5'),
('min_kills_for_ranking', '10'),
('skill_update_interval', '60'),
('show_admins_in_ranking', '1')
ON DUPLICATE KEY UPDATE setting_value = setting_value;

-- Trigger para atualizar skill automaticamente após mudanças
DELIMITER //

CREATE TRIGGER tr_after_stats_update
AFTER UPDATE ON ultimate_stats
FOR EACH ROW
BEGIN
    IF NEW.kills != OLD.kills OR NEW.deaths != OLD.deaths OR NEW.hs_kills != OLD.hs_kills THEN
        CALL sp_update_player_skill(NEW.id);
    END IF;
END //

DELIMITER ;

COMMIT;