#[macro_export]
macro_rules! await_lock {
    ($mutex:expr) => {{
        use rand::prelude::*;

        let mut rng = rand::thread_rng();
        let delay: u64 = rng.gen_range(1..250_000);

        let mut container: Option<tokio::sync::MutexGuard<_>> = None;
        while container.is_none() {
            std::thread::sleep(std::time::Duration::from_nanos(delay));
            if let Ok(guard) = $mutex.try_lock() {
                container = Some(guard);
            }
        }

        container.unwrap()
    }};
}

#[macro_export]
macro_rules! lock {
    ($mutex:expr) => {{
        use rand::prelude::*;

        let mut rng = rand::thread_rng();
        let delay: u64 = rng.gen_range(1..250_000);

        let mut container: Option<std::sync::MutexGuard<_>> = None;
        while container.is_none() {
            std::thread::sleep(std::time::Duration::from_nanos(delay));
            if let Ok(guard) = $mutex.try_lock() {
                container = Some(guard);
            }
        }

        container.unwrap()
    }};
}

#[macro_export]
macro_rules! random_bs_go {
    () => {{
        uuid::Uuid::new_v4().as_simple().to_string()[0..=7].to_string()
    }};
}

// #[macro_export]
// macro_rules! hashmap {
//     { $($key:expr => $value:expr),* } => {{
//         use std::collections::HashMap;

//         let mut hash: HashMap<String, String> = HashMap::new();

//         $(
//             hash.insert($key.to_string(), $value.to_string());
//         )*

//         hash
//     }};
// }

#[cfg(test)]
mod tests {
    use tokio::sync::Mutex;

    #[test]
    fn it_locks() {
        let lock = Mutex::new(true);
        let reader = await_lock!(lock);
        assert!(*reader);
    }
}
