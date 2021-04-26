# thsw
Simple application to switch desktop theme:
- from light to dark during sunset
- from dark to light during sunrise

The only limitations is that you have to provide command that 
actually switches the theme in config file.

In general the `thsw` can execute any provided command on sunset and sunrise.

## Build and run

Build the `thsw` with:
```shell
cargo build
```

Run the `thsw` with:
```shell
cargo run
```

Or alternatively you should start `thsw` directly:
```shell
./thsw
```

Example of config file is provided in [config.ini](config.ini)
You should place the config file to the location `thsw` give you at the first run.
Normally, it is `$HOME/.config/thsw/config.ini`

## References
It was quite difficult for find and implement algorithm that takes
geo coordinates with time zone and returns the time of sunset and 
sunrise for current day. Many thanks to resources and authors listed below.

1. General Solar Position Calculations, [link](https://www.esrl.noaa.gov/gmd/grad/solcalc/solareqns.PDF)
2. Solar Calculation Details, [link](https://www.esrl.noaa.gov/gmd/grad/solcalc/calcdetails.html)
3. Sunrise/Sunset Algorithm, [link](https://www.edwilliams.org/sunrise_sunset_algorithm.htm)
4. Julian Day Number Calculator, [link](https://quasar.as.utexas.edu/BillInfo/JulianDateCalc.html)
5. Jon Lund Steffensen, [redshift](https://github.com/jonls/redshift/blob/master/src/solar.c)
6. Thomas Brüggemann, [orbit](https://github.com/thomasbrueggemann/orbit/blob/master/sun.hpp)
