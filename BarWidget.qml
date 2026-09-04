import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "JalaliDate.js" as Jalali

// Jalali (Solar Hijri) date for the bar, and the host for the calendar panel.
//
// The label is deliberately terse -- day number and Finglish month, "13
// Shahrivar" -- because the bar is a glance, not a read. Everything else
// (weekday, year, the month grid, holidays, the Gregorian equivalent) is one
// click away in the panel.
//
// Structure follows the first-party clock widget: the bar mounts this item,
// this item owns a Loader holding Panel.qml, and the panel's open/close
// contract is forwarded from here so the bar's single-popout coordinator sees
// one identity per slot.
BarWidget {
  id: root
  moduleName: "local.jalali-calendar"

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

  // The full date the bar label leaves out, for the hover tooltip.
  readonly property string fullText: Jalali.longLabel(jalali.jy, jalali.jm, jalali.jd)

  // Vertical bars get one line per field rather than a rotated label.
  readonly property var verticalLines: [String(jalali.jd), Jalali.MONTHS[jalali.jm - 1].slice(0, 3)]

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
  readonly property real openPanelIndicatorWidth: button.labelWidth
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

  // Minute precision is enough to catch the day rollover, and costs one wake
  // a minute rather than a poll loop. The panel keeps its own clock for the
  // same reason.
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
    text: root.vertical ? "" : root.displayText
    tooltipText: root.vertical ? root.fullText : ""
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) { root.togglePanel() }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 2 ? button.fontSize * 0.85 : button.fontSize
          color: button.foreground
        }
      }
    }
  }
}
