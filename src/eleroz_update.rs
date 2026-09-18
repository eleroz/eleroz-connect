// ЭЛЕРОЗ: обновление со своего сайта.
// RustDesk спрашивает версию у api.rustdesk.com и своим клиентам проверку выключает,
// поэтому канал обновлений тут свой: описание версии лежит на eleroz.ru, файл — там же.
// Номер сборки подставляет CI в src/eleroz_build.rs, у собранной вручную копии он нулевой.
use hbb_common::{
    bail,
    config::Config,
    log,
    sha2::{Digest, Sha256},
    ResultType,
};
use std::{path::Path, sync::Mutex, time::Duration};

/// Где лежит описание последней версии. Можно подменить настройкой eleroz-update-url.
pub const MANIFEST_URL: &str = "https://eleroz.ru/upload/eleroz-connect/update.json";
const TIMEOUT: Duration = Duration::from_secs(20);

lazy_static::lazy_static! {
    static ref NEW_VERSION: Mutex<String> = Default::default();
    static ref NEW_SHA256: Mutex<String> = Default::default();
}

#[inline]
pub fn build_number() -> u32 {
    crate::eleroz_build::BUILD
}

#[inline]
pub fn new_version() -> String {
    NEW_VERSION.lock().unwrap().clone()
}

#[inline]
fn manifest_url() -> String {
    let custom = Config::get_option("eleroz-update-url");
    if custom.is_empty() {
        MANIFEST_URL.to_owned()
    } else {
        custom
    }
}

#[inline]
fn field(manifest: &serde_json::Value, key: &str) -> String {
    manifest[key].as_str().unwrap_or_default().to_owned()
}

/// Установленная через MSI копия обновляется пакетом, остальные — обычным файлом.
fn file_and_hash(manifest: &serde_json::Value) -> (String, String) {
    #[cfg(windows)]
    if crate::platform::is_msi_installed().unwrap_or(false) {
        let msi = field(manifest, "msi_url");
        if !msi.is_empty() {
            return (msi, field(manifest, "msi_sha256"));
        }
    }
    (field(manifest, "url"), field(manifest, "sha256"))
}

fn forget_new_version() {
    NEW_VERSION.lock().unwrap().clear();
    NEW_SHA256.lock().unwrap().clear();
    *crate::common::SOFTWARE_UPDATE_URL.lock().unwrap() = "".to_string();
}

pub fn check() -> ResultType<()> {
    let url = manifest_url();
    let client = crate::hbbs_http::create_http_client_with_url(&url);
    let response = client.get(&url).timeout(TIMEOUT).send()?;
    if !response.status().is_success() {
        bail!("Update manifest {} returned {}", url, response.status());
    }
    let manifest: serde_json::Value = serde_json::from_str(&response.text()?)?;
    let build = manifest["build"].as_u64().unwrap_or_default() as u32;
    let (file_url, sha256) = file_and_hash(&manifest);
    if build <= build_number() || file_url.is_empty() {
        forget_new_version();
        return Ok(());
    }
    let version = field(&manifest, "version");
    *NEW_VERSION.lock().unwrap() = if version.is_empty() {
        format!("сборка {}", build)
    } else {
        format!("{}, сборка {}", version, build)
    };
    *NEW_SHA256.lock().unwrap() = sha256.to_lowercase();
    log::info!("New version available: build {}, {}", build, file_url);
    #[cfg(feature = "flutter")]
    {
        let mut event = std::collections::HashMap::new();
        event.insert("name", "check_software_update_finish");
        event.insert("url", &file_url);
        if let Ok(data) = serde_json::to_string(&event) {
            let _ = crate::flutter::push_global_event(crate::flutter::APP_TYPE_MAIN, data);
        }
    }
    *crate::common::SOFTWARE_UPDATE_URL.lock().unwrap() = file_url;
    Ok(())
}

/// Скачанный файл сверяется с контрольной суммой из описания версии.
pub fn verify_file(path: &Path) -> ResultType<()> {
    let expected = NEW_SHA256.lock().unwrap().clone();
    if expected.is_empty() {
        return Ok(());
    }
    let mut hasher = Sha256::new();
    hasher.update(&std::fs::read(path)?);
    let actual = format!("{:x}", hasher.finalize());
    if actual != expected {
        bail!("Checksum mismatch: expected {}, got {}", expected, actual);
    }
    Ok(())
}
