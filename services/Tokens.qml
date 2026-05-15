pragma Singleton
import QtQuick
QtObject {
    property var padding: ({ smaller: 2, small: 4, medium: 8, normal: 12, large: 16 })
    property var font: ({ size: { small: 10, normal: 12, large: 14, title: 18 }, family: 'sans-serif', mono: 'monospace' })
    property var rounding: ({ small: 2, normal: 4, large: 8, full: 99 })
}
