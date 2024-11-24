use actix_web::{post, web, App, HttpResponse, HttpServer, Responder};
use actix_cors::Cors; // Import CORS
use dotenv::dotenv;
use lazy_static::lazy_static;
use log::{error, info};
use prometheus::{Counter, Encoder, TextEncoder};
use serde::{Deserialize, Serialize};
use std::env;
use thiserror::Error;
use tokio_postgres::{Client, Error as PgError, NoTls};
use tracing::instrument;
use tracing_actix_web::TracingLogger;

#[derive(Debug, Error)]
enum AppError {
    #[error("Database connection error")]
    DbConnectionError(#[from] PgError),
}

#[derive(Debug, Deserialize)]
struct RegisterRequest {
    name: String,
    email: String,
}

#[derive(Debug, Deserialize)]
struct LoginRequest {
    email: String,
}

#[derive(Serialize)]
struct ApiResponse {
    message: String,
    name: Option<String>,
    email: Option<String>,
    status: String,
}

// Metrics
lazy_static! {
    static ref REGISTER_REQUESTS: Counter = prometheus::register_counter!(
        "register_requests_total",
        "Total number of registration requests"
    )
    .unwrap();
    static ref LOGIN_REQUESTS: Counter = prometheus::register_counter!(
        "login_requests_total",
        "Total number of login requests"
    )
    .unwrap();
}

#[instrument]
async fn connect_to_db() -> Result<Client, AppError> {
    dotenv().ok();
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    let (client, connection) = tokio_postgres::connect(&database_url, NoTls)
        .await
        .map_err(AppError::DbConnectionError)?;

    tokio::spawn(async move {
        if let Err(e) = connection.await {
            error!("Database connection error: {}", e);
        }
    });

    info!("Database connection established successfully");
    Ok(client)
}

#[post("/register")]
#[instrument]
async fn register_user(user: web::Json<RegisterRequest>) -> impl Responder {
    REGISTER_REQUESTS.inc();

    let client = match connect_to_db().await {
        Ok(client) => client,
        Err(e) => {
            error!("Error connecting to database: {}", e);
            return HttpResponse::InternalServerError().json(ApiResponse {
                message: "Failed to connect to database".to_string(),
                name: None,
                email: Some(user.email.clone()),
                status: "error".to_string(),
            });
        }
    };

    // Check if the user already exists
    let check_query = "SELECT name, email FROM users WHERE email = $1";
    if let Ok(Some(row)) = client.query_opt(check_query, &[&user.email]).await {
        let name: String = row.get(0);
        let email: String = row.get(1);
        info!("User already exists: {}, {}", name, email);
        return HttpResponse::BadRequest().json(ApiResponse {
            message: "User already exists".to_string(),
            name: Some(name),
            email: Some(email),
            status: "error".to_string(),
        });
    }

    // Insert the new user into the database
    let insert_query = "INSERT INTO users (name, email) VALUES ($1, $2)";
    match client
        .execute(insert_query, &[&user.name, &user.email])
        .await
    {
        Ok(_) => {
            info!("User registered successfully: {}", user.email);
            HttpResponse::Ok().json(ApiResponse {
                message: "Registration successful".to_string(),
                name: Some(user.name.clone()),
                email: Some(user.email.clone()),
                status: "success".to_string(),
            })
        }
        Err(e) => {
            error!("Error inserting user: {}: {}", user.email, e);
            HttpResponse::InternalServerError().json(ApiResponse {
                message: "Failed to register user".to_string(),
                name: None,
                email: Some(user.email.clone()),
                status: "error".to_string(),
            })
        }
    }
}

#[post("/login")]
#[instrument]
async fn login_user(user: web::Json<LoginRequest>) -> impl Responder {
    LOGIN_REQUESTS.inc();

    let client = match connect_to_db().await {
        Ok(client) => client,
        Err(e) => {
            error!("Error connecting to database: {}", e);
            return HttpResponse::InternalServerError().json(ApiResponse {
                message: "Failed to connect to database".to_string(),
                name: None,
                email: Some(user.email.clone()),
                status: "error".to_string(),
            });
        }
    };

    // Check if the user exists
    let query = "SELECT name, email FROM users WHERE email = $1";
    match client.query_opt(query, &[&user.email]).await {
        Ok(Some(row)) => {
            let name: String = row.get(0);
            let email: String = row.get(1);
            info!("User found: {}", email);
            HttpResponse::Ok().json(ApiResponse {
                message: "Login successful".to_string(),
                name: Some(name),
                email: Some(email),
                status: "success".to_string(),
            })
        }
        Ok(None) => {
            info!("User not found: {}", user.email);
            HttpResponse::BadRequest().json(ApiResponse {
                message: "User does not exist".to_string(),
                name: None,
                email: Some(user.email.clone()),
                status: "error".to_string(),
            })
        }
        Err(e) => {
            error!("Error querying user: {}", e);
            HttpResponse::InternalServerError().json(ApiResponse {
                message: "Failed to query user".to_string(),
                name: None,
                email: Some(user.email.clone()),
                status: "error".to_string(),
            })
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init();

    HttpServer::new(|| {
        App::new()
            .wrap(TracingLogger::default())
            .wrap(
                Cors::default()
                    .allowed_origin("http://localhost:8080") // Frontend URL
                    .allowed_methods(vec!["GET", "POST", "OPTIONS"])
                    .allowed_headers(vec!["Content-Type", "Authorization"])
                    .max_age(3600),
            )
            .service(register_user)
            .service(login_user)
            .route("/metrics", web::get().to(metrics_handler))
    })
    .bind(("0.0.0.0", 8080))? // Bind to 0.0.0.0 so it's accessible to all local devices
    .run()
    .await
}

// Metrics endpoint handler
async fn metrics_handler() -> impl Responder {
    let encoder = TextEncoder::new();
    let mut buffer = Vec::new();
    let metrics = prometheus::gather();
    encoder.encode(&metrics, &mut buffer).unwrap();
    let response = String::from_utf8(buffer).unwrap();

    HttpResponse::Ok().content_type("text/plain").body(response)
}
