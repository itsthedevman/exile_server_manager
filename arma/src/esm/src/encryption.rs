use crate::*;
pub use base64::prelude::*;
use openssl::{
    rand::rand_bytes,
    symm::{Cipher, Crypter, Mode},
};

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

pub fn encrypt_request(data: &[u8], server_key: &[u8]) -> Result<Vec<u8>, String> {
    if server_key.len() < 32 {
        return Err("Server key must contain at least 32 bytes".into());
    }

    let encryption_key = &server_key[0..32];

    // Generate nonce
    let mut nonce = vec![0; NONCE_SIZE as usize];
    if let Err(e) = rand_bytes(&mut nonce) {
        error!("[encrypt_message] Failed to generate nonce. {e:?}");
        return Err(e.to_string());
    }

    // Setup GCM encryption
    let cipher = Cipher::aes_256_gcm();
    let mut encrypter =
        Crypter::new(cipher, Mode::Encrypt, encryption_key, Some(&nonce))
            .map_err(|e| format!("Failed to create cipher: {e}"))?;

    // Add session ID as authenticated data if provided
    if let Some(session_id) = &*lock!(SESSION_ID) {
        encrypter
            .aad_update(session_id.as_bytes())
            .map_err(|e| format!("Failed to update aad: {e}"))?;
    }

    // Allocate buffer for encrypted data
    let mut packet = vec![0; data.len() + cipher.block_size()];
    let mut count = encrypter
        .update(data, &mut packet)
        .map_err(|e| format!("Failed to update cipher: {e}"))?;

    count += encrypter
        .finalize(&mut packet[count..])
        .map_err(|e| format!("Failed to finalize cipher: {e}"))?;

    packet.truncate(count);

    // Get authentication tag
    let mut tag = vec![0u8; TAG_SIZE];
    encrypter
        .get_tag(&mut tag)
        .map_err(|e| format!("Failed to get tag: {e}"))?;

    // Append tag to encrypted data
    packet.extend_from_slice(&tag);

    // Insert nonce at specified positions
    let nonce_indices = lock!(INDICES).clone();
    for (loop_index, nonce_index) in nonce_indices.iter().enumerate() {
        packet.insert(*nonce_index as usize, nonce[loop_index])
    }

    Ok(packet)
}

pub fn decrypt_request(
    encoded_bytes: Vec<u8>,
    server_key: &[u8],
) -> Result<Vec<u8>, String> {
    if server_key.len() < 32 {
        return Err("Server key must contain at least 32 bytes".into());
    }

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

    // Split off authentication tag
    if packet.len() < TAG_SIZE {
        return Err("Encrypted data too short".into());
    }

    let tag = packet.split_off(packet.len() - TAG_SIZE);

    // Setup GCM decryption
    let cipher = Cipher::aes_256_gcm();

    let mut decrypter =
        Crypter::new(cipher, Mode::Decrypt, &server_key[0..32], Some(&nonce))
            .map_err(|e| format!("Failed to create cipher: {e}"))?;

    // Add session ID as authenticated data if provided
    if let Some(session_id) = &*lock!(SESSION_ID) {
        decrypter
            .aad_update(session_id.as_bytes())
            .map_err(|e| format!("Failed to perform aad update: {e}"))?;
    }

    // Set expected tag
    decrypter
        .set_tag(&tag)
        .map_err(|e| format!("Failed to set tag: {e}"))?;

    // Decrypt
    let mut plaintext = vec![0; packet.len() + cipher.block_size()];
    let mut count = decrypter
        .update(&packet, &mut plaintext)
        .map_err(|e| format!("Failed to update cipher: {e}"))?;

    count += decrypter
        .finalize(&mut plaintext[count..])
        .map_err(|e| format!("Failed to finalize cipher: {e}"))?;

    plaintext.truncate(count);

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
