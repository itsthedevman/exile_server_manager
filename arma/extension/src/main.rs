mod models;

use std::collections::HashMap;
use models::arma_request::ArmaRequest;
use models::

fn main() {
    let mut parameters: HashMap<String, String> = HashMap::new();
    parameters.insert(String::from("uid"), String::from("1234567890"));

    let request = ArmaRequest::new("test".to_string(), parameters);
    println!("{:?}", request);
    println!("{}", serde_json::to_string(&request).unwrap());
}
