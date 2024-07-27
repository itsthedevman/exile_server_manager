use super::*;

pub fn send_to_channel(id: String, content: String) {
    if !READY.load(Ordering::SeqCst) {
        error!("[send_to_channel] ⚠ This endpoint cannot be accessed before \"pre_init\" has completed");
        return;
    }

    let timer = std::time::Instant::now();
    trace!("[send_to_channel] id: {:?} - content: {:?}", id, content);

    std::thread::spawn(move || {
        TOKIO_RUNTIME.block_on(async {
            let message = Message::new().set_type(Type::Call).set_data(Data::from([
                ("function_name".to_owned(), json!("send_to_channel")),
                ("id".to_owned(), json!(id)),
                ("content".to_owned(), json!(content)),
            ]));

            if let Err(e) = BotRequest::send(message) {
                error!("[send_to_channel] ❌ {}", e);
            };

            info!("[send_to_channel] ⏲ Took {:.2?}", timer.elapsed());
        });
    });
}
