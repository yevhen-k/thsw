use std::env;
use std::fs;
use std::path::{Path, PathBuf};

const CONFIG_SAMPLE: &str = r#"[location]
latitude=51.1740
longitude=-1.8224

[commands]
; Here you can actually set any command
; you want to be executed during sunrise or sunset
day=xfconf-query -c xsettings -p /Net/ThemeName -s Adapta-Eta-Maia
night=xfconf-query -c xsettings -p /Net/ThemeName -s Adapta-Nokto-Maia"#;

pub fn get_cfg_path() -> PathBuf {
    let home_env = "HOME";
    let home_env_path = env::vars().find(|(key, _)| key == home_env);

    let home_dir = match home_env_path {
        Some((_, home_dir)) => home_dir,
        None => {
            println!("HOME environment variable not found. Will use current dir to read config.");
            String::from(".")
        }
    };

    // check if config file exists
    let cfg_dir_str = &format!("{}/.config/thsw", home_dir);
    let cfg_dir_path = Path::new(cfg_dir_str);
    if !cfg_dir_path.exists() {
        fs::create_dir_all(cfg_dir_path)
            .expect(&format!("Failed create directory {:?}", cfg_dir_path));
    }
    let cfg_file_str: &String = &format!("{}/config.ini", cfg_dir_str);
    let cfg_file_path: &Path = Path::new(cfg_file_str);
    if !cfg_file_path.exists() || !cfg_file_path.is_file() {
        println!("Please, create config file first: {:?}", cfg_file_path);
        println!("Sample content is:\n{}", CONFIG_SAMPLE);
        std::process::exit(1);
    }
    cfg_file_path.to_owned()
}
