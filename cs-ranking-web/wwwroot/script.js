// State
let allPlayers = [];
let filteredPlayers = [];
let currentPage = 1;
let playersPerPage = 20;
let autoRefreshInterval = null;
let currentFilter = '1h';

// DOM Elements
const loading = document.getElementById('loading');
const error = document.getElementById('error');
const errorMessage = document.getElementById('errorMessage');
const rankingBody = document.getElementById('rankingBody');
const searchInput = document.getElementById('searchInput');
const timeFilter = document.getElementById('timeFilter');
const autoRefreshCheckbox = document.getElementById('autoRefresh');
const prevPageBtn = document.getElementById('prevPage');
const nextPageBtn = document.getElementById('nextPage');
const paginationInfo = document.getElementById('paginationInfo');
const totalPlayers = document.getElementById('totalPlayers');
const totalKills = document.getElementById('totalKills');
const avgKD = document.getElementById('avgKD');
const updateTime = document.getElementById('updateTime');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    loadPlayers();
    setupEventListeners();
    startAutoRefresh();
});

// Event Listeners
function setupEventListeners() {
    searchInput.addEventListener('input', debounce(handleSearch, 300));
    timeFilter.addEventListener('change', handleTimeFilter);
    autoRefreshCheckbox.addEventListener('change', handleAutoRefreshToggle);
    prevPageBtn.addEventListener('click', () => changePage(-1));
    nextPageBtn.addEventListener('click', () => changePage(1));
}

// Load Players from API
async function loadPlayers() {
    try {
        loading.classList.remove('hidden');
        error.classList.add('hidden');

        const response = await fetch('/api/players?timeFilter=' + currentFilter);
        
        if (!response.ok) {
            throw new Error(`Erro ao carregar dados: ${response.status}`);
        }

        const data = await response.json();
        
        if (data.success && Array.isArray(data.data)) {
            allPlayers = data.data;
            applyFilters();
            updateStats();
            updateLastUpdateTime();
        } else {
            throw new Error('Formato de resposta inválido');
        }

    } catch (err) {
        console.error('Erro ao carregar ranking:', err);
        errorMessage.textContent = err.message;
        error.classList.remove('hidden');
    } finally {
        loading.classList.add('hidden');
    }
}

// Apply Filters
function applyFilters() {
    const searchTerm = searchInput.value.toLowerCase();
    
    filteredPlayers = allPlayers.filter(player => {
        if (!player.name) return false;
        return player.name.toLowerCase().includes(searchTerm);
    });

    // Sort by kills descending
    filteredPlayers.sort((a, b) => (b.kills || 0) - (a.kills || 0));
    
    currentPage = 1;
    renderTable();
    updatePagination();
}

// Handle Search
function handleSearch() {
    applyFilters();
}

// Handle Time Filter Change
function handleTimeFilter() {
    currentFilter = timeFilter.value;
    loadPlayers();
}

// Handle Auto Refresh Toggle
function handleAutoRefreshToggle() {
    if (autoRefreshCheckbox.checked) {
        startAutoRefresh();
    } else {
        stopAutoRefresh();
    }
}

// Start Auto Refresh
function startAutoRefresh() {
    if (autoRefreshInterval) clearInterval(autoRefreshInterval);
    autoRefreshInterval = setInterval(loadPlayers, 30000); // 30 seconds
}

// Stop Auto Refresh
function stopAutoRefresh() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
    }
}

// Render Table
function renderTable() {
    const startIndex = (currentPage - 1) * playersPerPage;
    const endIndex = startIndex + playersPerPage;
    const pagePlayers = filteredPlayers.slice(startIndex, endIndex);

    if (pagePlayers.length === 0) {
        rankingBody.innerHTML = `
            <tr>
                <td colspan="9" class="no-data">
                    <div class="no-data-content">
                        <span class="no-data-icon">🎮</span>
                        <p>Nenhum jogador encontrado</p>
                    </div>
                </td>
            </tr>
        `;
        return;
    }

    rankingBody.innerHTML = pagePlayers.map((player, index) => {
        const globalRank = startIndex + index + 1;
        const kd = player.deaths > 0 ? (player.kills / player.deaths).toFixed(2) : (player.kills || 0).toFixed(2);
        const hsPercent = player.kills > 0 ? ((player.hs_kills / player.kills) * 100).toFixed(1) : '0.0';
        const timeDisplay = formatTime(player.time);

        return `
            <tr class="player-row" data-player-id="${player.id}">
                <td class="rank-column">
                    <div class="rank-badge ${getRankClass(globalRank)}">${globalRank}</div>
                </td>
                <td class="player-column">
                    <div class="player-info">
                        <div class="player-name">${escapeHtml(player.name)}</div>
                        <div class="player-steamid">${player.steamid || 'Unknown'}</div>
                    </div>
                </td>
                <td class="skill-column">
                    <span class="stat-value skill-value">${formatNumber(player.skill)}</span>
                </td>
                <td class="kills-column">
                    <span class="stat-value kills-value">${formatNumber(player.kills)}</span>
                </td>
                <td class="deaths-column">
                    <span class="stat-value deaths-value">${formatNumber(player.deaths)}</span>
                </td>
                <td class="kd-column">
                    <span class="stat-value kd-value ${getKDClass(parseFloat(kd))}">${kd}</span>
                </td>
                <td class="hs-column">
                    <span class="stat-value hs-value">${formatNumber(player.hs_kills)}</span>
                </td>
                <td class="hs-percent-column">
                    <span class="stat-value hs-percent-value">${hsPercent}%</span>
                </td>
                <td class="time-column">
                    <span class="stat-value time-value">${timeDisplay}</span>
                </td>
            </tr>
        `;
    }).join('');
}

// Update Pagination
function updatePagination() {
    const totalPages = Math.ceil(filteredPlayers.length / playersPerPage);
    
    prevPageBtn.disabled = currentPage === 1;
    nextPageBtn.disabled = currentPage === totalPages || totalPages === 0;
    
    paginationInfo.textContent = totalPages > 0 
        ? `Página ${currentPage} de ${totalPages}`
        : 'Página 1 de 1';
}

// Change Page
function changePage(direction) {
    const totalPages = Math.ceil(filteredPlayers.length / playersPerPage);
    const newPage = currentPage + direction;
    
    if (newPage >= 1 && newPage <= totalPages) {
        currentPage = newPage;
        renderTable();
        updatePagination();
    }
}

// Update Stats
function updateStats() {
    totalPlayers.textContent = formatNumber(filteredPlayers.length);
    
    const totalKillsValue = filteredPlayers.reduce((sum, p) => sum + (p.kills || 0), 0);
    totalKills.textContent = formatNumber(totalKillsValue);
    
    const avgKDValue = filteredPlayers.length > 0
        ? (filteredPlayers.reduce((sum, p) => {
            const kd = p.deaths > 0 ? p.kills / p.deaths : p.kills || 0;
            return sum + kd;
        }, 0) / filteredPlayers.length).toFixed(2)
        : '0.00';
    
    avgKD.textContent = avgKDValue;
}

// Update Last Update Time
function updateLastUpdateTime() {
    const now = new Date();
    updateTime.textContent = now.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}

// Format Number
function formatNumber(num) {
    if (num === undefined || num === null) return '0';
    return num.toLocaleString('pt-BR');
}

// Format Time
function formatTime(seconds) {
    if (!seconds || seconds < 60) return '< 1 min';
    
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (hours > 0) {
        return `${hours}h ${minutes}min`;
    }
    return `${minutes}min`;
}

// Get Rank Class
function getRankClass(rank) {
    if (rank === 1) return 'rank-1';
    if (rank === 2) return 'rank-2';
    if (rank === 3) return 'rank-3';
    return 'rank-default';
}

// Get KD Class
function getKDClass(kd) {
    if (kd >= 2.0) return 'kd-excellent';
    if (kd >= 1.5) return 'kd-good';
    if (kd >= 1.0) return 'kd-average';
    return 'kd-poor';
}

// Escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Debounce Function
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Keyboard Shortcuts
document.addEventListener('keydown', (e) => {
    // Focus search with Ctrl+F or /
    if ((e.ctrlKey && e.key === 'f') || e.key === '/') {
        e.preventDefault();
        searchInput.focus();
    }
    
    // Page navigation with arrow keys
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
        const nextPageBtn = document.getElementById('nextPage');
        if (!nextPageBtn.disabled) {
            changePage(1);
        }
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
        const prevPageBtn = document.getElementById('prevPage');
        if (!prevPageBtn.disabled) {
            changePage(-1);
        }
    }
});