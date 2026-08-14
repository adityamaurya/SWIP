package `in`.swip.app

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

/**
 * `F-115` — SWIP from anywhere, without an overlay.
 *
 * ## What was asked for, and what this is instead
 *
 * The reference was the floating bubble that hovers over other apps — tap it,
 * it expands, it offers a saving. That is a `SYSTEM_ALERT_WINDOW` overlay, and
 * it is the single most invasive permission Android grants: an app holding it
 * can draw on top of your bank, and Play reviews it accordingly. For a category
 * reader it is not a reasonable trade, and it is the kind of thing that gets a
 * first app rejected.
 *
 * A **Quick Settings tile** is the same gesture with none of that. Swipe down
 * from anywhere in Android — inside a merchant's checkout, inside a browser,
 * on the lock screen — and SWIP is one tap away in the panel the user already
 * opens twenty times a day. No permission at all: the user adds the tile
 * themselves, which means it can never be there uninvited.
 *
 * The trade is honest and worth stating: the tile does not *float over* the
 * checkout the way the reference does. It is one swipe further away. In
 * exchange SWIP asks for nothing, draws over nothing, and cannot be mistaken
 * for spyware.
 *
 * ## The subtitle
 *
 * On Android 10+ a tile carries a second line. It is used here for the one
 * sentence that explains the whole product, because the Quick Settings panel is
 * the one place a person meets SWIP without having gone looking for it.
 */
@RequiresApi(Build.VERSION_CODES.N)
class SwipTile : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            state = Tile.STATE_INACTIVE
            label = "Scan a shop code"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                subtitle = "Know the category first"
            }
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()

        val launch = Intent(this, MainActivity::class.java).apply {
            // The tile is pressed from outside the app, so the activity needs
            // its own task. SINGLE_TOP keeps a running SWIP from being stacked
            // on top of itself when the tile is used twice.
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            // Read by MainActivity so it can open straight into the scanner
            // rather than the dashboard: a tile press is a deliberate "I am
            // looking at a code right now".
            putExtra(EXTRA_OPEN_SCANNER, true)
        }

        // Android 14 forbids starting an activity from a tile with the old
        // startActivityAndCollapse(Intent) overload - it throws
        // UnsupportedOperationException. The PendingIntent form is the
        // replacement, and the old one is still required below API 34.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(
                    this,
                    0,
                    launch,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            )
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(launch)
        }
    }

    companion object {
        const val EXTRA_OPEN_SCANNER = "in.swip.app.OPEN_SCANNER"
    }
}
