use crate::*;
pub use base64::prelude::*;
use aes_gcm::{
    Aes256Gcm, Key, Nonce,
    aead::{Aead, KeyInit, Payload},
};
use rand::{TryRng, rngs::SysRng};

const NONCE_SIZE: u8 = 12; // GCM typically uses 12 bytes for nonce
const TAG_SIZE: usize = 16; // GCM authentication tag is 16 bytes

lazy_static! {
    static ref DEFAULT_INDICES: Vec<u8> = (0..NONCE_SIZE).map(|i| i).collect();
    static ref INDICES: Arc<SyncMutex<Vec<u8>>> =
        Arc::new(SyncMutex::new(DEFAULT_INDICES.to_owned()));
    static ref SESSION_ID: Arc<SyncMutex<Option<String>>> =
        Arc::new(SyncMutex::new(None));
}

pub fn set_indices(mut new_indices: Vec<u8>) -> Result<(), String> {
    new_indices.dedup();
    new_indices.sort();

    if new_indices.len() != NONCE_SIZE as usize {
        return Err(format!(
            "[set_indices] Expected {}, got {} indices",
            NONCE_SIZE,
            new_indices.len()
        ));
    }

    *lock!(INDICES) = new_indices;

    Ok(())
}

pub fn reset_indices() {
    *lock!(INDICES) = DEFAULT_INDICES.to_owned();
}

pub fn set_session_id(session_id: &str) {
    *lock!(SESSION_ID) = Some(session_id.to_owned());
}

pub fn reset_session_id() {
    *lock!(SESSION_ID) = None;
}

/// The AES-256 key is the first 32 bytes of the server key, so both directions build their cipher the same way.
fn cipher_from(server_key: &[u8]) -> Result<Aes256Gcm, String> {
    let Some(encryption_key) = server_key.get(0..32) else {
        return Err(format!(
            "Server key must contain at least 32 bytes, got {}",
            server_key.len()
        ));
    };

    let key = <&Key<Aes256Gcm>>::try_from(encryption_key)
        .map_err(|e| format!("Server key is not a usable AES-256 key: {e}"))?;

    Ok(Aes256Gcm::new(key))
}

pub fn encrypt_request(data: &[u8], server_key: &[u8]) -> Result<Vec<u8>, String> {
    let cipher = cipher_from(server_key)?;

    // Drawn straight from the OS rather than a userspace generator, and a failure to read it is returned rather than
    // swallowed: GCM's security rests on never reusing a nonce under the same key, so encrypting with whatever bytes
    // happened to be in the buffer would be worse than not sending the message at all.
    let mut nonce_bytes = [0u8; NONCE_SIZE as usize];
    SysRng
        .try_fill_bytes(&mut nonce_bytes)
        .map_err(|e| format!("Failed to read a nonce from the system random source: {e}"))?;

    let nonce = Nonce::from(nonce_bytes);

    // Build payload with AAD (session_id if set)
    let session_id_guard = lock!(SESSION_ID);
    let aad = session_id_guard
        .as_deref()
        .map(str::as_bytes)
        .unwrap_or(b"");
    let payload = Payload { msg: data, aad };

    // Encrypt; output is ciphertext || 16-byte GCM tag
    let mut packet = cipher
        .encrypt(&nonce, payload)
        .map_err(|e| format!("Encryption failed: {e}"))?;

    // Insert nonce at specified positions
    let nonce_indices = lock!(INDICES).clone();
    for (loop_index, nonce_index) in nonce_indices.iter().enumerate() {
        packet.insert(*nonce_index as usize, nonce_bytes[loop_index]);
    }

    Ok(packet)
}

pub fn decrypt_request(
    encoded_bytes: Vec<u8>,
    server_key: &[u8],
) -> Result<Vec<u8>, String> {
    let cipher = cipher_from(server_key)?;
    let nonce_indices = lock!(INDICES).clone();

    let mut nonce: Vec<u8> = vec![];
    let mut packet: Vec<u8> = vec![];

    // Extract nonce and ciphertext
    for (index, byte) in encoded_bytes.iter().enumerate() {
        if nonce_indices
            .get(nonce.len())
            .is_some_and(|i| *i as usize == index)
        {
            nonce.push(*byte);
            continue;
        }

        packet.push(*byte);
    }

    if nonce.len() < NONCE_SIZE as usize {
        return Err(format!("Nonce must contain at least {NONCE_SIZE} bytes"));
    }

    if packet.len() < TAG_SIZE {
        return Err("Encrypted data too short".into());
    }

    // Build payload with AAD; packet = ciphertext || tag (aes-gcm validates tag)
    let session_id_guard = lock!(SESSION_ID);
    let aad = session_id_guard
        .as_deref()
        .map(str::as_bytes)
        .unwrap_or(b"");
    let payload = Payload { msg: &packet, aad };

    let nonce_bytes: [u8; NONCE_SIZE as usize] = nonce[..NONCE_SIZE as usize]
        .try_into()
        .map_err(|_| format!("Nonce is not the {NONCE_SIZE} bytes GCM expects"))?;

    let nonce = Nonce::from(nonce_bytes);
    let plaintext = cipher
        .decrypt(&nonce, payload)
        .map_err(|e| format!("Decryption failed: {e}"))?;

    Ok(plaintext)
}

#[cfg(test)]
mod tests {
    use uuid::Uuid;

    use super::*;

    #[test]
    fn test_encrypt_and_decrypt_message() {
        let mut message = Message::new().set_type(Type::Init);

        let server_init = Init {
            server_name: "server_name".into(),
            price_per_object: "10".into(),
            territory_lifetime: "7".into(),
            territory_data: "[]".into(),
            server_start_time: chrono::Utc::now(),
            extension_version: "2.0.0".into(),
            vg_enabled: false,
            vg_max_sizes: String::new(),
        };

        let expected = server_init.clone();
        message.data = server_init.to_data();

        let server_key = format!(
            "{}-{}-{}-{}",
            Uuid::new_v4(),
            Uuid::new_v4(),
            Uuid::new_v4(),
            Uuid::new_v4()
        );
        let server_key = server_key.as_bytes();

        let _ = set_indices(vec![
            3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33,
        ]);

        let _ = set_session_id("12345");

        let bytes = message.as_bytes().unwrap();
        let encrypted_bytes = encrypt_request(&bytes, server_key).unwrap();

        let decrypted_message =
            decrypt_request(encrypted_bytes, server_key).unwrap();

        let message = Message::from_bytes(&decrypted_message).unwrap();

        assert_eq!(message.message_type, Type::Init);

        let data = message.data;

        assert_eq!(
            data.get("server_name").unwrap().as_str().unwrap(),
            expected.server_name
        );

        assert_eq!(
            data.get("price_per_object").unwrap().as_str().unwrap(),
            expected.price_per_object
        );

        assert_eq!(
            data.get("territory_lifetime").unwrap().as_str().unwrap(),
            expected.territory_lifetime
        );

        assert_eq!(
            data.get("territory_data").unwrap().as_str().unwrap(),
            expected.territory_data
        );
    }
}
