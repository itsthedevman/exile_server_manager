pub struct ArmaResponse {
    values: Vec<String>
}

impl ArmaResponse {
    pub fn new(values: Vec<String>) -> ArmaResponse {
        ArmaResponse { values }
    }
}
