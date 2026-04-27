use super::*;
use parser::Parser;

pub fn add_xm8_notification(
    notification_type: String,
    recipient_uids: String,
    content: String,
) -> Result<(), String> {
    let timer = std::time::Instant::now();

    trace!(
        "[add_xm8_notification] notification_type: {:?} - recipient_uids: {:?} - content: {:?}",
        notification_type,
        recipient_uids,
        content
    );

    let content: HashMap<String, JSONValue> = match Parser::from_arma(&content) {
        Ok(d) => d,
        Err(e) => return Err(e.into()),
    };

    let content: HashMap<String, String> = content
        .into_iter()
        .map(|(key, value)| {
            let value = match value {
                JSONValue::String(e) => e,
                o => o.to_string(),
            };

            (key, value)
        })
        .collect();

    let result = TOKIO_RUNTIME.block_on(async {
        DATABASE
            .add_xm8_notifications(notification_type, recipient_uids, content)
            .await
            .map_err(|e| e.error_content)
    });

    debug!("[add_xm8_notification] ⏲ Took {:.2?}", timer.elapsed());

    result
}
