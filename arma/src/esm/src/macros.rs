#[macro_export]
macro_rules! await_lock {
    ($mutex:expr) => {{
        let delay: u64 = rand::random_range(1..250_000);

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
        let delay: u64 = rand::random_range(1..250_000);

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

// Compiled in rather than read off the server, so a query always matches the extension that runs it. A missing
// file is a build error.
#[macro_export]
macro_rules! include_sql {
    ($name:expr) => {
        include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/src/database/sql/", $name, ".sql")).to_string()
    };
}

// Generates the Queries struct from the SQL files
#[macro_export]
macro_rules! load_sql {
    ($( $names:ident ),* $(,)?) => {
        #[derive(Clone, Debug, Default)]
        pub struct Queries {
            $(pub $names: String),*
        }

        impl Queries {
            pub fn new() -> Self {
                Queries {
                    $($names: include_sql!(stringify!($names))),*
                }
            }
        }

    };
}

#[macro_export]
macro_rules! import_and_export {
    ($name:ident) => {
        pub mod $name;
        pub use $name::*;
    };
}

#[macro_export]
macro_rules! import {
    ($name:ident) => {
        pub mod $name;
        use $name::*;
    };
}

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
