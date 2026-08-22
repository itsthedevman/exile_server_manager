use super::*;

pub fn number_to_string(input_number: String) -> Result<String, String> {
    // Allow different types of separations
    let locale = match Locale::from_name(&CONFIG.number_locale) {
        Ok(l) => l,
        Err(e) => {
            return Err(format!(
                "[#number_to_string] Failed to local configured locale \"{locale}\". Reason: {e}",
                locale = CONFIG.number_locale
            ))
        }
    };

    // Parsed as u64 rather than usize, and the width is the whole point. usize is 32 bits on the i686 build, so
    // anything past 4,294,967,295 fails to parse there and succeeds on x86_64: pop tabs and respect totals reach
    // that range routinely, and the same call returns a number on one server and an error on the other.
    match input_number.parse::<u64>() {
        Ok(n) => Ok(n.to_formatted_string(&locale)),
        Err(e) => Err(format!(
            "[#number_to_string] Failed to parse unsigned integer from {input_number}. Reason: {e}"
        )),
    }
}
