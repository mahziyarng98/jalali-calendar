import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "JalaliDate.js" as Jalali

// Jalali (Solar Hijri) date and a 24-hour clock for the bar, and the host for
// the calendar panel.
//
// The label is deliberately terse -- day number, Finglish month and the time,
// "13 Shahrivar  14:32" -- because the bar is a glance, not a read.
// Everything else (weekday, year, the month grid, holidays, the Gregorian
// equivalent) is one click away in the panel.
//
// The date is the widget's identity and the clock is an addendum to it, so
// the time is set a step smaller and dimmed rather than given equal weight.
//
// Structure follows the first-party clock widget: the bar mounts this item,
// this item owns a Loader holding Panel.qml, and the panel's open/close
// contract is forwarded from here so the bar's single-popout coordinator sees
// one identity per slot.
BarWidget {
  id: root
  moduleName: "io.github.mahziyarng98.jalali-calendar"

  // Recomputed rather than cached across midnight; SystemClock below is what
  // makes that happen without the panel being opened.
  property date now: new Date()
  readonly property var jalali: Jalali.fromDate(now)

  readonly property bool showYear: setting("showYear", false) === true
  readonly property bool showWeekday: setting("showWeekday", false) === true

  readonly property string displayText: {
    var label = Jalali.shortLabel(jalali.jy, jalali.jm, jalali.jd)
    if (root.showWeekday) label = Jalali.weekdayName(Jalali.weekdayOf(jalali.jy, jalali.jm, jalali.jd)) + ", " + label
    if (root.showYear) label = label + " " + jalali.jy
    return label
  }

  // 24-hour, no meridiem, from the same `now` the date is read off -- so the
  // two can never disagree about which minute it is.
  readonly property string timeText: Jalali.timeLabel(now)

  // The full date the bar label leaves out, for the hover tooltip.
  readonly property string fullText: Jalali.longLabel(jalali.jy, jalali.jm, jalali.jd)

  // Vertical bars get one line per field rather than a rotated label: the day
  // and month, then the hour over the minute the way a vertical clock is
  // read. `secondary` is what keeps the two clock lines reading as an
  // addendum rather than as two more date fields.
  readonly property var verticalLines: [
    { text: String(jalali.jd), secondary: false },
    { text: Jalali.MONTHS[jalali.jm - 1].slice(0, 3), secondary: false },
    { text: Jalali.hourLabel(now), secondary: true },
    { text: Jalali.minuteLabel(now), secondary: true }
  ]

  function refresh() {
    root.now = new Date()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  // ---- Panel contract. Bar.findPanelWidget requires open/close/opened on
  //      the bar-widget root, so these forward rather than living on Panel.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity when the user clicks straight from one bar panel to another.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  // The open-panel dot under the pill spans the text, not the padded slot.
  // The label is painted by labelRow rather than by the button's own Text, so
  // the width comes from the row.
  readonly property real openPanelIndicatorWidth: root.vertical ? 0 : labelRow.width
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  // Minute precision is enough for both jobs this clock has -- catching the
  // day rollover and turning the minute on the label -- and costs one wake a
  // minute rather than a poll loop. Nothing here shows seconds, so anything
  // finer would be wakes spent painting the same two digits. It ticks on the
  // widget, not the panel, so the bar clock is live whether or not the panel
  // has ever been opened; the panel keeps its own for the same reason.
  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.now = clock.date
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "jalali-calendar"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.vertical ? root.fullText : ""
    // The label is two pieces at two sizes, so it is painted here rather than
    // by the button's own single-font Text.
    labelVisible: false
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : root.displayText !== ""
    fixedWidth: root.vertical ? -1 : Math.round(labelRow.implicitWidth + button.scaledHorizontalMargin * 2)
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) { root.togglePanel() }

    // A horizontal bar is one text line tall -- 26px at the default size --
    // so date and time sit side by side. Stacking them would halve both.
    Row {
      id: labelRow
      visible: !root.vertical
      anchors.centerIn: parent
      spacing: Style.space(7)

      Text {
        id: dateLabel
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: root.displayText
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering
      }

      Text {
        textFormat: Text.PlainText
        // Baselines, not centres: the two sizes have to sit on the same line
        // for the pair to read as one label.
        anchors.baseline: dateLabel.baseline
        text: root.timeText
        color: Util.alpha(button.foreground, 0.72)
        font.family: button.fontFamily
        font.pixelSize: Math.max(1, Math.round(button.fontSize * 0.88))
        // Tabular figures, so the widget does not change width -- and shove
        // the rest of the bar section sideways -- as the minute turns over.
        font.features: ({ "tnum": 1 })
        renderType: Text.NativeRendering
      }
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property var modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData.text
          fontFamily: button.fontFamily
          fontSize: modelData.secondary
            ? button.fontSize * 0.8
            : (modelData.text.length > 2 ? button.fontSize * 0.85 : button.fontSize)
          color: modelData.secondary ? Util.alpha(button.foreground, 0.72) : button.foreground
        }
      }
    }
  }
}
