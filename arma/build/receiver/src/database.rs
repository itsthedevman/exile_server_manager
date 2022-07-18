use crate::{BuildError, BuildResult};
use mysql::{prelude::Queryable, Opts, Pool};

pub struct Database {
    pool: Pool,
}

impl Database {
    pub fn new(connection_uri: String) -> Result<Self, BuildError> {
        let opts = match Opts::from_url(&connection_uri) {
            Ok(o) => o,
            Err(e) => return Err(e.to_string().into()),
        };

        let pool = match Pool::new(opts) {
            Ok(p) => p,
            Err(e) => return Err(e.to_string().into()),
        };

        Ok(Database { pool })
    }

    pub fn exec_query(&self, query: &str) -> BuildResult {
        let mut connection = match self.pool.get_conn() {
            Ok(c) => c,
            Err(e) => return Err(e.to_string().into()),
        };

        match connection.query_drop(query) {
            Ok(_) => Ok(()),
            Err(e) => Err(e.to_string().into()),
        }
    }
}
