package me.guslipkin.flights.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import me.guslipkin.flights.data.Network
import me.guslipkin.flights.game.Difficulty
import me.guslipkin.flights.game.grouped
import me.guslipkin.flights.ui.GameUiState
import me.guslipkin.flights.ui.theme.FlightDeckColors

@Composable
fun HelpDialog(
    uiState: GameUiState,
    networkProvider: (Int) -> Network,
    onDismiss: () -> Unit
) {
    val custom = uiState.customRules
    val levelRows = remember(custom) {
        val standardRows = Difficulty.STANDARD.map { d ->
            Triple(
                d.label,
                d.description,
                grouped(d.puzzleCount(networkProvider))
            )
        }
        val customDesc = if (custom.fixedRoute) {
            "your route (Settings)"
        } else {
            "${custom.hopsText()}, ${custom.maxConnections} conn. (Settings)"
        }
        val customCount = if (custom.countIsExact()) {
            grouped(custom.puzzleCount(networkProvider))
        } else {
            "≤${grouped(custom.puzzleCount(networkProvider))}"
        }
        standardRows + Triple("Custom", customDesc, customCount)
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth(0.94f)
                .clip(RoundedCornerShape(14.dp))
                .background(FlightDeckColors.SurfaceCard)
                .border(1.5.dp, FlightDeckColors.AccentSkyBlue, RoundedCornerShape(14.dp))
                .padding(14.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "HOW TO PLAY — FLIGHTS",
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        color = FlightDeckColors.AccentSkyBlue
                    )
                    Text(
                        text = "the shortest way, one letter at a time",
                        fontSize = 12.sp,
                        color = FlightDeckColors.TextSecondary
                    )
                }
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(FlightDeckColors.SurfaceElevated)
                        .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(6.dp))
                        .clickable(onClick = onDismiss)
                        .padding(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = "✕ Close",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        color = FlightDeckColors.TextSecondary
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 460.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Rules
                HelpSectionTitle("Rules")
                HelpBullet("Each hop changes one letter of the code: LAX → LAS → LOS.")
                HelpBullet("A hop needs a ticket, direct or 1 connection; every leg counts toward the great-circle distance.")
                HelpBullet("Reach the destination the long way and you'll be told; go back to improve.")
                if (uiState.rules.oncePerAirport()) {
                    HelpBullet("This game uses each airport once, connections included.")
                }

                HorizontalDivider(color = FlightDeckColors.BorderSubtle)

                // Touch & Map Controls
                HelpSectionTitle("Controls")
                HelpBullet("Tap an option row (or an orange airport on the map) once to preview its hop arc on the map.")
                HelpBullet("Tap the selected option again or press Fly to fly there.")
                HelpBullet("Tap Go Back in the Route panel to undo your last hop.")
                HelpBullet("Pinch to zoom, drag to pan, double-tap to zoom in, tap Fit to re-center, or tap Full to expand the map.")
                HelpBullet("Once a game is over, tap any hop row or use Prev Hop / Next Hop to step through the route on the map.")

                HorizontalDivider(color = FlightDeckColors.BorderSubtle)

                // Difficulty Levels & Puzzle Counts
                HelpSectionTitle("Difficulty · puzzles")
                for ((name, desc, count) in levelRows) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(6.dp))
                            .background(FlightDeckColors.SurfaceElevated.copy(alpha = 0.65f))
                            .padding(horizontal = 8.dp, vertical = 5.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = name,
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp,
                                color = FlightDeckColors.TextPrimary
                            )
                            Text(
                                text = desc,
                                fontSize = 11.sp,
                                color = FlightDeckColors.TextSecondary
                            )
                        }
                        Text(
                            text = count,
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp,
                            color = FlightDeckColors.PositiveGreen
                        )
                    }
                }

                HorizontalDivider(color = FlightDeckColors.BorderSubtle)

                // Credits
                HelpSectionTitle("Credits")
                HelpBullet("Flights is an original game conceived and created by Gus Lipkin (guslipkin.me).")
                HelpBullet("Routes: English Wikipedia's airport articles (CC BY-SA 4.0).")
                HelpBullet("Airports & coordinates: OurAirports (public domain).")
                HelpBullet("Map coastlines: Natural Earth (public domain).")
                HelpBullet("Jet audio: Wikimedia Commons ('Jet airliner overhead' & InspectorJ 'Boeing flyby', CC BY 4.0).")
            }
        }
    }
}

@Composable
private fun HelpSectionTitle(title: String) {
    Text(
        text = title,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 13.sp,
        color = FlightDeckColors.AccentSkyBlue
    )
}

@Composable
private fun HelpBullet(text: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            text = "•",
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
            color = FlightDeckColors.AccentSkyBlue
        )
        Text(
            text = text,
            fontSize = 12.sp,
            color = FlightDeckColors.TextPrimary
        )
    }
}
