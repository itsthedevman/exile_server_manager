use super::*;

use parking_lot::RwLock;

#[derive(Clone)]
pub struct Hasher {
    builder: Arc<RwLock<harsh::Harsh>>,
}

impl Hasher {
    const ALPHABET: &'static str = "abcdefghijklmnopqrstuvwxyz";
    const LENGTH: usize = 5;

    pub fn new() -> Self {
        Hasher {
            builder: Arc::new(RwLock::new(Self::builder(&random_bs_go!()))),
        }
    }

    fn builder(salt: &str) -> harsh::Harsh {
        harsh::Harsh::builder()
            .length(Hasher::LENGTH)
            .alphabet(Hasher::ALPHABET)
            .salt(salt)
            .build()
            .unwrap()
    }

    pub fn encode(&self, id: &str) -> String {
        let Ok(id) = id.parse() else {
            return String::new();
        };

        self.builder.read().encode(&[id])
    }

    pub fn decode(&self, input: &str) -> Option<u64> {
        let Ok(numbers) = self.builder.read().decode(input) else {
            return None;
        };

        numbers.get(0).copied()
    }

    pub fn set_salt(&self, salt: &str) {
        *self.builder.write() = Self::builder(salt)
    }
}
