// Gregorian <-> Jalali (Solar Hijri) conversion, plus the Finglish name tables
// and the month-grid builder the panel draws from.
//
// Deliberately Qt-free and side-effect-free so the same file runs under node
// for testing (see the check script in the README) and inside QML unchanged.
// Everything is integer arithmetic on Julian Day Numbers; no JS Date objects
// are used for calendar math, so a DST boundary can never shift a day.
//
// The leap rule is Borkowski's: the Jalali year is astronomical, not cyclic,
// so its leap years are described by a table of "breaks" -- years at which the
// spacing of leap years changes -- rather than by a modulus. Within a break
// interval leap years fall every 4 years with an 8-per-33 correction. This is
// the published description of the algorithm; the numbers below are its data.

// Years at which the leap-year spacing changes. Valid domain is
// [-61, 3177]; anything outside it is refused rather than guessed at.
var LEAP_BREAKS = [
  -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181,
  1210, 1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178
]

var MONTHS = [
  "Farvardin", "Ordibehesht", "Khordad", "Tir", "Mordad", "Shahrivar",
  "Mehr", "Aban", "Azar", "Dey", "Bahman", "Esfand"
]

// Saturday-first, the Iranian week.
var WEEKDAYS = [
  "Shanbe", "Yekshanbe", "Doshanbe", "Seshanbe", "Chaharshanbe", "Panjshanbe", "Jome"
]

// Two letters is enough to tell the seven apart and keeps the column heads
// narrower than the day numbers under them, so the row reads as a rule.
var WEEKDAYS_SHORT = ["Sh", "Ye", "Do", "Se", "Ch", "Pa", "Jo"]

var GREGORIAN_MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
]

// Integer division truncating toward zero, and its matching remainder. This
// is the arithmetic the published formulas below are written in -- several of
// them take the quotient of a small negative number, where truncation gives 0
// and flooring gives -1. Swapping in Math.floor here shifts whole years, so
// the two are not interchangeable. Where flooring really is wanted (stepping
// months across a year boundary) the pair further down is used instead.
function idiv(a, b) { return Math.trunc(a / b) }
function imod(a, b) { return a - Math.trunc(a / b) * b }

function floorDiv(a, b) { return Math.floor(a / b) }
function floorMod(a, b) { return a - Math.floor(a / b) * b }

// --- leap-year table ------------------------------------------------------

// Walks the break table for `jy` and returns everything downstream needs:
//   leap    0..3, the year's position in its 4-year leap group (0 = leap)
//   gy      the Gregorian year 1 Farvardin falls in
//   march   the day of March that 1 Farvardin falls on
function yearInfo(jy) {
  var last = LEAP_BREAKS.length - 1
  if (jy < LEAP_BREAKS[0] || jy >= LEAP_BREAKS[last])
    throw new Error("Jalali year out of supported range: " + jy)

  var gy = jy + 621
  var leapCount = -14          // leap days accumulated since the epoch break
  var breakStart = LEAP_BREAKS[0]
  var span = 0

  for (var i = 1; i <= last; i++) {
    span = LEAP_BREAKS[i] - breakStart
    if (jy < LEAP_BREAKS[i]) break
    leapCount += idiv(span, 33) * 8 + idiv(imod(span, 33), 4)
    breakStart = LEAP_BREAKS[i]
  }

  var offset = jy - breakStart
  leapCount += idiv(offset, 33) * 8 + idiv(imod(offset, 33) + 3, 4)
  // A break interval whose remainder is 4 ends on a leap year that the
  // formula above stops one short of.
  if (imod(span, 33) === 4 && span - offset === 4) leapCount += 1

  // Gregorian leap days over the same stretch, so the two drifts cancel.
  var gregorianLeaps = idiv(gy, 4) - idiv((idiv(gy, 100) + 1) * 3, 4) - 150

  // Position in the 4-year group, measured from the start of the interval and
  // pulled back into range for the last few years before the next break.
  var n = offset
  if (span - offset < 6) n = n - span + idiv(span + 4, 33) * 33
  var leap = imod(imod(n + 1, 33) - 1, 4)
  if (leap === -1) leap = 4

  return { leap: leap, gy: gy, march: 20 + leapCount - gregorianLeaps }
}

function isLeapYear(jy) {
  return yearInfo(jy).leap === 0
}

// Farvardin..Shahrivar are 31 days, Mehr..Bahman 30, Esfand 29 or 30.
function monthLength(jy, jm) {
  if (jm <= 6) return 31
  if (jm <= 11) return 30
  return isLeapYear(jy) ? 30 : 29
}

function yearLength(jy) {
  return isLeapYear(jy) ? 366 : 365
}

// --- Julian Day Number bridges -------------------------------------------

// Fliegel & Van Flandern's closed-form Gregorian <-> Julian Day Number pair.
// The calendar is treated as proleptic and the year runs March-to-February
// internally, which is what removes the leap day from the middle of the
// arithmetic. Every operand here is non-negative for any year the plugin can
// reach, so the divisions are ordinary floors.
function gregorianToJdn(gy, gm, gd) {
  var priorMarch = idiv(14 - gm, 12)      // 1 for Jan/Feb, 0 otherwise
  var y = gy + 4800 - priorMarch
  var m = gm + 12 * priorMarch - 3
  return gd + idiv(153 * m + 2, 5) + 365 * y
    + idiv(y, 4) - idiv(y, 100) + idiv(y, 400) - 32045
}

function jdnToGregorian(jdn) {
  var a = jdn + 32044
  var centuries = idiv(4 * a + 3, 146097)
  var c = a - idiv(146097 * centuries, 4)
  var years = idiv(4 * c + 3, 1461)
  var dayOfYear = c - idiv(1461 * years, 4)
  var m = idiv(5 * dayOfYear + 2, 153)     // 0 = March .. 11 = February
  return {
    gy: 100 * centuries + years - 4800 + idiv(m, 10),
    gm: m + 3 - 12 * idiv(m, 10),
    gd: dayOfYear - idiv(153 * m + 2, 5) + 1
  }
}

function jalaliToJdn(jy, jm, jd) {
  var info = yearInfo(jy)
  // The first six months are 31 days, the next five 30; the correction term
  // is what steps the run length down at Mehr.
  return gregorianToJdn(info.gy, 3, info.march)
    + (jm - 1) * 31 - idiv(jm, 7) * (jm - 7) + jd - 1
}

function jdnToJalali(jdn) {
  var g = jdnToGregorian(jdn)
  var jy = g.gy - 621
  var info = yearInfo(jy)
  var newYearJdn = gregorianToJdn(info.gy, 3, info.march)
  var offset = jdn - newYearJdn

  if (offset >= 0) {
    if (offset <= 185) return { jy: jy, jm: 1 + idiv(offset, 31), jd: imod(offset, 31) + 1 }
    offset -= 186
  } else {
    // Before Nowruz: still the previous Jalali year, in its 30-day half.
    // `info.leap === 1` means the year we are stepping back into was itself
    // a leap year, so its Esfand ran to 30 days.
    jy -= 1
    offset += 179
    if (info.leap === 1) offset += 1
  }
  return { jy: jy, jm: 7 + idiv(offset, 30), jd: imod(offset, 30) + 1 }
}

// --- public conversions ---------------------------------------------------

function toJalali(gy, gm, gd) {
  return jdnToJalali(gregorianToJdn(gy, gm, gd))
}

function toGregorian(jy, jm, jd) {
  return jdnToGregorian(jalaliToJdn(jy, jm, jd))
}

// Reads a JS Date in local time. Only used at the edges (what is today, what
// did the clock just tick to); all grid math stays on JDNs.
function fromDate(date) {
  return toJalali(date.getFullYear(), date.getMonth() + 1, date.getDate())
}

// --- weekday --------------------------------------------------------------

// Julian Day Number 0 was a Monday, so jdn % 7 is a Monday-zero weekday.
// Shifting by 2 puts Shanbe (Saturday) at index 0, matching WEEKDAYS.
function weekdayOfJdn(jdn) {
  return floorMod(floorMod(jdn, 7) + 2, 7)
}

function weekdayOf(jy, jm, jd) {
  return weekdayOfJdn(jalaliToJdn(jy, jm, jd))
}

// --- formatting -----------------------------------------------------------

// Sortable, and the key the holiday tables are looked up by.
function keyFor(jy, jm, jd) {
  return jy + "-" + (jm < 10 ? "0" : "") + jm + "-" + (jd < 10 ? "0" : "") + jd
}

function monthName(jm) { return MONTHS[jm - 1] || "" }
function weekdayName(index) { return WEEKDAYS[index] || "" }

// "13 Shahrivar" -- what the bar shows.
function shortLabel(jy, jm, jd) {
  return jd + " " + monthName(jm)
}

// "Jome, 13 Shahrivar 1405" -- the panel header.
function longLabel(jy, jm, jd) {
  return weekdayName(weekdayOf(jy, jm, jd)) + ", " + jd + " " + monthName(jm) + " " + jy
}

// "4 September 2026" -- the Gregorian equivalent in a day's detail line.
function gregorianLabel(gy, gm, gd) {
  return gd + " " + GREGORIAN_MONTHS[gm - 1] + " " + gy
}

// --- month stepping and grid ---------------------------------------------

function stepMonth(jy, jm, delta) {
  var total = jy * 12 + (jm - 1) + delta
  return { jy: floorDiv(total, 12), jm: floorMod(total, 12) + 1 }
}

// Whether a month can be shown at all: the ends of the supported range have
// no neighbouring year to spill into.
function isSupported(jy) {
  return jy > LEAP_BREAKS[0] && jy < LEAP_BREAKS[LEAP_BREAKS.length - 1] - 1
}

// Six rows of seven cells, always -- the panel is the same height in Esfand
// as in Farvardin, so stepping months never resizes the popup.
//
// `holidayFor(jy, jm, jd)` is optional and returns a holiday name or "".
// Spillover days from the neighbouring months are included and flagged, and
// are looked up too: a Nowruz sitting in the last row of Esfand still reads
// as a holiday.
function monthGrid(jy, jm, todayKey, holidayFor) {
  var firstJdn = jalaliToJdn(jy, jm, 1)
  var startJdn = firstJdn - weekdayOfJdn(firstJdn)
  var weeks = []

  for (var w = 0; w < 6; w++) {
    var days = []
    for (var d = 0; d < 7; d++) {
      var jdn = startJdn + w * 7 + d
      var jalali = jdnToJalali(jdn)
      var key = keyFor(jalali.jy, jalali.jm, jalali.jd)
      var holiday = holidayFor ? (holidayFor(jalali.jy, jalali.jm, jalali.jd) || "") : ""
      days.push({
        key: key,
        jy: jalali.jy,
        jm: jalali.jm,
        jd: jalali.jd,
        day: String(jalali.jd),
        inMonth: jalali.jy === jy && jalali.jm === jm,
        // Jome is the Iranian weekend; the grid dims it the way a wall
        // calendar sets Sunday apart.
        weekend: d === 6,
        today: key === todayKey,
        holiday: holiday,
        isHoliday: holiday !== ""
      })
    }
    weeks.push({ days: days })
  }
  return weeks
}

// node-only export; harmless inside QML, which ignores the guard.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    MONTHS: MONTHS, WEEKDAYS: WEEKDAYS, WEEKDAYS_SHORT: WEEKDAYS_SHORT,
    isLeapYear: isLeapYear, monthLength: monthLength, yearLength: yearLength,
    toJalali: toJalali, toGregorian: toGregorian, fromDate: fromDate,
    weekdayOf: weekdayOf, keyFor: keyFor, shortLabel: shortLabel,
    longLabel: longLabel, gregorianLabel: gregorianLabel,
    stepMonth: stepMonth, monthGrid: monthGrid, isSupported: isSupported,
    jalaliToJdn: jalaliToJdn, gregorianToJdn: gregorianToJdn
  }
}
