use crate::options::OPTIONS;
use crate::utils::CLIENT;
use anyhow::{Result, anyhow};
use reqwest::RequestBuilder;
use sha2::{Digest, Sha256};
use std::time::{SystemTime, UNIX_EPOCH};

const BASE_URL: &str = "https://api.dandanplay.net";

/// base64(sha256(AppId + Timestamp + Path + AppSecret))
fn calculate_signature(app_id: &str, timestamp: i64, path: &str, app_secret: &str) -> String {
    let data = format!("{}{}{}{}", app_id, timestamp, path, app_secret);
    let hash = Sha256::digest(data.as_bytes());
    use base64::prelude::*;
    BASE64_STANDARD.encode(hash)
}

fn get_timestamp() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_secs() as i64
}

fn build_auth_headers(path: &str) -> Result<[(String, String); 3]> {
    let options = *OPTIONS;
    let app_id = options.app_id;
    let app_secret = options.app_secret;

    if app_id.is_empty() || app_secret.is_empty() {
        return Err(anyhow!("app_id and app_secret must be configured"));
    }

    let timestamp = get_timestamp();
    let signature = calculate_signature(app_id, timestamp, path, app_secret);

    Ok([
        ("X-AppId".to_string(), app_id.to_string()),
        ("X-Signature".to_string(), signature),
        ("X-Timestamp".to_string(), timestamp.to_string()),
    ])
}

pub struct DandanplayService;

impl DandanplayService {
    pub fn get(path: &str) -> Result<RequestBuilder> {
        let headers = build_auth_headers(path)?;
        let url = format!("{}{}", BASE_URL, path);
        let mut request = CLIENT.get(&url);

        for (key, value) in headers {
            request = request.header(&key, value);
        }

        Ok(request)
    }

    pub fn post(path: &str) -> Result<RequestBuilder> {
        let headers = build_auth_headers(path)?;
        let url = format!("{}{}", BASE_URL, path);
        let mut request = CLIENT.post(&url);

        for (key, value) in headers {
            request = request.header(&key, value);
        }

        Ok(request)
    }

    pub fn is_auth_configured() -> bool {
        let options = *OPTIONS;
        !options.app_id.is_empty() && !options.app_secret.is_empty()
    }

    pub fn ensure_auth_configured() -> Result<()> {
        if !Self::is_auth_configured() {
            return Err(anyhow!(
                "Authentication not configured. Please set app_id and app_secret in config file."
            ));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_signature() {
        let app_id = "test_app_id";
        let timestamp = 1234567890i64;
        let path = "/api/v2/comment/123450001";
        let app_secret = "test_app_secret";

        let signature = calculate_signature(app_id, timestamp, path, app_secret);
        assert!(!signature.is_empty());
        assert!(
            signature
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '+' || c == '/' || c == '=')
        );
    }
}
