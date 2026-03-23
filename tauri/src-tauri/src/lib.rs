use std::io::{BufRead, BufReader, Write};
use std::process::{Command, Stdio};

const STYLE_SYSTEM_PROMPT: &str = r#"You are an aesthetic style designer for audio plugin UIs.
You receive a style system JSON and modify it based on the user's request.

The style system has these sections:
- geometry: cornerRadius, borderWidth, shadowBlur, plus per-widget settings (knob, button, toggle, slider, textInput)
- effects: bloom (enabled, size, intensity), shadows (enabled, blur, offsetX, offsetY, alpha), blur
- gradients: buttonGradient, knobGradient, accentGradient (each has enabled, type, angle, stops)
- typography: headingSize, bodySize, labelSize, smallSize, fontWeight, letterSpacing, lineHeight

When the user describes an aesthetic (e.g., "80s Macintosh", "neon cyberpunk", "warm analog"),
translate that into specific property changes across ALL relevant sections.

Return ONLY a valid JSON object with the changed properties as a diff.
Do NOT return the full style system — only properties that changed.
Structure: {"geometry":{"button":{"cornerRadius":0}},"effects":{"shadows":{"enabled":false}}}

If a component is selected, only change properties for that component type."#;

#[tauri::command]
async fn chat_send(
    prompt: String,
    style_json: String,
    selected_component: Option<String>,
    model: Option<String>,
) -> Result<String, String> {
    let model_id = model.unwrap_or_else(|| "claude-opus-4-6".to_string());

    // Build the full prompt with system context
    let mut full_prompt = format!("{}\n\nCurrent style system:\n{}\n\n", STYLE_SYSTEM_PROMPT, style_json);
    if let Some(ref component) = selected_component {
        full_prompt.push_str(&format!("[Selected component: {}]\n", component));
    }
    full_prompt.push_str(&format!("User request: {}\n\nReturn ONLY a JSON diff:", prompt));

    // Spawn claude CLI
    let output = Command::new("claude")
        .args([
            "--print",
            "--output-format", "json",
            "--model", &model_id,
            "-p", &full_prompt,
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| format!("Failed to run claude CLI: {}. Is it installed?", e))?;

    if output.status.success() {
        let response = String::from_utf8_lossy(&output.stdout).to_string();
        // Parse the JSON output format: {"type":"result","result":"..."}
        if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&response) {
            if let Some(result) = parsed.get("result").and_then(|r| r.as_str()) {
                // Extract JSON diff from the result text
                if let Some(json_start) = result.find('{') {
                    if let Some(json_end) = result.rfind('}') {
                        let json_str = &result[json_start..=json_end];
                        if let Ok(diff) = serde_json::from_str::<serde_json::Value>(json_str) {
                            return Ok(serde_json::json!({
                                "message": result[..json_start].trim().to_string(),
                                "diff": diff
                            }).to_string());
                        }
                    }
                }
                // No JSON found — return the text as message
                return Ok(serde_json::json!({
                    "message": result,
                    "diff": {}
                }).to_string());
            }
        }
        // Raw response
        Ok(serde_json::json!({
            "message": response.trim(),
            "diff": {}
        }).to_string())
    } else {
        let err = String::from_utf8_lossy(&output.stderr).to_string();
        Err(format!("Claude CLI error: {}", err.trim()))
    }
}

#[tauri::command]
async fn chat_health() -> Result<String, String> {
    let output = Command::new("claude")
        .arg("--version")
        .output()
        .map_err(|e| format!("Claude CLI not found: {}", e))?;

    if output.status.success() {
        let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(serde_json::json!({
            "status": "ok",
            "version": version,
        }).to_string())
    } else {
        Err("Claude CLI not authenticated or not working".to_string())
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri::Builder::default()
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            Ok(())
        });

    // Enable WebDriver in debug builds
    #[cfg(debug_assertions)]
    let builder = builder.plugin(tauri_plugin_webdriver::init());

    builder
        .invoke_handler(tauri::generate_handler![chat_send, chat_health])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
