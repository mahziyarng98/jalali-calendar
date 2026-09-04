import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "JalaliDate.js" as Jalali
import "holidays-fixed.js" as FixedHolidays

// The Jalali calendar panel: a month grid on the Iranian week, Shanbe first.
//
// It is an instrument, not a picker. Today is marked with a thin accent ring
// rather than a filled badge; official holidays are marked with a red numeral
// AND a dot, so a theme whose red is not actually red still signals them; and
// the only thing that animates is the month turning over, which is the one
// place motion carries meaning here.
//
// BarWidget.qml owns the bar label and hands this panel the button to anchor
// against.
Panel {
  id: root
  moduleName: "io.github.mahziyarng98.jalali-calendar"
  ipcTarget: "jalali-calendar"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget in its slot, not this nested panel, so the
  // popout coordinator has to be given that widget as this panel's identity.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- Today. SystemClock keeps this honest across midnight so the ring
  //      rolls over without the panel being reopened.
  property date today: new Date()
  readonly property var todayDate: Jalali.fromDate(today)
  readonly property string todayKey: Jalali.keyFor(todayDate.jy, todayDate.jm, todayDate.jd)

  // ---- The month on screen, and the month it is on its way to. The two are
  //      only ever apart for the ~180ms of a page turn; keeping the
  //      destination separate is what lets a second click land during the
  //      first turn without losing an update.
  property int viewYear: todayDate.jy
  property int viewMonth: todayDate.jm
  property int pendingYear: todayDate.jy
  property int pendingMonth: todayDate.jm
  property int slideDirection: 1

  readonly property bool viewingCurrentMonth: pendingYear === todayDate.jy && pendingMonth === todayDate.jm

  // ---- Day cursor. Hidden until the keyboard or a click asks for it, so the
  //      grid opens as a read-out and only becomes navigable on demand.
  property var cursorDate: null
  property var hoverDate: null

  // What the rail under the grid is describing: whatever is under the
  // pointer, else the cursor, else today.
  readonly property var detailDate: hoverDate || cursorDate || todayDate

  // ---- Colour roles. Nothing here is a hex except the one reserved red
  //      below; everything else is the live Omarchy theme, so the panel
  //      re-skins with `omarchy theme set`.
  readonly property color ink: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  // Alpha rather than Qt.darker so these stay legible on a light theme too,
  // where darkening a near-black foreground does nothing.
  readonly property color muted: Util.alpha(ink, 0.62)
  readonly property color faint: Util.alpha(ink, 0.34)
  readonly property color accentInk: Style.selectedStateColor(ink, Color.accent, Color.urgent)
  readonly property color ringColor: Style.normalBorderFor(ink, Color.accent, Color.urgent)

  // A holiday marker has to read as a signal. Most themes carry a real red in
  // `urgent` (colors.toml `red`/`color1`) and using it keeps the panel in the
  // theme's own voice -- but monochrome themes set that key to a grey, which
  // would silently turn the one semantic colour in this panel into more text.
  // When the theme's red has no chroma to speak of, fall back to a single
  // reserved red used for nothing else. The dot under the numeral means the
  // signal survives either way.
  readonly property bool themeHasRed: Color.urgent.hsvSaturation >= 0.25
  readonly property color holidayInk: themeHasRed ? Color.urgent : "#e03131"

  readonly property int cellWidth: Style.space(44)
  readonly property int cellHeight: Style.space(34)
  readonly property int cellSpacing: Style.space(2)

  // ---- Lunar holiday table, loaded from disk so it can be corrected without
  //      touching code. Bumping the revision is what re-runs the grid binding
  //      when the file changes on disk.
  property var lunarByKey: ({})
  property var lunarYears: ({})
  property int lunarRevision: 0

  readonly property bool lunarYearMissing: lunarYears[String(viewYear)] !== true

  function applyLunar(raw) {
    var byKey = {}
    var years = {}
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      var table = parsed.years || {}
      for (var year in table) {
        var entries = table[year]
        if (!entries || !Array.isArray(entries)) continue   // null means "not filled in yet"
        years[String(year)] = true
        for (var i = 0; i < entries.length; i++) {
          var entry = entries[i]
          if (!entry || !entry.month || !entry.day || !entry.name) continue
          byKey[Jalali.keyFor(Number(year), Number(entry.month), Number(entry.day))] = String(entry.name)
        }
      }
    } catch (e) {
      console.warn("jalali-calendar: could not read holidays-lunar.json: " + e)
    }
    root.lunarByKey = byKey
    root.lunarYears = years
    root.lunarRevision++
  }

  // A day can carry both a solar and a lunar occasion -- 14 Khordad is the
  // demise of Imam Khomeini every year, and in some years Eyd-e Ghadir lands
  // on it too -- so both are kept.
  function holidayFor(jy, jm, jd) {
    var names = []
    var fixed = FixedHolidays.fixedHolidayFor(jm, jd)
    if (fixed !== "") names.push(fixed)
    var lunar = root.lunarByKey[Jalali.keyFor(jy, jm, jd)]
    if (lunar) names.push(lunar)
    return names.join(" · ")
  }

  readonly property var weeks: {
    root.lunarRevision   // reactive dependency: rebuild when the table reloads
    return Jalali.monthGrid(root.viewYear, root.viewMonth, root.todayKey, root.holidayFor)
  }

  // ---- Panel lifecycle -----------------------------------------------------

  function open() {
    refresh()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.hoverDate = null
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Summoning by hotkey moves no pointer, so a hover the bar was still
  // holding must not keep the center indicators revealed behind the panel.
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    root.today = new Date()
    root.cursorDate = null
    root.hoverDate = null
    root.goToToday()
  }

  // ---- Month navigation ----------------------------------------------------

  function goToMonth(jy, jm, direction) {
    if (!Jalali.isSupported(jy)) return
    if (jy === root.pendingYear && jm === root.pendingMonth) return

    // Commit whatever the in-flight turn was heading for before starting a
    // new one, so a fast second click cannot drop a month.
    if (pageTurn.running) {
      pageTurn.stop()
      root.viewYear = root.pendingYear
      root.viewMonth = root.pendingMonth
    }

    root.pendingYear = jy
    root.pendingMonth = jm
    root.slideDirection = direction

    if (!root.opened) {
      root.viewYear = jy
      root.viewMonth = jm
      return
    }
    pageTurn.restart()
  }

  function moveMonth(delta) {
    var next = Jalali.stepMonth(root.pendingYear, root.pendingMonth, delta)
    goToMonth(next.jy, next.jm, delta >= 0 ? 1 : -1)
  }

  function moveYear(delta) {
    moveMonth(delta * 12)
  }

  function goToToday() {
    var behind = root.pendingYear * 12 + root.pendingMonth < root.todayDate.jy * 12 + root.todayDate.jm
    goToMonth(root.todayDate.jy, root.todayDate.jm, behind ? 1 : -1)
  }

  // ---- Day cursor ----------------------------------------------------------

  function selectDay(date) {
    root.cursorDate = { jy: date.jy, jm: date.jm, jd: date.jd }
    if (date.jy !== root.pendingYear || date.jm !== root.pendingMonth) {
      var forward = date.jy * 12 + date.jm > root.pendingYear * 12 + root.pendingMonth
      goToMonth(date.jy, date.jm, forward ? 1 : -1)
    }
  }

  // Arrow keys walk days, not months: the cursor crossing a month edge is
  // what turns the page, the same way it would on paper.
  function moveCursor(days) {
    var from = root.cursorDate || root.todayDate
    var moved = Jalali.jdnToJalali(Jalali.jalaliToJdn(from.jy, from.jm, from.jd) + days)
    if (!Jalali.isSupported(moved.jy)) return
    selectDay(moved)
  }

  function describeHoliday(date) {
    return root.holidayFor(date.jy, date.jm, date.jd)
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      var next = Jalali.fromDate(clock.date)
      if (Jalali.keyFor(next.jy, next.jm, next.jd) === root.todayKey) return
      var followToday = root.viewingCurrentMonth
      root.today = clock.date
      if (followToday) root.goToToday()
    }
  }

  FileView {
    id: lunarFile
    path: decodeURIComponent(String(Qt.resolvedUrl("holidays-lunar.json")).replace(/^file:\/\//, ""))
    watchChanges: true
    printErrors: false
    onLoaded: root.applyLunar(lunarFile.text())
    onLoadFailed: root.applyLunar("")
  }

  // The one motion moment: a directional slide and crossfade as the month
  // turns over, about as long as a page takes to settle. Everything else in
  // this panel moves only enough to acknowledge a pointer.
  SequentialAnimation {
    id: pageTurn

    ParallelAnimation {
      NumberAnimation { target: gridShifter; property: "opacity"; to: 0; duration: 60; easing.type: Easing.OutCubic }
      NumberAnimation { target: gridShifter; property: "x"; to: -root.slideDirection * Style.space(20); duration: 60; easing.type: Easing.OutCubic }
    }

    ScriptAction {
      script: {
        root.viewYear = root.pendingYear
        root.viewMonth = root.pendingMonth
        gridShifter.x = root.slideDirection * Style.space(20)
      }
    }

    ParallelAnimation {
      NumberAnimation { target: gridShifter; property: "opacity"; to: 1; duration: 120; easing.type: Easing.OutCubic }
      NumberAnimation { target: gridShifter; property: "x"; to: 0; duration: 120; easing.type: Easing.OutCubic }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    // fittedContentWidth takes a card width, not a content width, so the
    // padding and border have to be added on -- otherwise the grid runs to
    // the card's edge and the chevrons sit on the border.
    contentWidth: panel.fittedContentWidth(calendarColumn.implicitWidth
      + panel.padding * 2 + Border.left(panel.borderSpec) + Border.right(panel.borderSpec))
    contentHeight: panel.fittedContentHeight(calendarColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveCursor(dx)
        if (dy !== 0) root.moveCursor(dy * 7)
      }
      onActivateRequested: root.goToToday()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "[") root.moveMonth(-1)
        else if (t === "]") root.moveMonth(1)
        else if (t === "{") root.moveYear(-1)
        else if (t === "}") root.moveYear(1)
        else if (t === "t" || t === "T") root.goToToday()
      }

      Column {
        id: calendarColumn
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(10)

        // ---- Hero: today in full Finglish. Once the view has stepped away
        //      it is also the way back -- clicking the date you are looking
        //      for beats hunting for a control.
        Item {
          width: gridColumn.width
          height: heroText.implicitHeight

          Text {
            id: heroText
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Jalali.longLabel(root.todayDate.jy, root.todayDate.jm, root.todayDate.jd)
            color: heroMouse.containsMouse ? root.accentInk : root.ink
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.title
            font.bold: true

            Behavior on color { ColorAnimation { duration: 90 } }
          }

          MouseArea {
            id: heroMouse
            x: heroText.x
            y: heroText.y
            width: heroText.width
            height: heroText.height
            enabled: !root.viewingCurrentMonth
            hoverEnabled: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goToToday()

            PanelToolTip {
              visible: heroMouse.containsMouse
              text: "Back to today"
              fontFamily: root.contentFontFamily
            }
          }
        }

        // ---- Month rail: chevrons on the grid's outer bounds, the label
        //      centred and fixed-width so it holds still between "Tir" and
        //      "Ordibehesht".
        Item {
          width: gridColumn.width
          height: monthLabel.implicitHeight + Style.space(10)

          Text {
            id: monthLabel
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(170)
            horizontalAlignment: Text.AlignHCenter
            text: Jalali.monthName(root.pendingMonth) + " " + root.pendingYear
            color: root.ink
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.subtitle
          }

          PanelActionButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰅁"
            tooltipText: "Previous month"
            foreground: root.ink
            fontFamily: root.contentFontFamily
            onClicked: root.moveMonth(-1)
          }

          PanelActionButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰅂"
            tooltipText: "Next month"
            foreground: root.ink
            fontFamily: root.contentFontFamily
            onClicked: root.moveMonth(1)
          }
        }

        // ---- Today. Kept in the layout at all times so the grid below never
        //      shifts; inert and dimmed while it has nothing to do.
        Item {
          width: gridColumn.width
          height: todayButton.height

          Rectangle {
            id: todayButton
            anchors.horizontalCenter: parent.horizontalCenter
            width: todayLabel.implicitWidth + Style.spacing.controlPaddingX * 2
            height: todayLabel.implicitHeight + Style.spacing.controlPaddingY * 2
            radius: Style.cornerRadius
            color: todayMouse.containsMouse && !root.viewingCurrentMonth
              ? Style.hoverFillFor(root.ink, Color.accent, Color.urgent)
              : "transparent"
            border.width: Style.spacing.hairline
            border.color: root.viewingCurrentMonth ? Util.alpha(root.ink, 0.12) : root.ringColor
            opacity: root.viewingCurrentMonth ? 0.45 : 1

            Behavior on color { ColorAnimation { duration: 90 } }
            Behavior on opacity { NumberAnimation { duration: 90 } }

            Text {
              id: todayLabel
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: "Today"
              color: todayMouse.containsMouse && !root.viewingCurrentMonth ? root.accentInk : root.muted
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              id: todayMouse
              anchors.fill: parent
              enabled: !root.viewingCurrentMonth
              hoverEnabled: enabled
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goToToday()
            }
          }
        }

        // ---- The grid itself, wrapped so the page turn can move all of it
        //      as one sheet.
        Item {
          width: gridColumn.width
          height: gridColumn.height
          clip: true

          WheelHandler {
            onWheel: function(event) {
              // Horizontal wheels and touchpad side-scrolls report y === 0;
              // without this they would every one read as "next month".
              if (event.angleDelta.y === 0) return
              root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
            }
          }

          Item {
            id: gridShifter
            width: parent.width
            height: parent.height

            Column {
              id: gridColumn
              spacing: Style.space(3)

              // Weekday rule. Smaller than the numbers under it and lightly
              // letter-spaced, because it is structure rather than a label.
              Row {
                spacing: root.cellSpacing

                Repeater {
                  model: Jalali.WEEKDAYS_SHORT

                  Text {
                    textFormat: Text.PlainText
                    required property var modelData
                    required property int index
                    width: root.cellWidth
                    height: Style.space(18)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    // Jome is the Iranian weekend; the column head says so
                    // before any number does.
                    color: index === 6 ? root.faint : root.muted
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                  }
                }
              }

              Repeater {
                model: root.weeks

                Row {
                  required property var modelData
                  spacing: root.cellSpacing

                  Repeater {
                    model: modelData.days

                    Item {
                      id: cell
                      required property var modelData

                      width: root.cellWidth
                      height: root.cellHeight

                      readonly property bool isCursor: root.cursorDate !== null
                        && modelData.key === Jalali.keyFor(root.cursorDate.jy, root.cursorDate.jm, root.cursorDate.jd)

                      // Hover fill. Flat, thin, and gone in under a tenth of
                      // a second -- an acknowledgement, not an animation.
                      Rectangle {
                        anchors.fill: parent
                        radius: Style.cornerRadius
                        color: dayMouse.containsMouse
                          ? Style.hoverFillFor(root.ink, Color.accent, Color.urgent)
                          : "transparent"

                        Behavior on color { ColorAnimation { duration: 90 } }
                      }

                      // Keyboard/selection focus. Distinct from the today
                      // ring so the two can sit on the same cell.
                      Rectangle {
                        visible: cell.isCursor
                        anchors.fill: parent
                        radius: Style.cornerRadius
                        color: "transparent"
                        border.width: Style.spacing.hairline
                        border.color: Style.focusBorderFor(root.ink, Color.accent, Color.urgent)
                      }

                      // Today: a thin ring, never a filled badge, breathing
                      // slowly enough that you notice it only once.
                      Rectangle {
                        id: todayRing
                        visible: cell.modelData.today
                        anchors.centerIn: parent
                        width: parent.width - Style.space(8)
                        height: parent.height - Style.space(8)
                        radius: Style.cornerRadius
                        color: "transparent"
                        border.width: Style.spacing.hairline
                        border.color: root.ringColor
                        transformOrigin: Item.Center

                        SequentialAnimation on scale {
                          running: todayRing.visible && root.opened
                          loops: Animation.Infinite
                          NumberAnimation { from: 1.0; to: 1.04; duration: 1250; easing.type: Easing.InOutSine }
                          NumberAnimation { from: 1.04; to: 1.0; duration: 1250; easing.type: Easing.InOutSine }
                        }
                      }

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -Style.space(2)
                        text: cell.modelData.day
                        // Priority: a day outside the month recedes, a
                        // holiday is red, today is never dimmed even when it
                        // falls on a Jome, and Jome is otherwise quieter than
                        // the working week.
                        color: !cell.modelData.inMonth
                          ? root.faint
                          : (cell.modelData.isHoliday
                            ? root.holidayInk
                            : (cell.modelData.today || !cell.modelData.weekend ? root.ink : root.muted))
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        // Tabular figures, so every column of the grid lines
                        // up even under a proportional theme font.
                        font.features: ({ "tnum": 1 })
                      }

                      // Holidays are never signalled by colour alone: some
                      // themes have no red to give.
                      Rectangle {
                        visible: cell.modelData.isHoliday
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Style.space(6)
                        width: Style.space(3)
                        height: width
                        radius: width / 2
                        color: cell.modelData.inMonth ? root.holidayInk : Util.alpha(root.holidayInk, 0.4)
                      }

                      MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoverDate = {
                          key: cell.modelData.key,
                          jy: cell.modelData.jy,
                          jm: cell.modelData.jm,
                          jd: cell.modelData.jd
                        }
                        // Matched on the full key, not the day number: a
                        // spillover 1 and an in-month 1 are both "1", and
                        // leaving one must not clear the other's reading.
                        onExited: if (root.hoverDate && root.hoverDate.key === cell.modelData.key) root.hoverDate = null
                        onClicked: root.selectDay(cell.modelData)

                        // Only holidays get a tooltip. Forty-two of them
                        // chasing the pointer would be noise; one that names
                        // the occasion you just landed on is the answer to
                        // why the number is red.
                        PanelToolTip {
                          visible: dayMouse.containsMouse && cell.modelData.holiday !== ""
                          text: cell.modelData.holiday
                          fontFamily: root.contentFontFamily
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // ---- Detail rail. One steady line under the grid rather than a
        //      tooltip chasing the pointer across 42 cells: the Gregorian
        //      equivalent of whatever day is being pointed at, and the
        //      occasion if it has one.
        Item {
          width: gridColumn.width
          height: detailColumn.implicitHeight

          Column {
            id: detailColumn
            width: parent.width
            spacing: Style.space(3)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: {
                var d = root.detailDate
                var g = Jalali.toGregorian(d.jy, d.jm, d.jd)
                return d.jd + " " + Jalali.monthName(d.jm) + " " + d.jy
                  + "  =  " + Jalali.gregorianLabel(g.gy, g.gm, g.gd)
              }
              color: root.muted
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              visible: text !== ""
              text: root.describeHoliday(root.detailDate)
              color: root.holidayInk
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }

            // Says so out loud when a year's lunar occasions have not been
            // filled in, so an empty Moharram reads as missing data rather
            // than as a month with nothing in it.
            Text {
              textFormat: Text.PlainText
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              visible: root.lunarYearMissing
              text: "Lunar holidays for " + root.viewYear + " not in holidays-lunar.json"
              color: root.faint
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
