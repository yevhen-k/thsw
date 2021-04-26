use chrono::{Local, NaiveTime};

#[derive(Copy, Clone, Debug)]
pub struct Astronomy {
    latitude: f32,
    longitude: f32,
    tz: i32,
}

impl Astronomy {
    pub fn new(latitude: f32, longitude: f32, tz: i32) -> Self {
        Astronomy {
            latitude,
            longitude,
            tz,
        }
    }

    pub fn process(&self) -> (NaiveTime, NaiveTime) {
        // Julian Day
        let julian_day = Local::now().timestamp() as f64 / 86400.0 + 2440587.5;

        // Julian Century
        let julian_century = (julian_day - 2451545.0) / 36525.0;

        // Calculate the Geometric Mean Anomaly of the Sun (deg)
        let mean_anomaly = 357.52911 + julian_century * (35999.05029 - 0.0001537 * julian_century);
        let mean_anomaly_rad = Self::deg_to_rad(mean_anomaly);

        // Calculate the Geometric Mean Longitude of the Sun (deg)
        let mean_longitude =
            (280.46646 + julian_century * (36000.76983 + julian_century * 0.0003032)) % 360.0;
        let mean_longitude_rad = Self::deg_to_rad(mean_longitude);

        // Calculate the mean obliquity of the ecliptic
        let mean_obliquity = 23.0
            + (26.0
                + (21.448
                    - julian_century
                        * (46.815 + julian_century * (0.00059 - julian_century * 0.001813)))
                    / 60.0)
                / 60.0;

        // Calculate the corrected obliquity of the ecliptic (deg)
        let obliquity_correction =
            mean_obliquity + 0.00256 * Self::deg_to_rad(125.04 - 1934.136 * julian_century).cos();
        let obliquity_correction_rad = Self::deg_to_rad(obliquity_correction);

        // helper var
        let mut helper_var = (obliquity_correction_rad / 2.0).tan();
        helper_var *= helper_var;

        // Calculate the eccentricity of earth's orbit
        let eccentricity =
            0.016708634 - julian_century * (0.000042037 + 0.0000001267 * julian_century);

        // Calculate the difference between true solar time and mean solar time
        let eqtime = 4.0
            * Self::rad_to_deg(
                helper_var * (2.0 * mean_longitude_rad).sin()
                    - 2.0 * eccentricity * mean_anomaly_rad.sin()
                    + 4.0
                        * eccentricity
                        * helper_var
                        * mean_anomaly_rad.sin()
                        * (2.0 * mean_anomaly_rad).cos()
                    - 0.5 * helper_var * helper_var * (4.0 * mean_longitude_rad).sin()
                    - 1.25 * eccentricity * eccentricity * (2.0 * mean_longitude_rad).sin(),
            );

        // Solar Noon (LST)
        let noon = (720.0 - 4.0 * self.longitude as f64 - eqtime + self.tz as f64 * 60.0) / 1440.0;

        // Calculate the equation of center for the sun
        let sun_center = mean_anomaly_rad.sin()
            * (1.914602 - julian_century * (0.004817 + 0.000014 * julian_century))
            + (2.0 * mean_anomaly_rad).sin() * (0.019993 - 0.000101 * julian_century)
            + (3.0 * mean_anomaly_rad).sin() * 0.000289;

        // Calculate the true longitude of the sun
        let sun_longitude = mean_longitude + sun_center;

        // Calculate the apparent longitude of the sun (deg)
        let sun_long_app = sun_longitude
            - 0.00569
            - 0.00478 * Self::deg_to_rad(125.04 - 1934.136 * julian_century).sin();
        let sun_long_app_rad = Self::deg_to_rad(sun_long_app);

        // Calculate the declination of the sun (deg)
        let diclination =
            Self::rad_to_deg((obliquity_correction_rad.sin() * sun_long_app_rad.sin()).asin());
        let diclination_rad = Self::deg_to_rad(diclination);

        // The solar hour angle, sunrise (deg)
        const ZENITH_DEG: f64 = 90.833;
        let zenith_rad: f64 = Self::deg_to_rad(ZENITH_DEG);
        let lat_rad = Self::deg_to_rad(self.latitude as f64);
        let ha = Self::rad_to_deg(
            (zenith_rad.cos() / (lat_rad.cos() * diclination_rad.cos())
                - lat_rad.tan() * diclination_rad.tan())
            .acos(),
        );

        // Sunrise Time (LST)
        let sunrise = (noon * 1440.0 - ha * 4.0) / 1440.0;
        let naive_sr_time = Self::day_part_to_nt(sunrise);
        // Sunset Time (LST)
        let sunset = (noon * 1440.0 + ha * 4.0) / 1440.0;
        let naive_ss_time = Self::day_part_to_nt(sunset);
        (naive_sr_time, naive_ss_time)
    }

    fn deg_to_rad(deg: f64) -> f64 {
        deg * 2.0 * std::f64::consts::PI / 360.0
    }

    fn rad_to_deg(rad: f64) -> f64 {
        rad * 360.0 / (2.0 * std::f64::consts::PI)
    }

    fn day_part_to_nt(day_part: f64) -> NaiveTime {
        let seconds = (day_part * 3600.0 * 24.0).round();
        let hours = (seconds / 3600.0).floor();
        let minutes = ((seconds / 3600.0 - hours) * 60.0).round();
        NaiveTime::from_hms(hours as u32, minutes as u32, 0)
    }
}
