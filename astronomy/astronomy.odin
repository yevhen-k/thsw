package astronomy

import "core:math"
import "core:time"

get_sunrise_sunset :: proc(
	longitude, latitude, tz: f32,
) -> (
	sunrise: time.Time,
	sunset: time.Time,
) {
	// Julian Day
	tz_nsec := i64(tz) *  /*hours*/3600 *  /*sec*/1e9 /*nsec*/
	julian_day := f64((time.now()._nsec) / 1e9) / 86400.0 + 2440587.5

	// Julian Century
	julian_century := (julian_day - 2451545.0) / 36525.0

	// Calculate the Geometric Mean Anomaly of the Sun (deg)
	mean_anomaly := 357.52911 + julian_century * (35999.05029 - 0.0001537 * julian_century)
	mean_anomaly_rad := math.to_radians(mean_anomaly)

	// Calculate the Geometric Mean Longitude of the Sun (deg)
	mean_longitude :=
		i64(280.46646 + julian_century * (36000.76983 + julian_century * 0.0003032)) % 360

	mean_longitude_rad := math.to_radians(f64(mean_longitude))

	// Calculate the mean obliquity of the ecliptic
	mean_obliquity :=
		23.0 +
		(26.0 +
				(21.448 -
						julian_century *
							(46.815 + julian_century * (0.00059 - julian_century * 0.001813))) /
					60.0) /
			60.0

	// Calculate the corrected obliquity of the ecliptic (deg)
	obliquity_correction :=
		mean_obliquity + 0.00256 * math.cos(math.to_radians(125.04 - 1934.136 * julian_century))
	obliquity_correction_rad := math.to_radians(obliquity_correction)

	// helper var
	helper_var := math.tan(obliquity_correction_rad / 2.0)
	helper_var *= helper_var

	// Calculate the eccentricity of earth's orbit
	eccentricity := 0.016708634 - julian_century * (0.000042037 + 0.0000001267 * julian_century)

	// Calculate the difference between true solar time and mean solar time
	eqtime :=
		4.0 *
		math.to_degrees(
			helper_var * math.sin(2.0 * mean_longitude_rad) -
			2.0 * eccentricity * math.sin(mean_anomaly_rad) +
			4.0 *
				eccentricity *
				helper_var *
				math.sin(mean_anomaly_rad) *
				math.cos(2.0 * mean_anomaly_rad) -
			0.5 * helper_var * helper_var * math.sin(4.0 * mean_longitude_rad) -
			1.25 * eccentricity * eccentricity * math.sin(2.0 * mean_longitude_rad),
		)

	// Solar Noon (LST)
	noon := (720.0 - 4.0 * f64(longitude) - eqtime * 60.0) / 1440.0

	// Calculate the equation of center for the sun
	sun_center :=
		math.sin(mean_anomaly_rad) *
			(1.914602 - julian_century * (0.004817 + 0.000014 * julian_century)) +
		math.sin(2.0 * mean_anomaly_rad) * (0.019993 - 0.000101 * julian_century) +
		math.sin(3.0 * mean_anomaly_rad) * 0.000289

	// Calculate the true longitude of the sun
	sun_longitude := f64(mean_longitude) + sun_center

	// Calculate the apparent longitude of the sun (deg)
	sun_long_app :=
		sun_longitude -
		0.00569 -
		0.00478 * math.sin(math.to_radians(125.04 - 1934.136 * julian_century))
	sun_long_app_rad := math.to_radians(sun_long_app)

	// Calculate the declination of the sun (deg)
	diclination := math.to_degrees(
		math.asin(math.sin(obliquity_correction_rad) * math.sin(sun_long_app_rad)),
	)
	diclination_rad := math.to_radians(diclination)

	// The solar hour angle, sunrise (deg)
	ZENITH_DEG: f64 : 90.833
	zenith_rad: f64 = math.to_radians(ZENITH_DEG)
	lat_rad := math.to_radians(f64(latitude))
	ha := math.to_degrees(
		math.acos(
			math.cos(zenith_rad) / (math.cos(lat_rad) * math.cos(diclination_rad)) -
			math.tan(lat_rad) * math.tan(diclination_rad),
		),
	)

	// Sunrise Time (LST)
	sunrise = time.Time {
		_nsec = i64((noon * 1440.0 - ha * 4.0) / 1440.0 * 3600 * 24 * 1e9),
	}
	sunrise = time.time_add(sunrise, -time.Duration(tz_nsec))

	// Sunset Time (LST)
	sunset = time.Time {
		_nsec = i64((noon * 1440.0 + ha * 4.0) / 1440.0 * 3600 * 24 * 1e9),
	}
	sunset = time.time_add(sunset, -time.Duration(tz_nsec))

	return
}
