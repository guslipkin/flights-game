package me.guslipkin.flights.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import me.guslipkin.flights.data.Network
import me.guslipkin.flights.game.FlightOption
import me.guslipkin.flights.game.Status
import me.guslipkin.flights.game.shortPlace
import me.guslipkin.flights.ui.GameUiState
import me.guslipkin.flights.ui.theme.FlightDeckColors

/**
 * Formats a 3-letter airport code with its changed letter (0..2) highlighted in bold Orange,
 * plus an optional `★` star for the destination airport.
 */
fun styledAirportCode(
    code: String,
    changedIndex: Int?,
    baseColor: Color,
    isDestination: Boolean = false
): AnnotatedString {
    return buildAnnotatedString {
        for (i in code.indices) {
            val isChanged = changedIndex == i
            withStyle(
                SpanStyle(
                    color = if (isChanged) FlightDeckColors.WarningOrange else baseColor,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace
                )
            ) {
                append(code[i])
            }
        }
        if (isDestination) {
            withStyle(
                SpanStyle(
                    color = FlightDeckColors.DestinationPurple,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace
                )
            ) {
                append("★")
            }
        }
    }
}

@Composable
fun OptionsPanel(
    uiState: GameUiState,
    network: Network,
    onOptionTapped: (Int) -> Unit,
    onFlySelected: () -> Unit,
    onGoBack: () -> Unit,
    onNewGame: () -> Unit,
    modifier: Modifier = Modifier
) {
    val listState = rememberLazyListState()
    val options = uiState.options

    LaunchedEffect(uiState.currentAirport, uiState.selectedOptionIndex) {
        val sel = uiState.selectedOptionIndex
        if (sel != null && sel in options.indices) {
            val visibleIndices = listState.layoutInfo.visibleItemsInfo.map { it.index }
            if (sel !in visibleIndices) {
                listState.animateScrollToItem(sel)
            }
        }
    }

    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(FlightDeckColors.SurfaceCard)
            .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(12.dp))
            .padding(horizontal = 10.dp, vertical = 8.dp)
    ) {
        // Panel Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "OPTIONS (${options.size})",
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                fontSize = 12.sp,
                letterSpacing = 0.8.sp,
                color = FlightDeckColors.AccentSkyBlue
            )
            if (options.isNotEmpty()) {
                Text(
                    text = "Tap to preview · Tap again or Fly",
                    fontSize = 11.sp,
                    color = FlightDeckColors.TextMuted
                )
            }
        }

        if (options.isEmpty()) {
            val emptyText = when {
                uiState.status == Status.Playing && uiState.atDestination ->
                    "You're at the destination by a longer route. Tap Go Back to try another way."
                uiState.status == Status.Playing ->
                    "No tickets from here to an airport not already on your route. Tap Go Back."
                else ->
                    "The game is over. Start a New Game or Daily Challenge to play again."
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text(
                        text = emptyText,
                        fontSize = 13.sp,
                        color = FlightDeckColors.TextSecondary
                    )
                    if (uiState.status == Status.Playing && uiState.hops > 0) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(FlightDeckColors.SurfaceElevated)
                                .border(1.dp, FlightDeckColors.WarningOrange, RoundedCornerShape(8.dp))
                                .clickable(onClick = onGoBack)
                                .padding(horizontal = 16.dp, vertical = 8.dp)
                        ) {
                            Text(
                                text = "← Go Back",
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp,
                                color = FlightDeckColors.WarningOrange
                            )
                        }
                    } else if (uiState.status != Status.Playing) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(FlightDeckColors.AccentSkyBlue.copy(alpha = 0.16f))
                                .border(1.dp, FlightDeckColors.AccentSkyBlue, RoundedCornerShape(8.dp))
                                .clickable(onClick = onNewGame)
                                .padding(horizontal = 16.dp, vertical = 8.dp)
                        ) {
                            Text(
                                text = "New Game",
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp,
                                color = FlightDeckColors.AccentSkyBlue
                            )
                        }
                    }
                }
            }
        } else {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 1.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                itemsIndexed(options, key = { _, opt -> opt.code }) { index, option ->
                    OptionRow(
                        option = option,
                        isSelected = index == uiState.selectedOptionIndex,
                        isDestination = option.airport == uiState.destinationAirport,
                        showDistances = uiState.rules.showsDistances(),
                        showPlaces = uiState.rules.showPlaces,
                        showVia = uiState.rules.showsConnections(),
                        placeText = shortPlace(network.place(option.airport)),
                        formattedDistance = uiState.units.format(option.distance),
                        onRowClick = { onOptionTapped(index) },
                        onFlyClick = onFlySelected
                    )
                }
            }
        }
    }
}

@Composable
private fun OptionRow(
    option: FlightOption,
    isSelected: Boolean,
    isDestination: Boolean,
    showDistances: Boolean,
    showPlaces: Boolean,
    showVia: Boolean,
    placeText: String,
    formattedDistance: String,
    onRowClick: () -> Unit,
    onFlyClick: () -> Unit
) {
    val bgColor = if (isSelected) FlightDeckColors.SelectedRowBg else FlightDeckColors.SurfaceElevated
    val borderColor = when {
        isSelected -> FlightDeckColors.SelectedRowBorder
        isDestination -> FlightDeckColors.DestinationPurple.copy(alpha = 0.55f)
        else -> FlightDeckColors.BorderSubtle
    }
    val baseCodeColor = if (isDestination) {
        FlightDeckColors.DestinationPurple
    } else {
        FlightDeckColors.TextPrimary
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(bgColor)
            .border(1.dp, borderColor, RoundedCornerShape(6.dp))
            .clickable(onClick = onRowClick)
            .padding(horizontal = 8.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = if (isSelected) "> " else "  ",
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            fontSize = 13.sp,
            color = FlightDeckColors.WarningOrange
        )

        Text(
            text = styledAirportCode(
                code = option.code,
                changedIndex = option.changed,
                baseColor = baseCodeColor,
                isDestination = isDestination
            ),
            fontSize = 14.sp,
            modifier = Modifier.width(42.dp)
        )

        if (showDistances) {
            Text(
                text = formattedDistance,
                fontFamily = FontFamily.Monospace,
                fontSize = 11.5.sp,
                color = FlightDeckColors.TextSecondary,
                maxLines = 1,
                modifier = Modifier.padding(end = 8.dp)
            )
        }

        if (showPlaces && placeText.isNotEmpty()) {
            Text(
                text = placeText,
                fontSize = 12.5.sp,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                color = FlightDeckColors.TextPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .weight(1f)
                    .padding(end = 6.dp)
            )
        } else {
            Spacer(modifier = Modifier.weight(1f))
        }

        if (showVia) {
            val viaLabel = if (option.via.isEmpty()) {
                "direct"
            } else {
                "via ${option.via.joinToString(", ")}"
            }
            Text(
                text = viaLabel,
                fontFamily = FontFamily.Monospace,
                fontSize = 11.5.sp,
                color = FlightDeckColors.TextSecondary,
                maxLines = 1
            )
        }

        if (isSelected) {
            Spacer(modifier = Modifier.width(6.dp))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(5.dp))
                    .background(FlightDeckColors.WarningOrange)
                    .clickable(onClick = onFlyClick)
                    .padding(horizontal = 8.dp, vertical = 2.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Fly →",
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 11.5.sp,
                    color = Color.Black
                )
            }
        }
    }
}
