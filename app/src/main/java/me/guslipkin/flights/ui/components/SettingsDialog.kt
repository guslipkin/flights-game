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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import me.guslipkin.flights.data.MAX_CONNECTIONS
import me.guslipkin.flights.data.Network
import me.guslipkin.flights.game.Difficulty
import me.guslipkin.flights.game.MAX_HOPS
import me.guslipkin.flights.game.MIN_HOPS
import me.guslipkin.flights.game.Rules
import me.guslipkin.flights.game.Units
import me.guslipkin.flights.game.View
import me.guslipkin.flights.game.grouped
import me.guslipkin.flights.game.parseCode
import me.guslipkin.flights.ui.GameUiState
import me.guslipkin.flights.ui.theme.FlightDeckColors
import java.util.Locale

@Composable
fun SettingsDialog(
    uiState: GameUiState,
    networkProvider: (Int) -> Network,
    onApply: (
        units: Units,
        curves: Boolean,
        haptics: Boolean,
        sound: Boolean,
        custom: Rules,
        playCustom: Boolean
    ) -> String?,
    onDismiss: () -> Unit
) {
    var units by remember { mutableStateOf(uiState.units) }
    var curves by remember { mutableStateOf(uiState.curves) }
    var haptics by remember { mutableStateOf(uiState.hapticsEnabled) }
    var sound by remember { mutableStateOf(uiState.soundEnabled) }
    var custom by remember { mutableStateOf(uiState.customRules) }
    var startText by remember { mutableStateOf(uiState.customRules.start ?: "") }
    var endText by remember { mutableStateOf(uiState.customRules.end ?: "") }
    var problem by remember { mutableStateOf<String?>(null) }

    val statusResult = remember(custom) { custom.check(networkProvider) }

    fun stepIndex(current: Int, size: Int, forward: Boolean): Int {
        return if (forward) (current + 1) % size else (current + size - 1) % size
    }

    fun stepViewPreset(forward: Boolean) {
        val all = Difficulty.STANDARD
        val currentIdx = custom.view.level()?.let { all.indexOf(it) }?.takeIf { it >= 0 }
        val nextIdx = when {
            currentIdx != null -> stepIndex(currentIdx, all.size, forward)
            forward -> 0
            else -> all.lastIndex
        }
        custom = custom.copy(view = View.of(all[nextIdx]))
        problem = null
    }

    fun stepMinHops(forward: Boolean) {
        val top = custom.maxHops ?: MAX_HOPS
        val choices = (MIN_HOPS..top).toList()
        val idx = choices.indexOf(custom.minHops).coerceAtLeast(0)
        custom = custom.copy(minHops = choices[stepIndex(idx, choices.size, forward)])
        problem = null
    }

    fun stepMaxHops(forward: Boolean) {
        val choices: List<Int?> = (custom.minHops..MAX_HOPS).map { it as Int? } + listOf(null)
        val idx = choices.indexOf(custom.maxHops).coerceAtLeast(0)
        custom = custom.copy(maxHops = choices[stepIndex(idx, choices.size, forward)])
        problem = null
    }

    Dialog(
        onDismissRequest = {
            onApply(units, curves, haptics, sound, custom, false)
        },
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
            // Modal Title
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "SETTINGS",
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    letterSpacing = 1.sp,
                    color = FlightDeckColors.AccentSkyBlue
                )
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(FlightDeckColors.SurfaceElevated)
                        .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(6.dp))
                        .clickable {
                            onApply(units, curves, haptics, sound, custom, false)
                        }
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

            Spacer(modifier = Modifier.height(8.dp))

            // Scrollable Settings Rows
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 430.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                SectionHeader("Preferences")

                StepperSettingRow(
                    label = "Units",
                    value = units.label,
                    note = "distance units (Default: nm)",
                    enabled = true,
                    onStep = { forward ->
                        val all = Units.entries
                        units = all[stepIndex(units.ordinal, all.size, forward)]
                    }
                )
                StepperSettingRow(
                    label = "Map lines",
                    value = if (curves) "Curved" else "Straight",
                    note = "the hops' shape (Default: Curved)",
                    enabled = true,
                    onStep = { curves = !curves }
                )
                StepperSettingRow(
                    label = "Haptics",
                    value = if (haptics) "On" else "Off",
                    note = "tactile feedback on hops",
                    enabled = true,
                    onStep = { haptics = !haptics }
                )
                StepperSettingRow(
                    label = "Sound",
                    value = if (sound) "On" else "Off",
                    note = "jet sound effects",
                    enabled = true,
                    onStep = { sound = !sound }
                )

                Spacer(modifier = Modifier.height(4.dp))
                HorizontalDivider(color = FlightDeckColors.BorderSubtle)
                Spacer(modifier = Modifier.height(2.dp))

                SectionHeader("Custom game")

                StepperSettingRow(
                    label = "Shows",
                    value = custom.view.label(),
                    note = "sets the 4 below as a level does",
                    enabled = true,
                    onStep = ::stepViewPreset
                )
                StepperSettingRow(
                    label = "Map",
                    value = if (custom.view.map) "On" else "Off",
                    note = "else a list of codes",
                    enabled = true,
                    indented = true,
                    onStep = {
                        custom = custom.copy(view = custom.view.copy(map = !custom.view.map))
                        problem = null
                    }
                )
                StepperSettingRow(
                    label = "Distances",
                    value = if (custom.view.distances) "On" else "Off",
                    note = "while playing",
                    enabled = true,
                    indented = true,
                    onStep = {
                        custom = custom.copy(view = custom.view.copy(distances = !custom.view.distances))
                        problem = null
                    }
                )
                StepperSettingRow(
                    label = "Connections",
                    value = if (custom.view.connections) "On" else "Off",
                    note = "where hops connect",
                    enabled = true,
                    indented = true,
                    onStep = {
                        custom = custom.copy(view = custom.view.copy(connections = !custom.view.connections))
                        problem = null
                    }
                )
                StepperSettingRow(
                    label = "How far over",
                    value = if (custom.view.amountOver) "On" else "Off",
                    note = "when you arrive the long way",
                    enabled = true,
                    indented = true,
                    onStep = {
                        custom = custom.copy(view = custom.view.copy(amountOver = !custom.view.amountOver))
                        problem = null
                    }
                )
                StepperSettingRow(
                    label = "City, country",
                    value = if (custom.showPlaces) "On" else "Off",
                    note = "beside each option",
                    enabled = true,
                    onStep = {
                        custom = custom.copy(showPlaces = !custom.showPlaces)
                        problem = null
                    }
                )
                StepperSettingRow(
                    label = "Puzzles",
                    value = if (custom.fixedRoute) "Route" else "Random",
                    note = if (custom.fixedRoute) "your start and end, any length" else "random, within the limits",
                    enabled = true,
                    onStep = {
                        custom = custom.copy(fixedRoute = !custom.fixedRoute)
                        problem = null
                    }
                )
                StepperSettingRow(
                    label = "Max connections",
                    value = custom.maxConnections.toString(),
                    note = if (!custom.fixedRoute) "per hop's ticket" else "not used for a fixed route",
                    enabled = !custom.fixedRoute,
                    onStep = { forward ->
                        val next = stepIndex(custom.maxConnections, MAX_CONNECTIONS + 1, forward)
                        custom = custom.copy(maxConnections = next)
                        problem = null
                    }
                )
                val reuseEnabled = custom.connections() > 0
                StepperSettingRow(
                    label = "Reuse connections",
                    value = if (custom.reuseConnections) "Yes" else "No",
                    note = when {
                        !reuseEnabled -> "no connections to reuse"
                        custom.reuseConnections -> "airports may repeat as connections"
                        else -> "each airport once, connections too"
                    },
                    enabled = reuseEnabled,
                    onStep = {
                        custom = custom.copy(reuseConnections = !custom.reuseConnections)
                        problem = null
                    }
                )
                StepperSettingRow(
                    label = "Min hops",
                    value = custom.minHops.toString(),
                    note = if (!custom.fixedRoute) "in the best route (3-20)" else "not used for a fixed route",
                    enabled = !custom.fixedRoute,
                    onStep = ::stepMinHops
                )
                StepperSettingRow(
                    label = "Max hops",
                    value = custom.maxHops?.toString() ?: "No limit",
                    note = if (!custom.fixedRoute) "in the best route (3-20)" else "not used for a fixed route",
                    enabled = !custom.fixedRoute,
                    onStep = ::stepMaxHops
                )

                CodeInputSettingRow(
                    label = "Start",
                    text = startText,
                    enabled = custom.fixedRoute,
                    onTextChange = { raw ->
                        val clean = raw.filter { it.isLetter() }.uppercase(Locale.US).take(3)
                        startText = clean
                        custom = custom.copy(start = parseCode(clean))
                        problem = null
                    },
                    onClearToRandom = {
                        startText = ""
                        custom = custom.copy(start = null)
                        problem = null
                    }
                )
                CodeInputSettingRow(
                    label = "End",
                    text = endText,
                    enabled = custom.fixedRoute,
                    onTextChange = { raw ->
                        val clean = raw.filter { it.isLetter() }.uppercase(Locale.US).take(3)
                        endText = clean
                        custom = custom.copy(end = parseCode(clean))
                        problem = null
                    },
                    onClearToRandom = {
                        endText = ""
                        custom = custom.copy(end = null)
                        problem = null
                    }
                )

                // Defaults Reset Row
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Defaults",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 13.sp,
                            color = FlightDeckColors.TextPrimary
                        )
                        Text(
                            text = "custom settings to defaults",
                            fontSize = 11.sp,
                            color = FlightDeckColors.TextMuted
                        )
                    }
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(FlightDeckColors.SurfaceElevated)
                            .border(1.dp, FlightDeckColors.BorderAccent, RoundedCornerShape(6.dp))
                            .clickable {
                                custom = Rules()
                                startText = ""
                                endText = ""
                                problem = null
                            }
                            .padding(horizontal = 14.dp, vertical = 6.dp)
                    ) {
                        Text(
                            text = "Reset",
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp,
                            color = FlightDeckColors.TextPrimary
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))
            HorizontalDivider(color = FlightDeckColors.BorderSubtle)
            Spacer(modifier = Modifier.height(8.dp))

            // Live Puzzle Count & Validation Status
            val activeProblem = problem
            val statusErr = statusResult.exceptionOrNull()?.message
            when {
                activeProblem != null -> {
                    Text(
                        text = activeProblem,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        color = FlightDeckColors.WarningOrange
                    )
                }
                statusErr != null -> {
                    Text(
                        text = "Can't play these settings: $statusErr.",
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        color = FlightDeckColors.WarningOrange
                    )
                }
                else -> {
                    val count = statusResult.getOrDefault(0)
                    val prefix = if (custom.countIsExact()) {
                        "Puzzles with these settings: "
                    } else {
                        "Puzzles with these settings: up to "
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = prefix,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 12.sp,
                            color = FlightDeckColors.TextSecondary
                        )
                        Text(
                            text = grouped(count),
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp,
                            color = FlightDeckColors.PositiveGreen
                        )
                    }
                }
            }

            Text(
                text = "Levels' max hops: Easy 4, Medium 6, Hard 8, Pilot none",
                fontFamily = FontFamily.Monospace,
                fontSize = 11.sp,
                color = FlightDeckColors.TextMuted,
                modifier = Modifier.padding(top = 2.dp)
            )

            Spacer(modifier = Modifier.height(10.dp))

            // Footer Action Buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(8.dp))
                        .background(FlightDeckColors.SurfaceElevated)
                        .border(1.dp, FlightDeckColors.BorderAccent, RoundedCornerShape(8.dp))
                        .clickable {
                            onApply(units, curves, haptics, sound, custom, false)
                        }
                        .padding(vertical = 10.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Save & Close",
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        color = FlightDeckColors.TextPrimary
                    )
                }

                Box(
                    modifier = Modifier
                        .weight(1.2f)
                        .clip(RoundedCornerShape(8.dp))
                        .background(
                            if (statusResult.isSuccess) {
                                FlightDeckColors.AccentSkyBlue
                            } else {
                                FlightDeckColors.SurfaceElevated
                            }
                        )
                        .border(
                            1.dp,
                            if (statusResult.isSuccess) {
                                FlightDeckColors.AccentSkyBlue
                            } else {
                                FlightDeckColors.WarningOrange
                            },
                            RoundedCornerShape(8.dp)
                        )
                        .clickable {
                            val err = onApply(units, curves, haptics, sound, custom, true)
                            if (err != null) {
                                problem = err
                            }
                        }
                        .padding(vertical = 10.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Play Custom",
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        color = if (statusResult.isSuccess) Color.Black else FlightDeckColors.WarningOrange
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 13.sp,
        color = FlightDeckColors.AccentSkyBlue,
        modifier = Modifier.padding(top = 2.dp, bottom = 2.dp)
    )
}

@Composable
private fun StepperSettingRow(
    label: String,
    value: String,
    note: String,
    enabled: Boolean,
    indented: Boolean = false,
    onStep: (forward: Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .alpha(if (enabled) 1f else 0.45f)
            .clip(RoundedCornerShape(6.dp))
            .background(FlightDeckColors.SurfaceElevated.copy(alpha = 0.6f))
            .padding(horizontal = 8.dp, vertical = 5.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(start = if (indented) 16.dp else 0.dp)
        ) {
            Text(
                text = label,
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
                color = FlightDeckColors.TextPrimary
            )
            Text(
                text = note,
                fontSize = 11.sp,
                color = FlightDeckColors.TextMuted
            )
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(FlightDeckColors.SurfaceCard)
                    .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(4.dp))
                    .clickable(enabled = enabled) { onStep(false) }
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(
                    text = "◀",
                    fontFamily = FontFamily.Monospace,
                    fontSize = 11.sp,
                    color = FlightDeckColors.AccentSkyBlue
                )
            }
            Text(
                text = value,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                fontSize = 12.sp,
                color = FlightDeckColors.TextPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.width(72.dp)
            )
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(FlightDeckColors.SurfaceCard)
                    .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(4.dp))
                    .clickable(enabled = enabled) { onStep(true) }
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(
                    text = "▶",
                    fontFamily = FontFamily.Monospace,
                    fontSize = 11.sp,
                    color = FlightDeckColors.AccentSkyBlue
                )
            }
        }
    }
}

@Composable
private fun CodeInputSettingRow(
    label: String,
    text: String,
    enabled: Boolean,
    onTextChange: (String) -> Unit,
    onClearToRandom: () -> Unit
) {
    val note = if (enabled) "type 3-letter code; ✕ clears to random" else "only for a fixed route"
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .alpha(if (enabled) 1f else 0.45f)
            .clip(RoundedCornerShape(6.dp))
            .background(FlightDeckColors.SurfaceElevated.copy(alpha = 0.6f))
            .padding(horizontal = 8.dp, vertical = 5.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
                color = FlightDeckColors.TextPrimary
            )
            Text(
                text = note,
                fontSize = 11.sp,
                color = FlightDeckColors.TextMuted
            )
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Box(
                modifier = Modifier
                    .width(76.dp)
                    .clip(RoundedCornerShape(5.dp))
                    .background(FlightDeckColors.RadarBackground)
                    .border(
                        1.dp,
                        if (text.length == 3) FlightDeckColors.AccentSkyBlue else FlightDeckColors.BorderAccent,
                        RoundedCornerShape(5.dp)
                    )
                    .padding(horizontal = 8.dp, vertical = 5.dp),
                contentAlignment = Alignment.Center
            ) {
                if (text.isEmpty()) {
                    Text(
                        text = "Random",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        color = FlightDeckColors.TextMuted
                    )
                }
                BasicTextField(
                    value = text,
                    onValueChange = { if (enabled) onTextChange(it) },
                    enabled = enabled,
                    singleLine = true,
                    textStyle = TextStyle(
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        color = FlightDeckColors.TextPrimary,
                        textAlign = TextAlign.Center
                    ),
                    cursorBrush = SolidColor(FlightDeckColors.AccentSkyBlue),
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Characters,
                        imeAction = ImeAction.Done
                    ),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            if (text.isNotEmpty() && enabled) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(FlightDeckColors.SurfaceCard)
                        .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(4.dp))
                        .clickable(onClick = onClearToRandom)
                        .padding(horizontal = 6.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = "✕",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 11.sp,
                        color = FlightDeckColors.TextSecondary
                    )
                }
            }
        }
    }
}
