// Official Iranian holidays that fall on a fixed Jalali date every year.
//
// These are safe to hardcode precisely because they are solar: they are
// defined against this calendar, so they do not drift. The lunar (Hijri
// Qamari) holidays -- Eyd-e Fetr, Ashura, Arbaeen and the rest -- move about
// eleven days earlier each Jalali year and cannot be derived from a formula
// with certainty, so they live in holidays-lunar.json instead. See the header
// of that file.
//
// Qt-free and side-effect-free, like JalaliDate.js, so it runs under node.

var FIXED_HOLIDAYS = [
  { month: 1,  day: 1,  name: "Nowruz" },
  { month: 1,  day: 2,  name: "Nowruz Holiday" },
  { month: 1,  day: 3,  name: "Nowruz Holiday" },
  { month: 1,  day: 4,  name: "Nowruz Holiday" },
  { month: 1,  day: 12, name: "Islamic Republic Day" },
  { month: 1,  day: 13, name: "Sizdah Be-dar" },
  { month: 3,  day: 14, name: "Demise of Imam Khomeini" },
  { month: 3,  day: 15, name: "15 Khordad Uprising" },
  { month: 11, day: 22, name: "Islamic Revolution Victory" },
  { month: 12, day: 29, name: "Oil Industry Nationalization Day" }
]

// "1-13" -> "Sizdah Be-dar". Built once; the grid asks 42 times per redraw.
var FIXED_BY_KEY = (function () {
  var index = {}
  for (var i = 0; i < FIXED_HOLIDAYS.length; i++) {
    var entry = FIXED_HOLIDAYS[i]
    index[entry.month + "-" + entry.day] = entry.name
  }
  return index
})()

function fixedHolidayFor(jm, jd) {
  return FIXED_BY_KEY[jm + "-" + jd] || ""
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { FIXED_HOLIDAYS: FIXED_HOLIDAYS, fixedHolidayFor: fixedHolidayFor }
}
