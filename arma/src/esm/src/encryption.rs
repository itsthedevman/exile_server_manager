use crate::*;
use base64::prelude::*;
use openssl::{
    rand::rand_bytes,
    symm::{decrypt, encrypt, Cipher},
};

const NONCE_SIZE: u8 = 16;
lazy_static! {
    static ref DEFAULT_INDICES: Vec<u8> = (0..NONCE_SIZE).map(|i| i).collect();
    static ref INDICES: Arc<SyncMutex<Vec<u8>>> =
        Arc::new(SyncMutex::new(DEFAULT_INDICES.to_owned()));
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

pub fn encrypt_message(message: &Message, server_key: &[u8]) -> Result<Vec<u8>, String> {
    if server_key.len() < 32 {
        return Err("Server key must contain at least 32 bytes".into());
    }

    let message_bytes: Vec<u8> = match serde_json::to_vec(&message) {
        Ok(bytes) => bytes,
        Err(e) => return Err(e.to_string()),
    };

    // encryption_key has to be exactly 32 bytes
    let encryption_key = &server_key[0..32];

    let mut nonce_key = [0; NONCE_SIZE as usize];
    if let Err(e) = rand_bytes(&mut nonce_key) {
        error!("[encrypt_message] Failed to generate nonce. {e:?}");
    }

    let cipher = Cipher::aes_256_cbc();

    // and encrypt it
    let mut packet: Vec<u8> = match encrypt(
        cipher,
        encryption_key,
        Some(&nonce_key),
        message_bytes.as_ref(),
    ) {
        Ok(bytes) => bytes,
        Err(e) => return Err(e.to_string()),
    };

    // Now store the nonce in the packet at the specified locations
    let nonce_indices = lock!(INDICES).clone();
    for (loop_index, nonce_index) in nonce_indices.iter().enumerate() {
        packet.insert(*nonce_index as usize, nonce_key[loop_index])
    }

    Ok(BASE64_STANDARD.encode(packet).into_bytes())
}

pub fn decrypt_message<'a>(bytes: &[u8], server_key: &[u8]) -> Result<Vec<u8>, String> {
    if server_key.len() < 32 {
        return Err("Server key must contain at least 32 bytes".into());
    }

    let Ok(encoded_message) = String::from_utf8(bytes.to_vec()) else {
        return Err("Failed to convert to string".into());
    };

    let encoded_message: Vec<u8> = match BASE64_STANDARD.decode(&encoded_message) {
        Ok(p) => p,
        Err(e) => return Err(format!("[decrypt_message] {e:?}")),
    };

    let nonce_indices = lock!(INDICES).clone();

    let mut nonce: Vec<u8> = vec![];
    let mut packet: Vec<u8> = vec![];

    // I was going to remove the bytes at the indexes from the message bytes but..
    // According to the Vec::remove docs, it can have slow performance due. I suspect that's not really an
    // issue for this, but I did come up with another way to do it.
    // To avoid re-indexing the bytes array 12 times (plus a copy since I'd need it to be mut), I'll go through
    // each byte and rebuild the packet without the nonce in it. This _should_ be good on perf
    for (index, byte) in encoded_message.iter().enumerate() {
        if nonce_indices
            .get(nonce.len())
            .is_some_and(|i| *i as usize == index)
        {
            nonce.push(*byte);
            continue;
        }

        packet.push(*byte);
    }

    info!("[decrypt_message] Packet: {packet:?}");

    // Build the cipher
    let server_key = &server_key[0..=31]; // server_key has to be exactly 32 bytes
    info!(
        "[decrypt_message] Server key: {server_key:?} | nonce: {nonce:?} | size: {}",
        nonce.len()
    );

    let cipher = Cipher::aes_256_cbc();

    // Decrypt! This also ensures the message has been encrypted using this server's key.
    match decrypt(cipher, server_key, Some(&nonce), packet.as_ref()) {
        Ok(message) => Ok(message),
        Err(e) => Err(format!("Failed to decrypt. {e:?}")),
    }
}

#[cfg(test)]
mod tests {
    use uuid::Uuid;

    use super::*;

    #[test]
    fn test_encrypt_and_decrypt_message() {
        let mut message = Message::new();

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

        message.data = Data::Init(server_init);

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

        let encrypted_bytes = encrypt_message(&message, server_key);
        assert!(encrypted_bytes.is_ok());

        let decrypted_message = decrypt_message(&encrypted_bytes.unwrap(), server_key);
        assert!(decrypted_message.is_ok());

        let decrypted_message = decrypted_message.unwrap();
        let message = Message::from_bytes(&decrypted_message).unwrap();

        assert_eq!(message.message_type, Type::Event);

        match message.data {
            Data::Init(data) => {
                assert_eq!(data.server_name, expected.server_name);
                assert_eq!(data.price_per_object, expected.price_per_object);
                assert_eq!(data.territory_lifetime, expected.territory_lifetime);
                assert_eq!(data.territory_data, expected.territory_data);
            }
            _ => panic!("Invalid message data"),
        }
    }
}
