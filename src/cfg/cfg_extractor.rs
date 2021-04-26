use configparser::ini::Ini;
use std::path::PathBuf;
use std::process::Command;

pub struct CfgExtractor {
    config: Ini,
}

impl CfgExtractor {
    pub fn new(cfg_file_path: PathBuf) -> Self {
        let mut config = Ini::new_cs();
        let _ = config.load(cfg_file_path.to_str().unwrap());
        CfgExtractor { config }
    }

    pub fn get_latitude(&self) -> f32 {
        self.config
            .get("location", "latitude")
            .unwrap()
            .parse::<f32>()
            .unwrap()
    }

    pub fn get_longitude(&self) -> f32 {
        self.config
            .get("location", "longitude")
            .unwrap()
            .parse::<f32>()
            .unwrap()
    }

    pub fn get_commands(&self) -> (Command, Command) {
        let command_day = self.config.get("commands", "day").unwrap();
        let command_day_vec = command_day.split(" ").collect::<Vec<&str>>();
        let command_night = self.config.get("commands", "night").unwrap();
        let command_night_vec = command_night.split(" ").collect::<Vec<&str>>();

        // println!("command_day: {:?}", &command_day_vec);
        // println!("cmd: {:?}", &command_day_vec[0]);
        // println!("args: {:?}", &command_day_vec[1..]);

        // populate commands to be executed while sunrise or sunset
        let mut day_cmd = Command::new(&command_day_vec[0]);
        for cmd in &command_day_vec[1..] {
            day_cmd.arg(cmd);
        }

        let mut night_cmd = Command::new(&command_night_vec[0]);
        for cmd in &command_night_vec[1..] {
            night_cmd.arg(cmd);
        }

        (day_cmd, night_cmd)
    }
}
