use super::*;

pub fn pre_init(
    callback: Context,
    server_name: String,
    price_per_object: NumberString,
    territory_lifetime: NumberString,
    territory_data: String,
    vg_enabled: bool,
    vg_max_sizes: String,
) {
    // Only allow this method to be called properly once
    if READY.load(Ordering::SeqCst) {
        error!("[pre_init] ⚠ This endpoint can only be called once. Perhaps your server is boot looping?");
        return;
    }

    let timer = std::time::Instant::now();
    debug!(
        r#"[pre_init]
            server_name: {:?}
            price_per_object: {:?}
            territory_lifetime: {:?}
            territory_data: {:?}
            vg_enabled: {:?}
            vg_max_sizes: {:?}
        "#,
        server_name,
        price_per_object,
        territory_lifetime,
        territory_data,
        vg_enabled,
        vg_max_sizes
    );

    // Router must be initialized outside the async context
    lazy_static::initialize(&ROUTER);

    info!("[pre_init] Exile Server Manager (extension) is initializing");
    info!("[pre_init]   Validating config file...");

    if let Err(e) = CONFIG.validate() {
        error!("[pre_init] ❌ Boot failed - Invalid config file");
        warn!("[validate] ⚠ {}", e);
        error!("[pre_init] ❌ Boot failed - You must fix the above warning before Exile Server Manager can boot");
        return;
    }

    info!("[pre_init]   Validating initialization package...");

    // Using the data from the a3 server, create a data packet to be used whenever the server connects to the bot.
    let init = Init {
        server_name,
        price_per_object,
        territory_lifetime,
        territory_data,
        vg_enabled,
        vg_max_sizes,
        server_start_time: Utc::now(),
        extension_version: format!(
            "{}+{}",
            env!("CARGO_PKG_VERSION"),
            std::include_str!("../../.build-sha")
        ),
    };

    if let Err(errors) = init.validate() {
        debug!("{:#?}", init);
        error!("[pre_init] ❌ Boot failed - Invalid initialization data provided");

        for error in errors {
            warn!("[validate] ⚠ {error}");
        }

        error!("[pre_init] ❌ Boot failed - You must fix the above warnings before Exile Server Manager can boot");
        return;
    }

    info!("[pre_init]   Initializing...");

    if let Err(e) = ArmaRequest::initialize(callback) {
        error!("[pre_init] ❌ Boot failed - Failed to initialize connection to Arma");
        warn!("[pre_init] ⚠ {e}");
        error!("[pre_init] ❌ Boot failed");
    };

    if let Err(e) = BotRequest::initialize(init) {
        error!("[pre_init] ❌ Boot failed - Failed to initialize connection to the bot");
        warn!("[pre_init] ⚠ {e}");
        error!("[pre_init] ❌ Boot failed");
        return;
    };

    TOKIO_RUNTIME.block_on(async {
        info!("[pre_init]   Connecting to the database...");
        if let Err(e) = DATABASE.connect().await {
            error!("[pre_init] ❌ Boot failed - Failed to connect to the database");
            warn!("[pre_init] ⚠ {e}");
            error!("[pre_init] ❌ Boot failed");
            return;
        }
    });

    info!(
        "[pre_init] ✅ Initialization completed in {:.2?}",
        timer.elapsed()
    );
}
