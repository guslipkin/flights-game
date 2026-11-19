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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
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

private data class DifficultyRowInfo(
    val difficulty: Difficulty,
    val description: String,
    val puzzleCountText: String,
    val isPlayable: Boolean
)

@Composable
fun DifficultyDialog(
    uiState: GameUiState,
    networkProvider: (Int) -> Network,
    onSelectDifficulty: (Difficulty) -> Unit,
    onConfigureCustom: () -> Unit,
    onDismiss: () -> Unit
) {
    val custom = uiState.customRules
    val rows = remember(custom) {
        val standard = Difficulty.STANDARD.map { d ->
            val count = d.puzzleCount(networkProvider)
            DifficultyRowInfo(
                difficulty = d,
                description = d.description,
                puzzleCountText = "${grouped(count)} puzzles",
                isPlayable = true
            )
        }
        val customCheck = custom.check(networkProvider)
        val customCount = customCheck.getOrDefault(0)
        val customCountText = when {
            customCheck.isFailure -> customCheck.exceptionOrNull()?.message ?: "no puzzles fit"
            custom.countIsExact() -> "${grouped(customCount)} puzzles"
            else -> "≤${grouped(customCount)} puzzles"
        }
        standard + DifficultyRowInfo(
            difficulty = Difficulty.Custom,
            description = custom.summary(),
            puzzleCountText = customCountText,
            isPlayable = customCheck.isSuccess
        )
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth(0.92f)
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
                        text = "SELECT DIFFICULTY",
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        letterSpacing = 0.8.sp,
                        color = FlightDeckColors.AccentSkyBlue
                    )
                    Text(
                        text = "Tap a level to start a new game",
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
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                for (row in rows) {
                    val isCurrent = uiState.difficulty == row.difficulty
                    val borderColor = when {
                        isCurrent -> FlightDeckColors.AccentSkyBlue
                        !row.isPlayable -> FlightDeckColors.WarningOrange.copy(alpha = 0.6f)
                        else -> FlightDeckColors.BorderSubtle
                    }
                    val bgColor = if (isCurrent) {
                        FlightDeckColors.AccentSkyBlue.copy(alpha = 0.12f)
                    } else {
                        FlightDeckColors.SurfaceElevated
                    }

                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(bgColor)
                            .border(1.dp, borderColor, RoundedCornerShape(10.dp))
                            .clickable {
                                if (row.difficulty == Difficulty.Custom && !row.isPlayable) {
                                    onConfigureCustom()
                                } else {
                                    onSelectDifficulty(row.difficulty)
                                }
                            }
                            .padding(horizontal = 12.dp, vertical = 10.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    text = row.difficulty.label,
                                    fontFamily = FontFamily.Monospace,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 14.sp,
                                    color = if (isCurrent) {
                                        FlightDeckColors.AccentSkyBlue
                                    } else {
                                        FlightDeckColors.TextPrimary
                                    }
                                )
                                if (isCurrent) {
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(4.dp))
                                            .background(FlightDeckColors.AccentSkyBlue)
                                            .padding(horizontal = 6.dp, vertical = 1.dp)
                                    ) {
                                        Text(
                                            text = "CURRENT",
                                            fontFamily = FontFamily.Monospace,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 9.sp,
                                            color = Color.Black
                                        )
                                    }
                                }
                                if (row.difficulty == Difficulty.Medium) {
                                    Text(
                                        text = "default & daily",
                                        fontFamily = FontFamily.Monospace,
                                        fontSize = 10.sp,
                                        color = FlightDeckColors.TextMuted
                                    )
                                }
                            }

                            Text(
                                text = row.puzzleCountText,
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.Bold,
                                fontSize = 11.5.sp,
                                color = if (row.isPlayable) {
                                    FlightDeckColors.PositiveGreen
                                } else {
                                    FlightDeckColors.WarningOrange
                                }
                            )
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = row.description,
                                fontSize = 12.sp,
                                color = FlightDeckColors.TextSecondary,
                                modifier = Modifier.weight(1f)
                            )

                            if (row.difficulty == Difficulty.Custom) {
                                Box(
                                    modifier = Modifier
                                        .padding(start = 8.dp)
                                        .clip(RoundedCornerShape(6.dp))
                                        .background(FlightDeckColors.SurfaceCard)
                                        .border(
                                            1.dp,
                                            FlightDeckColors.BorderAccent,
                                            RoundedCornerShape(6.dp)
                                        )
                                        .clickable(onClick = onConfigureCustom)
                                        .padding(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text(
                                        text = "Customize…",
                                        fontFamily = FontFamily.Monospace,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 11.sp,
                                        color = FlightDeckColors.AccentSkyBlue
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
