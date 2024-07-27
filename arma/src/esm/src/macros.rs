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

#[macro_export]
macro_rules! include_sql {
    ($name:expr) => {{
        let path = concat!("./@esm/sql/queries/", $name, ".sql");

        match fs::read_to_string(path) {
            Ok(c) => c,
            Err(e) => {
                error!(
                    "Failed to load file at @esm/sql/queries/{}.sql. Reason: {e}",
                    $name
                );

                String::new()
            }
        }
    }};
}

// Generates the Statements struct from the SQL files
#[macro_export]
macro_rules! statements {
    ($( $names:ident ),* $(,)?) => {
        #[derive(Clone, Debug, Default)]
        struct Statements {
            $($names: String),*
        }

        impl Statements {
            pub fn new() -> Self {
                Statements {
                    $($names: include_sql!(stringify!($names))),*
                }
            }

            pub fn validate(&self) -> ESMResult {
                $(
                    if self.$names.is_empty() {
                        return Self::format_error(stringify!($names));
                    }
                )*

                Ok(())
            }

            fn format_error(name: &str) -> ESMResult {
                Err(format!(
                    "Failed to load {name}.sql. Please ensure @esm/sql/queries/{name}.sql exists and contains valid SQL"
                )
                .into())
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
