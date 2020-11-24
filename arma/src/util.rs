pub fn convert_a3_array(array_string: String) -> Result<serde_json::Value, serde_json::Error> {
  let package = str::replace(&array_string, "\"\"", "\"");

  let package = serde_json::from_str(&package)?;

  Ok(package)
}
