use serde_json::json;
use std::thread;

fn main() {
    println!("Starting ESM");

    let server_name = String::from("esm_bin (¯\\\\_(ツ)_/¯)");
    let price_per_object = String::from("10");
    let territory_lifetime = String::from("7");
    let territory_data = json!([
        [
            ["level", "1"],
            ["purchase_price", "5000"],
            ["radius", "15"],
            ["object_count", "30"]
        ],
        [
            ["level", "2"],
            ["purchase_price", "10000"],
            ["radius", "30"],
            ["object_count", "60"]
        ],
        [
            ["level", "3"],
            ["purchase_price", "15000"],
            ["radius", "45"],
            ["object_count", "90"]
        ],
        [
            ["level", "4"],
            ["purchase_price", "20000"],
            ["radius", "60"],
            ["object_count", "120"]
        ],
        [
            ["level", "5"],
            ["purchase_price", "25000"],
            ["radius", "75"],
            ["object_count", "150"]
        ],
        [
            ["level", "6"],
            ["purchase_price", "30000"],
            ["radius", "90"],
            ["object_count", "180"]
        ],
        [
            ["level", "7"],
            ["purchase_price", "35000"],
            ["radius", "105"],
            ["object_count", "210"]
        ],
        [
            ["level", "8"],
            ["purchase_price", "40000"],
            ["radius", "120"],
            ["object_count", "240"]
        ],
        [
            ["level", "9"],
            ["purchase_price", "45000"],
            ["radius", "135"],
            ["object_count", "270"]
        ],
        [
            ["level", "10"],
            ["purchase_price", "50000"],
            ["radius", "150"],
            ["object_count", "300"]
        ]
    ])
    .to_string();

    let extension = esm_arma::init().testing();

    let args = vec![
        server_name,
        price_per_object,
        territory_lifetime,
        territory_data,
        true.to_string(),
        String::from(r#"["-1","5","8","11","13","15","18","21","25","28"]"#),
    ];

    let (_result, _) = unsafe { extension.call("pre_init", Some(args)) };

    loop {
        thread::sleep(std::time::Duration::from_secs(1))
    }
}
