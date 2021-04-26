mod astronomy;
mod cfg;

use astronomy::Astronomy;
use cfg::get_cfg_path;
use cfg::CfgExtractor;
use chrono::{Local, NaiveTime};
use std::thread::sleep;
use std::time;

#[derive(Debug, PartialEq)]
enum LastExecuted {
    Day,
    Night,
    None,
}

fn main() {
    // get config path
    let cfg_file_path = get_cfg_path();

    // read config file
    let config = CfgExtractor::new(cfg_file_path);

    // prepare to populate Astronomy
    let local_time = Local::now();
    let tz = local_time.offset().local_minus_utc() / 3600; // 3 for UTC+3
    let latitude = config.get_latitude();
    let longitude = config.get_longitude();

    // populate astronomy
    let astronomy = Astronomy::new(latitude, longitude, tz);

    // get commands
    let (mut day_cmd, mut night_cmd) = config.get_commands();
    let sleep_time = time::Duration::from_secs(10 * 60); // 10 minutes
    let mut last_executed: LastExecuted = LastExecuted::None;

    // main loop
    loop {
        let (sunrise, sunset) = astronomy.process();
        let curr_time: NaiveTime = Local::now().time();
        // let curr_time: NaiveTime = NaiveTime::from_hms(21, 0, 0);
        let is_day = sunrise <= curr_time && curr_time <= sunset;
        let is_night = sunset <= curr_time || curr_time <= sunrise;

        // println!("now:\t\t{}", curr_time.format("%H:%M"));
        // println!("is_day:\t\t{}", is_day);
        // println!("is_night:\t{}", is_night);
        // println!("last execution:\t{:?}\n", last_executed);

        if is_day && (last_executed == LastExecuted::None || last_executed == LastExecuted::Night) {
            println!(">>> night -> day switching command execution\n");
            day_cmd
                .status()
                .expect(&format!("Can't execute command: {:?}", day_cmd));
            last_executed = LastExecuted::Day;
        }
        if is_night && (last_executed == LastExecuted::None || last_executed == LastExecuted::Day) {
            println!(">>> day -> night switching command execution\n");
            night_cmd
                .status()
                .expect(&format!("Can't execute command: {:?}", night_cmd));
            last_executed = LastExecuted::Night;
        }
        sleep(sleep_time);
    }
}
