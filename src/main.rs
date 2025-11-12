use axum::{response::Json, routing::get, Router};
use serde_json::json;
use std::env;
use tracing::info;

#[tokio::main]
async fn main() {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    let port = env::var("ZEUS_HTTP_PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse::<u16>()
        .expect("Invalid port");

    let bind_addr = env::var("ZEUS_BIND_ADDR").unwrap_or_else(|_| "0.0.0.0".to_string());

    // Build router
    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(health));

    let addr = format!("{}:{}", bind_addr, port);
    info!("🚀 Zeus Orchestrator listening on {}", addr);

    // Start server
    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .expect("Failed to bind");

    axum::serve(listener, app)
        .await
        .expect("Server failed");
}

async fn root() -> Json<serde_json::Value> {
    Json(json!({
        "service": "Zeus Orchestrator",
        "version": "0.1.0",
        "status": "running"
    }))
}

async fn health() -> Json<serde_json::Value> {
    Json(json!({
        "status": "healthy",
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}
