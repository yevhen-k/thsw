package thsw

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
// to calc time
import "core:time"
// to parse ini file
import "core:encoding/ini"
// to get env vars on linux
import "core:sys/posix"
// to execute commands on linux
import "core:c/libc"
// to check if file exists on linux
import "core:sys/linux"

import "astronomy"


CONFIG_EXAMPLE ::
	"[location]\n" +
	"latitude=51.1740\n" +
	"longitude=-1.8224\n" +
	"tz=3\n\n" +
	"[commands]\n" +
	"; Here you can actually set anycommand\n" +
	"; you want to be executed during sunrise or sunset\n" +
	"day=xfconf-query -c xsettings -p /Net/ThemeName -s Adapta - Eta - Maia\n" +
	"night xfconf-query -c xsettings -p /Net/ThemeName -s Adapta - Nokto - Maia"


LastExecuted :: enum {
	Day,
	Night,
	None,
}

get_cfg_path :: proc(
	allocator := context.allocator,
) -> (
	path: string,
	ok: bool,
	err: mem.Allocator_Error,
) {
	cur_location :: "./config.ini"
	conf_location :: ".config/thsw/config.ini"
	when ODIN_OS == .Linux {

		// Check in current folder
		if linux.access(cur_location) == linux.Errno.NONE {
			path, err = strings.clone(cur_location, allocator = allocator)
			ok = err != nil
			return
		}

		// Check in `.config/` folder
		env := posix.environ
		home :: "HOME"
		homepath: string
		defer delete(homepath)
		for i, entry := 0, posix.environ[0]; entry != nil; i, entry = i + 1, posix.environ[i] {
			entry := string(entry)
			key, err := strings.split(entry, sep = "=", allocator = allocator)
			if err != nil {
				log.error("Failed to allocate mem")
				return "", false, err
			}
			defer delete(key)
			if key[0] == home {
				homepath, err = strings.clone(key[1], allocator = allocator)
				if err != nil {
					log.error("Failed to allocate mem")
					return "", false, err
				}
				break
			}
		}
		full_conf_path: string
		full_conf_path, err = strings.concatenate(
			{homepath, "/", conf_location},
			allocator = allocator,
		)
		if err != nil {
			log.error("Failed to allocate mem")
			return "", false, err
		}
		if linux.access(strings.unsafe_string_to_cstring(full_conf_path)) == linux.Errno.NONE {
			return full_conf_path, true, nil
		}
		return "", false, nil
	}
	when ODIN_OS == .Windows {
		env := os.environ()
		exists := os.exists("./config.ini")
		log.panic("Windows support is unimplemented")
	}
	return "", false, nil
}

parse_config :: proc(
	config: ini.Map,
) -> (
	day_cmd: string,
	night_cmd: string,
	longitude: f32,
	latitude: f32,
	tz: f32,
	ok: bool,
) {
	longitude, ok = strconv.parse_f32(config["location"]["longitude"])
	if !ok {
		log.error("Cannon parse longitude")
		return
	}
	latitude, ok = strconv.parse_f32(config["location"]["latitude"])
	if !ok {
		log.error("Cannon parse latitude")
		return
	}
	tz, ok = strconv.parse_f32(config["location"]["tz"])
	if !ok {
		log.error("Cannon parse tz")
		return
	}

	day_cmd, ok = config["commands"]["day"]
	if !ok {
		log.error("Cannon parse day command")
		return
	}
	night_cmd, ok = config["commands"]["night"]
	if !ok {
		log.error("Cannon parse night command")
		return
	}
	ok = true
	return
}

main1 :: proc() {
	s: string
	fmt.printfln("%v, %d, %t", s, len(s), s == "")
}

// odin run . -debug
main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	// Logger
	logger := log.create_console_logger()
	context.logger = logger
	defer log.destroy_console_logger(logger)

	// Get config file
	cfg_file_path, ok, err := get_cfg_path()
	if err != nil {
		log.error("Failed to allocate memoty for config. Exiting")
		os.exit(1)
	}
	if !ok {
		log.error(
			"Config not found. Please, create `config.ini` and put it to the current folder or `.config/thsw/config.ini`",
		)
		fmt.printfln("`config.ini` example:\n%s", CONFIG_EXAMPLE)
	}
	defer delete(cfg_file_path)
	cfg, _, ok_load := ini.load_map_from_path(path = cfg_file_path, allocator = context.allocator)
	if !ok_load {
		log.errorf("Cannon open file `%s`", cfg_file_path)
		os.exit(1)
	}
	defer ini.delete_map(cfg)

	day_cmd, night_cmd, longitude, latitude, tz, ok_parse := parse_config(cfg)
	if !ok_parse {
		log.errorf("Cannon open file `%s`", cfg_file_path)
		os.exit(1)
	}
	fmt.printfln(
		"\nday: %s\nnight: %s\nlon: %f\nlat: %f\ntz: %f",
		day_cmd,
		night_cmd,
		longitude,
		latitude,
		tz,
	)

	last_executed := LastExecuted.None

	sleep_time := time.Duration(
		10 * 1e9 *  /*s*/60,
		/*min*/
	)
	for {
		local_now := time.time_add(time.now(), time.Duration(i64(tz) * 3600 * 1e9))
		local_hour, local_min, local_sec := time.clock(local_now)
		secons_today := local_hour * 60 * 60 + local_min * 60 + local_sec
		fmt.printfln("cur time: %d:%d:%d", local_hour, local_min, local_sec)
		// fmt.printfln("local_now: %d", local_now)

		local_sunrise, local_sunset := astronomy.get_sunrise_sunset(longitude, latitude, tz)
		// fmt.printfln("sunrise: %d", sunrise)
		// fmt.printfln("sunset: %d", sunset)

		sunrise_hour, sunrise_min, sunrise_sec := time.clock(local_sunrise)
		sunset_hour, sunset_min, sunset_sec := time.clock(local_sunset)
		fmt.printfln("sunrise: %d:%d:%d", sunrise_hour, sunrise_min, sunrise_sec)
		fmt.printfln("sunset: %d:%d:%d", sunset_hour, sunset_min, sunset_sec)

		seconds_until_sunrise := sunrise_hour * 60 * 60 + sunrise_min * 60 + sunrise_sec
		seconds_until_sunset := sunset_hour * 60 * 60 + sunset_min * 60 + sunset_sec
		is_day := seconds_until_sunrise <= secons_today && secons_today <= seconds_until_sunset
		is_night := seconds_until_sunset <= secons_today || secons_today <= seconds_until_sunrise
		fmt.printfln("is_day? %t\nis_night? %t", is_day, is_night)

		if is_day && (last_executed == LastExecuted.None || last_executed == LastExecuted.Night) {
			log.info(">>> night -> day switching command execution\n")
			when ODIN_OS == .Linux {
				res_day := libc.system(strings.unsafe_string_to_cstring(day_cmd))
				log.info(res_day)
				if res_day != 0 {
					log.errorf("Cannot execute command: %s", day_cmd)
					os.exit(1)
				}
			}
			// TODO: implement windows
			when ODIN_OS == .Windows {
				log.painc("Windows support is unimplemeted")
			}
			last_executed = LastExecuted.Day
		}
		if is_night && (last_executed == LastExecuted.None || last_executed == LastExecuted.Day) {
			log.info(">>> day -> night switching command execution\n")
			when ODIN_OS == .Linux {
				res_night := libc.system(strings.unsafe_string_to_cstring(night_cmd))
				if res_night != 0 {
					log.errorf("Cannot execute command: %s", night_cmd)
					os.exit(1)
				}
			}
			// TODO: implement windows
			when ODIN_OS == .Windows {
				log.painc("Windows support is unimplemeted")
			}

			last_executed = LastExecuted.Night
		}
		time.sleep(sleep_time)
	}
}
