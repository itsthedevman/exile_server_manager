#[macro_export]
macro_rules! read_lock {
    ($reader:expr) => {{
        let mut container: Option<parking_lot::RwLockReadGuard<_>> = None;
        while container.is_none() {
            container = $reader.try_read_for(std::time::Duration::from_micros(200));
        }
        container.unwrap()
    }};
}

#[macro_export]
macro_rules! write_lock {
    ($writer:expr) => {{
        let mut container: Option<parking_lot::RwLockWriteGuard<_>> = None;
        while container.is_none() {
            container = $writer.try_write_for(std::time::Duration::from_micros(200));
        }
        container.unwrap()
    }};
}

#[cfg(test)]
mod tests {
    use parking_lot::RwLock;

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
