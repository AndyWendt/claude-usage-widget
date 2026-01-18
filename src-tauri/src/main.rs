// Prevents additional console window on Windows in release
#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::process::Command;
use std::sync::Mutex;
use tauri::{Manager, State};
use tauri_plugin_autostart::MacosLauncher;

// ============================================================================
// Data Types
// ============================================================================

/// Response from Anthropic OAuth usage API
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UsageApiResponse {
    pub five_hour: Option<UsageWindow>,
    pub seven_day: Option<UsageWindow>,
    pub seven_day_sonnet: Option<UsageWindow>,
    pub seven_day_opus: Option<UsageWindow>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UsageWindow {
    pub utilization: f64,
    pub resets_at: String,
}

/// Local stats cache structure from ~/.claude/stats-cache.json
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StatsCache {
    pub daily_activity: Option<Vec<DailyActivity>>,
    pub daily_model_tokens: Option<Vec<DailyTokens>>,
    pub last_computed_date: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyActivity {
    pub date: String,
    pub message_count: i64,
    pub session_count: i64,
    pub tool_call_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyTokens {
    pub date: String,
    pub tokens_by_model: HashMap<String, i64>,
}

/// Combined widget data sent to frontend
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WidgetData {
    pub five_hour: Option<UsageMetric>,
    pub seven_day: Option<UsageMetric>,
    pub seven_day_sonnet: Option<UsageMetric>,
    pub seven_day_opus: Option<UsageMetric>,
    pub token_stats: TokenStats,
    pub last_updated: String,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UsageMetric {
    pub percent: f64,
    pub resets_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TokenStats {
    pub today_tokens: i64,
    pub week_tokens: i64,
    pub today_messages: i64,
    pub week_messages: i64,
}

/// App settings
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    pub always_on_top: bool,
    pub refresh_interval: u64,
    pub position: Option<Position>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Position {
    pub x: f64,
    pub y: f64,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            always_on_top: true,
            refresh_interval: 60,
            position: None,
        }
    }
}

// ============================================================================
// App State
// ============================================================================

pub struct AppState {
    pub settings: Mutex<Settings>,
    pub cached_token: Mutex<Option<String>>,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            settings: Mutex::new(Settings::default()),
            cached_token: Mutex::new(None),
        }
    }
}

// ============================================================================
// Keychain Access
// ============================================================================

/// Extract OAuth token from macOS Keychain
fn get_oauth_token_from_keychain() -> Result<String, String> {
    let output = Command::new("security")
        .args(["find-generic-password", "-s", "Claude Code-credentials", "-w"])
        .output()
        .map_err(|e| format!("Failed to execute security command: {}", e))?;

    if !output.status.success() {
        return Err("No credentials found in Keychain. Please sign in to Claude Code first.".to_string());
    }

    let json_str = String::from_utf8(output.stdout)
        .map_err(|e| format!("Invalid UTF-8 in keychain data: {}", e))?
        .trim()
        .to_string();

    // Parse the JSON to extract claudeAiOauth.accessToken
    let creds: serde_json::Value = serde_json::from_str(&json_str)
        .map_err(|e| format!("Failed to parse credentials JSON: {}", e))?;

    creds["claudeAiOauth"]["accessToken"]
        .as_str()
        .map(|s| s.to_string())
        .ok_or_else(|| "No OAuth token found in credentials".to_string())
}

// ============================================================================
// API Calls
// ============================================================================

/// Fetch usage data from Anthropic OAuth API
async fn fetch_usage_from_api(token: &str) -> Result<UsageApiResponse, String> {
    let client = reqwest::Client::new();

    let response = client
        .get("https://api.anthropic.com/api/oauth/usage")
        .header("Authorization", format!("Bearer {}", token))
        .header("anthropic-beta", "oauth-2025-04-20")
        .send()
        .await
        .map_err(|e| format!("API request failed: {}", e))?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        return Err(format!("API error {}: {}", status, body));
    }

    response
        .json::<UsageApiResponse>()
        .await
        .map_err(|e| format!("Failed to parse API response: {}", e))
}

// ============================================================================
// Local Stats
// ============================================================================

/// Read and parse local stats cache
fn read_stats_cache() -> Result<StatsCache, String> {
    let home = dirs::home_dir().ok_or("Could not find home directory")?;
    let stats_path = home.join(".claude").join("stats-cache.json");

    if !stats_path.exists() {
        return Ok(StatsCache {
            daily_activity: None,
            daily_model_tokens: None,
            last_computed_date: None,
        });
    }

    let content = std::fs::read_to_string(&stats_path)
        .map_err(|e| format!("Failed to read stats cache: {}", e))?;

    serde_json::from_str(&content)
        .map_err(|e| format!("Failed to parse stats cache: {}", e))
}

/// Calculate activity stats from cache
fn calculate_token_stats(cache: &StatsCache) -> TokenStats {
    let today = chrono::Local::now().format("%Y-%m-%d").to_string();
    let week_ago = (chrono::Local::now() - chrono::Duration::days(7))
        .format("%Y-%m-%d")
        .to_string();

    let mut today_tokens: i64 = 0;
    let mut week_tokens: i64 = 0;
    let mut today_messages: i64 = 0;
    let mut week_messages: i64 = 0;

    // Get token counts from dailyModelTokens
    if let Some(daily_tokens) = &cache.daily_model_tokens {
        for day in daily_tokens {
            let day_total: i64 = day.tokens_by_model.values().sum();

            if day.date == today {
                today_tokens = day_total;
            }

            if day.date >= week_ago {
                week_tokens += day_total;
            }
        }
    }

    // Get message counts from dailyActivity
    if let Some(daily_activity) = &cache.daily_activity {
        for day in daily_activity {
            if day.date == today {
                today_messages = day.message_count;
            }

            if day.date >= week_ago {
                week_messages += day.message_count;
            }
        }
    }

    TokenStats {
        today_tokens,
        week_tokens,
        today_messages,
        week_messages,
    }
}

// ============================================================================
// Tauri Commands
// ============================================================================

#[tauri::command]
async fn get_usage_data(state: State<'_, AppState>) -> Result<WidgetData, String> {
    // Get or refresh OAuth token
    let token = {
        let mut cached = state.cached_token.lock().unwrap();
        if cached.is_none() {
            *cached = Some(get_oauth_token_from_keychain()?);
        }
        cached.clone().unwrap()
    };

    // Fetch API data
    let api_result = fetch_usage_from_api(&token).await;

    // Read local stats
    let stats_cache = read_stats_cache().unwrap_or(StatsCache {
        daily_activity: None,
        daily_model_tokens: None,
        last_computed_date: None,
    });
    let token_stats = calculate_token_stats(&stats_cache);

    let now = chrono::Utc::now().to_rfc3339();

    match api_result {
        Ok(api_data) => Ok(WidgetData {
            five_hour: api_data.five_hour.map(|w| UsageMetric {
                percent: w.utilization,
                resets_at: w.resets_at,
            }),
            seven_day: api_data.seven_day.map(|w| UsageMetric {
                percent: w.utilization,
                resets_at: w.resets_at,
            }),
            seven_day_sonnet: api_data.seven_day_sonnet.map(|w| UsageMetric {
                percent: w.utilization,
                resets_at: w.resets_at,
            }),
            seven_day_opus: api_data.seven_day_opus.map(|w| UsageMetric {
                percent: w.utilization,
                resets_at: w.resets_at,
            }),
            token_stats,
            last_updated: now,
            error: None,
        }),
        Err(e) => {
            // Clear cached token if auth failed
            if e.contains("401") || e.contains("403") {
                let mut cached = state.cached_token.lock().unwrap();
                *cached = None;
            }
            Ok(WidgetData {
                five_hour: None,
                seven_day: None,
                seven_day_sonnet: None,
                seven_day_opus: None,
                token_stats,
                last_updated: now,
                error: Some(e),
            })
        }
    }
}

#[tauri::command]
fn get_settings(state: State<'_, AppState>) -> Settings {
    state.settings.lock().unwrap().clone()
}

#[tauri::command]
fn save_settings(state: State<'_, AppState>, settings: Settings) -> Result<(), String> {
    // Save to state
    *state.settings.lock().unwrap() = settings.clone();

    // Persist to file
    let home = dirs::home_dir().ok_or("Could not find home directory")?;
    let settings_dir = home.join(".claude-widget");
    std::fs::create_dir_all(&settings_dir)
        .map_err(|e| format!("Failed to create settings directory: {}", e))?;

    let settings_path = settings_dir.join("settings.json");
    let content = serde_json::to_string_pretty(&settings)
        .map_err(|e| format!("Failed to serialize settings: {}", e))?;

    std::fs::write(&settings_path, content)
        .map_err(|e| format!("Failed to write settings: {}", e))?;

    Ok(())
}

#[tauri::command]
fn save_window_position(state: State<'_, AppState>, x: f64, y: f64) -> Result<(), String> {
    let mut settings = state.settings.lock().unwrap();
    settings.position = Some(Position { x, y });

    // Persist
    let home = dirs::home_dir().ok_or("Could not find home directory")?;
    let settings_path = home.join(".claude-widget").join("settings.json");

    if let Ok(content) = serde_json::to_string_pretty(&*settings) {
        let _ = std::fs::write(&settings_path, content);
    }

    Ok(())
}

#[tauri::command]
async fn set_always_on_top(window: tauri::Window, value: bool) -> Result<(), String> {
    window
        .set_always_on_top(value)
        .map_err(|e| format!("Failed to set always on top: {}", e))
}

// ============================================================================
// App Setup
// ============================================================================

fn load_settings() -> Settings {
    let home = match dirs::home_dir() {
        Some(h) => h,
        None => return Settings::default(),
    };

    let settings_path = home.join(".claude-widget").join("settings.json");

    if let Ok(content) = std::fs::read_to_string(&settings_path) {
        if let Ok(settings) = serde_json::from_str(&content) {
            return settings;
        }
    }

    Settings::default()
}

fn main() {
    let settings = load_settings();

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_autostart::init(
            MacosLauncher::LaunchAgent,
            Some(vec!["--autostarted"]),
        ))
        .manage(AppState {
            settings: Mutex::new(settings),
            cached_token: Mutex::new(None),
        })
        .setup(|app| {
            // Enable autostart on first launch
            use tauri_plugin_autostart::ManagerExt;
            let autostart_manager = app.autolaunch();
            if !autostart_manager.is_enabled().unwrap_or(false) {
                let _ = autostart_manager.enable();
            }

            // Restore window position if saved
            if let Some(window) = app.get_webview_window("main") {
                let state: State<AppState> = app.state();
                let settings = state.settings.lock().unwrap();

                if let Some(pos) = &settings.position {
                    let _ = window.set_position(tauri::Position::Physical(
                        tauri::PhysicalPosition::new(pos.x as i32, pos.y as i32),
                    ));
                }

                let _ = window.set_always_on_top(settings.always_on_top);
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_usage_data,
            get_settings,
            save_settings,
            save_window_position,
            set_always_on_top,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
