#[macro_export]
macro_rules! read_lock {
    ($reader:expr) => {{
        let mut container: Option<tokio::sync::RwLockReadGuard<_>> = None;
        while container.is_none() {
            if let Ok(r) = $reader.try_read() {
                container = Some(r);
            }
        }
        container.unwrap()
    }};
}

#[macro_export]
macro_rules! write_lock {
    ($writer:expr) => {{
        let mut container: Option<tokio::sync::RwLockWriteGuard<_>> = None;
        while container.is_none() {
            if let Ok(w) = $writer.try_write() {
                container = Some(w);
            };
        }
        container.unwrap()
    }};
}

#[cfg(test)]
mod tests {
    use tokio::sync::RwLock;

    #[test]
    fn it_locks_reader() {
        let lock = RwLock::new(true);
        let reader = read_lock!(lock);
        assert!(*reader);
    }

    #[test]
    fn it_locks_writer() {
        let lock = RwLock::new(true);
        let mut writer = write_lock!(lock);
        *writer = false;
        assert!(!*writer);
    }
}
