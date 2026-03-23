use std::process::Command;

#[tauri::command]
async fn chat_send(
    prompt: String,
    style_json: String,
    selected_component: Option<String>,
    image_base64: Option<String>,
) -> Result<String, String> {
    // Build the request payload for the Node.js sidecar
    let payload = serde_json::json!({
        "prompt": prompt,
        "styleJSON": style_json,
        "selectedComponent": selected_component,
        "image": image_base64,
    });

    // Try to call the Node.js sidecar agent
    let sidecar_path = std::env::current_dir()
        .unwrap_or_default()
        .join("sidecar")
        .join("agent.mjs");

    if sidecar_path.exists() {
        // Spawn Node.js process with the payload as stdin
        let output = Command::new("node")
            .arg(&sidecar_path)
            .arg("--payload")
            .arg(payload.to_string())
            .output()
            .map_err(|e| format!("Failed to spawn agent: {}", e))?;

        if output.status.success() {
            let response = String::from_utf8_lossy(&output.stdout).to_string();
            Ok(response)
        } else {
            let err = String::from_utf8_lossy(&output.stderr).to_string();
            Err(format!("Agent error: {}", err))
        }
    } else {
        // Fallback: return a mock response for development
        Ok(serde_json::json!({
            "message": "Agent sidecar not found. Install with: cd tauri/sidecar && pnpm install",
            "diff": {}
        }).to_string())
    }
}

#[tauri::command]
async fn chat_health() -> Result<String, String> {
    // Check if Node.js and the sidecar are available
    let node_check = Command::new("node")
        .arg("--version")
        .output();

    match node_check {
        Ok(output) if output.status.success() => {
            let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
            Ok(serde_json::json!({
                "status": "ok",
                "nodeVersion": version,
            }).to_string())
        }
        _ => Err("Node.js not found".to_string()),
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![chat_send, chat_health])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
