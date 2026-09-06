// Checks JalaliDate.js against dates that can be verified independently, and
// doubles as a conversion tool for whoever maintains holidays-lunar.json.
//
//   node test/jalali-date-test.js              run the checks
//   node test/jalali-date-test.js 1405 3 6     print one Jalali date's Gregorian equivalent
//   node test/jalali-date-test.js 2026-05-27   print one Gregorian date's Jalali equivalent

var path = require("path")
var J = require(path.join(__dirname, "..", "JalaliDate.js"))

var argv = process.argv.slice(2)

if (argv.length === 3) {
  var jy = Number(argv[0]), jm = Number(argv[1]), jd = Number(argv[2])
  var g = J.toGregorian(jy, jm, jd)
  console.log(J.longLabel(jy, jm, jd) + "  =  " + J.gregorianLabel(g.gy, g.gm, g.gd))
  process.exit(0)
}

if (argv.length === 1 && /^\d{4}-\d{1,2}-\d{1,2}$/.test(argv[0])) {
  var parts = argv[0].split("-").map(Number)
  var j = J.toJalali(parts[0], parts[1], parts[2])
  console.log(J.gregorianLabel(parts[0], parts[1], parts[2]) + "  =  " + J.longLabel(j.jy, j.jm, j.jd))
  process.exit(0)
}

var failures = 0
function check(label, got, want) {
  var g = JSON.stringify(got), w = JSON.stringify(want)
  if (g === w) { console.log("  ok   " + label) }
  else { failures++; console.log("  FAIL " + label + "\n         got  " + g + "\n         want " + w) }
}

console.log("Nowruz anchors (1 Farvardin -> Gregorian)")
check("1400", J.toGregorian(1400, 1, 1), { gy: 2021, gm: 3, gd: 21 })
check("1403", J.toGregorian(1403, 1, 1), { gy: 2024, gm: 3, gd: 20 })
check("1404", J.toGregorian(1404, 1, 1), { gy: 2025, gm: 3, gd: 21 })
check("1405", J.toGregorian(1405, 1, 1), { gy: 2026, gm: 3, gd: 21 })
check("1406", J.toGregorian(1406, 1, 1), { gy: 2027, gm: 3, gd: 21 })
check("1407", J.toGregorian(1407, 1, 1), { gy: 2028, gm: 3, gd: 20 })
check("1408", J.toGregorian(1408, 1, 1), { gy: 2029, gm: 3, gd: 20 })

console.log("Weekdays (Shanbe-first)")
// 21 March 2026 is a Saturday; 20 March 2024 a Wednesday; 21 March 2021 a Sunday.
check("1405-01-01 is Shanbe", J.WEEKDAYS[J.weekdayOf(1405, 1, 1)], "Shanbe")
check("1403-01-01 is Chaharshanbe", J.WEEKDAYS[J.weekdayOf(1403, 1, 1)], "Chaharshanbe")
check("1400-01-01 is Yekshanbe", J.WEEKDAYS[J.weekdayOf(1400, 1, 1)], "Yekshanbe")

console.log("Leap years and Esfand length")
var leaps = []
for (var y = 1370; y <= 1440; y++) if (J.isLeapYear(y)) leaps.push(y)
// Eight leap years to a 33-year cycle, spaced 4 except for the 5 that closes it.
check("leap years 1370-1440", leaps,
  [1370, 1375, 1379, 1383, 1387, 1391, 1395, 1399, 1403, 1408, 1412, 1416, 1420, 1424, 1428, 1432, 1436])
check("Esfand 1403 (leap)", J.monthLength(1403, 12), 30)
check("Esfand 1404", J.monthLength(1404, 12), 29)
check("Esfand 1408 (leap)", J.monthLength(1408, 12), 30)

console.log("Internal consistency, Jalali 1300-1500")
var lengthMismatches = 0
for (var ly = 1300; ly <= 1500; ly++)
  if (J.jalaliToJdn(ly + 1, 1, 1) - J.jalaliToJdn(ly, 1, 1) !== (J.isLeapYear(ly) ? 366 : 365)) lengthMismatches++
check("year length equals the gap between Nowruzes", lengthMismatches, 0)

var roundTripFailures = 0, days = 0
for (var ry = 1300; ry <= 1500; ry++) {
  for (var rm = 1; rm <= 12; rm++) {
    for (var rd = 1, len = J.monthLength(ry, rm); rd <= len; rd++) {
      var gr = J.toGregorian(ry, rm, rd)
      var back = J.toJalali(gr.gy, gr.gm, gr.gd)
      days++
      if (back.jy !== ry || back.jm !== rm || back.jd !== rd) roundTripFailures++
    }
  }
}
check("round trip over " + days + " days", roundTripFailures, 0)

console.log("Month grid")
var grid = J.monthGrid(1405, 1, "1405-01-01", null)
check("always six rows", grid.length, 6)
check("Farvardin 1405 opens on Shanbe", grid[0].days[0].key, "1405-01-01")
check("Jome is the last column", grid[0].days[6].weekend, true)
check("step past Esfand", J.stepMonth(1404, 12, 1), { jy: 1405, jm: 1 })
check("step back past Farvardin", J.stepMonth(1405, 1, -1), { jy: 1404, jm: 12 })

console.log("Clock labels")
// Built from local parts, so these assert the local wall clock rather than UTC.
var morning = new Date(2026, 8, 6, 9, 5, 0)
check("zero-padded on both halves", J.timeLabel(morning), "09:05")
check("24-hour, no meridiem", J.timeLabel(new Date(2026, 8, 6, 23, 59, 0)), "23:59")
check("midnight is 00:00, not 24:00", J.timeLabel(new Date(2026, 8, 6, 0, 0, 0)), "00:00")
check("the halves the vertical bar stacks", [J.hourLabel(morning), J.minuteLabel(morning)], ["09", "05"])

console.log(failures === 0 ? "\nAll checks passed." : "\n" + failures + " check(s) failed.")
process.exit(failures === 0 ? 0 : 1)
