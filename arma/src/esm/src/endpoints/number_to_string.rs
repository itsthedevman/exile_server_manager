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

    match input_number.parse::<usize>() {
        Ok(n) => Ok(n.to_formatted_string(&locale)),
        Err(e) => Err(format!(
            "[#number_to_string] Failed to parse unsigned integer from {input_number}. Reason: {e}"
        )),
    }
}
