# SkyMap64 v1.1 – personal planetarium for the Commodore 64

SkyMap64 draws the night sky for a given date, time and place, in the spirit of SkySafari. It shows 1041 stars down to magnitude 4.5, the lines and Latin names of all 89 constellations, named bright stars, all 110 Messier objects, the Sun, the Moon and the planets Mercury to Saturn. It also draws the horizon with the ground, the compass points, and a blue sky in daytime.

## Running

**VICE:** open `skymap64en.d64` (File → Smart attach) or run `x64sc skymap64en.d64`.
**Real C64:** copy the D64 to an SD2IEC, Ultimate etc. and type `LOAD"SKYMAP64EN",8` followed by `RUN`.

The title screen appears first; press RETURN. Then enter the day, month, year, hour, minute, time zone (hours east of UTC) and your latitude (north positive) and longitude (east positive). RETURN keeps the shown value; the defaults are Greenwich. After a keypress the program computes the positions and the sunset/moonset times (about 23 s), shows a summary and then the sky.

## Controls

| Key | Function |
|---|---|
| cursor keys / joystick in port 2 | rotate the view |
| `+` `-` | zoom in / out (field of view 120°, 90°, 60°, 40°, 25°, 15°) |
| `N` `E` `S` `W` | face north / east / south / west |
| `,` `.` | time −/+ 10 minutes |
| `:` `;` | time −/+ 1 hour |
| `RETURN` | recompute the planets for the current time |
| `I` | summary: sunset, astronomical night, moonset |
| `F` | find an object (planet, named star, Messier object such as `M31`, constellation); the start of the name is enough |
| `C` / `L` / `M` | constellation lines / labels / Messier objects on/off |
| `D` / `Q` | new date or place / quit |

The status bar shows the viewing direction, altitude, field of view, date (YYYY-MM-DD) and time. An asterisk `*` means that the time was changed and the planets have not been recomputed yet; press RETURN.

One redraw takes about 2.5 s. Star and horizon positions match PyEphem to within 1–3 pixels; planets are accurate to about 1°; the rise/set times to about a minute.

## Building

See the Czech README: `src/build.sh` builds both the Czech and the English version from the same sources (ACME, petcat/c1541 from VICE, Python 3 with NumPy).

Data: stars, constellations and the Messier catalogue from d3-celestial (BSD-3, based on Hipparcos and Stellarium); planetary formulas by Paul Schlyter.
