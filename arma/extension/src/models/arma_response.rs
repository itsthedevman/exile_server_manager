pub struct ArmaResponse {
    // Indicates to the 
    success: bool,
    values: Vec
}

impl ArmaResponse {
    pub fn new(success: bool, values: Vec) -> ArmaResponse {
        ArmaResponse { success, values }
    }
}
