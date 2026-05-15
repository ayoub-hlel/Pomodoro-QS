pragma Singleton
import QtQuick

/**
 * Colours — Local M3 palette singleton for standalone development.
 *
 * Matches the API shape of Caelestia's qs.services.Colours exactly:
 *   Colours.palette.m3primary
 *   Colours.tPalette.m3surfaceContainerLow
 *   Colours.light
 *
 * These are sensible dark-mode defaults. When patched into the real
 * Caelestia shell at runtime, the real Colours singleton takes over
 * with dynamic wallpaper-derived colors.
 */
QtObject {
    readonly property bool light: false

    readonly property QtObject palette: QtObject {
        readonly property color m3primary:                         "#a9cae8"
        readonly property color m3onPrimary:                       "#21435c"
        readonly property color m3primaryContainer:                "#34566f"
        readonly property color m3onPrimaryContainer:              "#d4e4f8"
        readonly property color m3secondary:                       "#b7c9d9"
        readonly property color m3onSecondary:                     "#293846"
        readonly property color m3tertiary:                        "#f0bc95"
        readonly property color m3onTertiary:                      "#48290c"
        readonly property color m3error:                           "#fa746f"
        readonly property color m3onError:                         "#601410"
        readonly property color m3success:                         "#b5ccba"
        readonly property color m3onSuccess:                       "#1e3524"
        readonly property color m3background:                      "#020304"
        readonly property color m3onBackground:                    "#e0e6ee"
        readonly property color m3surface:                         "#020304"
        readonly property color m3onSurface:                       "#e0e6ee"
        readonly property color m3surfaceVariant:                  "#2a3138"
        readonly property color m3onSurfaceVariant:                "#a5acb3"
        readonly property color m3outline:                         "#70767d"
        readonly property color m3outlineVariant:                  "#42494f"
        readonly property color m3inverseSurface:                  "#e0e6ee"
        readonly property color m3inverseOnSurface:                "#30363d"
        readonly property color m3surfaceTint:                     "#a9cae8"
    }

    readonly property QtObject tPalette: QtObject {
        readonly property color m3surfaceContainerLow:             Qt.alpha(palette.m3surface, 0.95)
        readonly property color m3surfaceContainer:                Qt.alpha(palette.m3surface, 0.92)
        readonly property color m3surfaceContainerHigh:            Qt.alpha(palette.m3surface, 0.88)
        readonly property color m3surfaceContainerHighest:         Qt.alpha(palette.m3surface, 0.84)
        readonly property color m3primaryContainer:                Qt.alpha(palette.m3primaryContainer, 0.85)
    }
}
