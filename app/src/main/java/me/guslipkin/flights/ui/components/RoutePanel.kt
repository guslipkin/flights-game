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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import me.guslipkin.flights.data.Network
import me.guslipkin.flights.data.Ticket
import me.guslipkin.flights.game.NEXT_HOP
import me.guslipkin.flights.game.Status
import me.guslipkin.flights.game.WENT_HERE
import me.guslipkin.flights.game.YOU_LEFT
import me.guslipkin.flights.game.pluralS
import me.guslipkin.flights.ui.GameUiState
import me.guslipkin.flights.ui.theme.FlightDeckColors

private sealed interface ExpandedRouteEntry {
    val key: String

    data class SectionTitle(
        override val key: String,
        val text: String,
        val color: Color
    ) : ExpandedRouteEntry

    data class StopRow(
        override val key: String,
        val primaryLine: AnnotatedString,
        val remark: Pair<String, Color>?,
        val place: String,
        val globalStep: Int?
    ) : ExpandedRouteEntry
}

@Composable
fun RoutePanel(
    uiState: GameUiState,
    network: Network,
    alwaysExpanded: Boolean,
    maxExpandedHeight: Dp = 210.dp,
    onToggleExpanded: () -> Unit,
    onGoBack: () -> Unit,
    onStepHop: (down: Boolean) -> Unit,
    onSelectHopStep: (Int?) -> Unit,
    onShare: () -> Unit,
    modifier: Modifier = Modifier
) {
    val isExpanded = alwaysExpanded || uiState.routeExpanded || uiState.status != Status.Playing
    val distanceSuffix = if (uiState.distancesVisible) {
        ": ${uiState.units.format(uiState.totalDistanceNm)}"
    } else {
        ""
    }
    val headerTitle = when (uiState.status) {
        Status.Playing -> "ROUTE (${uiState.hops} hop${pluralS(uiState.hops)}$distanceSuffix)"
        Status.Won -> "YOU WON! ROUTE$distanceSuffix"
        Status.GivenUp -> "GAME OVER · ROUTES"
    }
    val headerColor = when (uiState.status) {
        Status.Playing -> FlightDeckColors.AccentSkyBlue
        Status.Won -> FlightDeckColors.PositiveGreen
        Status.GivenUp -> FlightDeckColors.WarningOrange
    }

    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(FlightDeckColors.SurfaceCard)
            .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(12.dp))
            .padding(horizontal = 10.dp, vertical = 8.dp)
    ) {
        // Top Header Bar
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier
                    .weight(1f)
                    .clickable(enabled = !alwaysExpanded && uiState.status == Status.Playing) {
                        onToggleExpanded()
                    },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = headerTitle,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp,
                    letterSpacing = 0.6.sp,
                    color = headerColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                if (!alwaysExpanded && uiState.status == Status.Playing) {
                    Text(
                        text = if (isExpanded) "▾" else "▴",
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        color = FlightDeckColors.TextMuted
                    )
                }
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (uiState.status == Status.Playing) {
                    val canBack = uiState.hops > 0
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(
                                if (canBack) FlightDeckColors.SurfaceElevated else FlightDeckColors.Background
                            )
                            .border(
                                1.dp,
                                if (canBack) FlightDeckColors.BorderAccent else FlightDeckColors.BorderSubtle,
                                RoundedCornerShape(6.dp)
                            )
                            .clickable(enabled = canBack, onClick = onGoBack)
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = "← Go Back",
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp,
                            color = if (canBack) FlightDeckColors.TextPrimary else FlightDeckColors.TextMuted
                        )
                    }
                } else {
                    if (uiState.stepCount > 0) {
                        SmallRouteButton(
                            text = "Prev Hop",
                            onClick = { onStepHop(false) }
                        )
                        SmallRouteButton(
                            text = "Next Hop",
                            onClick = { onStepHop(true) }
                        )
                    }
                    SmallRouteButton(
                        text = "Share",
                        accentColor = FlightDeckColors.AccentSkyBlue,
                        onClick = onShare
                    )
                }
            }
        }

        if (!isExpanded) {
            // Virtualized LazyRow breadcrumb trail, right-aligned & auto-scrolling to destination on right
            val compactListState = rememberLazyListState()
            val breadcrumbTokens = remember(
                uiState.route,
                uiState.currentAirport,
                uiState.destinationAirport,
                uiState.endCode,
                uiState.atDestination,
                network
            ) {
                val list = ArrayList<AnnotatedString>(uiState.route.size + 1)
                for (i in uiState.route.indices) {
                    val idx = uiState.route[i]
                    val code = network.code(idx)
                    val isCurrent = idx == uiState.currentAirport
                    val isDest = idx == uiState.destinationAirport
                    val baseColor = when {
                        isCurrent -> FlightDeckColors.PositiveGreen
                        isDest -> FlightDeckColors.DestinationPurple
                        else -> FlightDeckColors.TextPrimary
                    }
                    val changed = if (i > 0) {
                        val prevCode = network.code(uiState.route[i - 1])
                        (0..2).firstOrNull { prevCode[it] != code[it] }
                    } else {
                        null
                    }
                    list.add(
                        buildAnnotatedString {
                            if (i > 0) {
                                withStyle(
                                    SpanStyle(
                                        color = FlightDeckColors.TextMuted,
                                        fontFamily = FontFamily.Monospace
                                    )
                                ) {
                                    append(" → ")
                                }
                                withStyle(
                                    SpanStyle(
                                        color = FlightDeckColors.TextSecondary,
                                        fontFamily = FontFamily.Monospace
                                    )
                                ) {
                                    append("$i.")
                                }
                            }
                            append(
                                styledAirportCode(
                                    code = code,
                                    changedIndex = changed,
                                    baseColor = baseColor,
                                    isDestination = isDest
                                )
                            )
                        }
                    )
                }
                if (!uiState.atDestination) {
                    list.add(
                        buildAnnotatedString {
                            withStyle(
                                SpanStyle(
                                    color = FlightDeckColors.TextMuted,
                                    fontFamily = FontFamily.Monospace
                                )
                            ) {
                                append(" → … → ")
                            }
                            withStyle(
                                SpanStyle(
                                    color = FlightDeckColors.DestinationPurple,
                                    fontWeight = FontWeight.Bold,
                                    fontFamily = FontFamily.Monospace
                                )
                            ) {
                                append("${uiState.endCode}★")
                            }
                        }
                    )
                }
                list
            }

            LaunchedEffect(breadcrumbTokens.size, uiState.currentAirport) {
                if (breadcrumbTokens.isNotEmpty()) {
                    compactListState.scrollToItem(breadcrumbTokens.lastIndex)
                }
            }

            LazyRow(
                state = compactListState,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 5.dp)
                    .clickable(onClick = onToggleExpanded),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically
            ) {
                itemsIndexed(breadcrumbTokens, key = { index, _ -> index }) { _, token ->
                    Text(
                        text = token,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                        maxLines = 1
                    )
                }
            }
        } else {
            // Virtualized LazyColumn for expanded stops list (zero lag even with many hops)
            val expandedListState = rememberLazyListState()
            val entries = remember(
                uiState.status,
                uiState.route,
                uiState.legs,
                uiState.bestRoute,
                uiState.bestLegs,
                uiState.divergence,
                uiState.distancesVisible,
                uiState.units,
                uiState.rules,
                uiState.currentAirport,
                uiState.destinationAirport,
                uiState.atDestination,
                uiState.endCode,
                network
            ) {
                buildExpandedRouteEntries(uiState, network)
            }

            LaunchedEffect(uiState.route.size, uiState.status, uiState.routeStep) {
                if (entries.isEmpty()) return@LaunchedEffect
                val step = uiState.routeStep
                if (step != null) {
                    val targetIdx = entries.indexOfFirst {
                        it is ExpandedRouteEntry.StopRow && it.globalStep == step
                    }
                    if (targetIdx >= 0) {
                        expandedListState.animateScrollToItem(targetIdx)
                    }
                } else if (uiState.status == Status.Playing) {
                    expandedListState.scrollToItem(entries.lastIndex)
                } else if (uiState.status == Status.GivenUp) {
                    expandedListState.scrollToItem(0)
                }
            }

            val heightMod = if (alwaysExpanded) {
                Modifier.fillMaxWidth()
            } else {
                Modifier
                    .fillMaxWidth()
                    .heightIn(max = maxExpandedHeight)
            }

            LazyColumn(
                state = expandedListState,
                modifier = heightMod.padding(top = 6.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                items(entries, key = { it.key }) { entry ->
                    when (entry) {
                        is ExpandedRouteEntry.SectionTitle -> {
                            Text(
                                text = entry.text,
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp,
                                color = entry.color,
                                modifier = Modifier.padding(top = 4.dp, bottom = 1.dp)
                            )
                        }
                        is ExpandedRouteEntry.StopRow -> {
                            val isPicked = uiState.status != Status.Playing &&
                                entry.globalStep != null &&
                                uiState.routeStep == entry.globalStep
                            val rowBg = if (isPicked) FlightDeckColors.SelectedRowBg else Color.Transparent
                            val rowBorder = if (isPicked) FlightDeckColors.WarningOrange else Color.Transparent

                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(rowBg)
                                    .border(1.dp, rowBorder, RoundedCornerShape(6.dp))
                                    .clickable(
                                        enabled = uiState.status != Status.Playing && entry.globalStep != null
                                    ) {
                                        onSelectHopStep(entry.globalStep)
                                    }
                                    .padding(horizontal = 6.dp, vertical = 2.dp)
                            ) {
                                Text(
                                    text = entry.primaryLine,
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 12.5.sp
                                )
                                StopSecondLine(
                                    remark = entry.remark,
                                    place = entry.place
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun buildExpandedRouteEntries(
    uiState: GameUiState,
    network: Network
): List<ExpandedRouteEntry> {
    val entries = ArrayList<ExpandedRouteEntry>()

    fun appendRouteStops(
        prefixKey: String,
        route: List<Int>,
        legs: List<Ticket>,
        stepOffset: Int,
        codeColorForStop: (stopPos: Int, airportIdx: Int) -> Color,
        remarkForStop: (stopPos: Int) -> Pair<String, Color>?
    ) {
        if (route.isEmpty()) return
        val startIdx = route[0]
        val startPrimary = buildAnnotatedString {
            append("    ")
            withStyle(
                SpanStyle(
                    color = codeColorForStop(0, startIdx),
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace
                )
            ) {
                append(network.code(startIdx))
            }
            withStyle(
                SpanStyle(
                    color = FlightDeckColors.TextSecondary,
                    fontFamily = FontFamily.Monospace
                )
            ) {
                append("  start")
            }
        }
        entries.add(
            ExpandedRouteEntry.StopRow(
                key = "${prefixKey}_start",
                primaryLine = startPrimary,
                remark = remarkForStop(0),
                place = if (uiState.rules.showPlaces) network.place(startIdx) else "",
                globalStep = null
            )
        )

        val hopCount = minOf(route.size - 1, legs.size)
        for (n in 0 until hopCount) {
            val fromIdx = route[n]
            val toIdx = route[n + 1]
            val leg = legs[n]
            val fromCode = network.code(fromIdx)
            val toCode = network.code(toIdx)
            val changed = (0..2).firstOrNull { fromCode[it] != toCode[it] }

            val primary = buildAnnotatedString {
                withStyle(
                    SpanStyle(
                        color = FlightDeckColors.TextSecondary,
                        fontFamily = FontFamily.Monospace
                    )
                ) {
                    append("%2d. ".format(n + 1))
                }
                append(
                    styledAirportCode(
                        code = toCode,
                        changedIndex = changed,
                        baseColor = codeColorForStop(n + 1, toIdx),
                        isDestination = toIdx == uiState.destinationAirport
                    )
                )
                if (uiState.distancesVisible) {
                    withStyle(
                        SpanStyle(
                            color = FlightDeckColors.TextSecondary,
                            fontFamily = FontFamily.Monospace
                        )
                    ) {
                        append("  ${uiState.units.format(leg.distance)}")
                    }
                }
                if (uiState.rules.showsConnections() && leg.via.isNotEmpty()) {
                    val viaCodes = leg.via.joinToString(", ") { network.code(it) }
                    withStyle(
                        SpanStyle(
                            color = FlightDeckColors.TextMuted,
                            fontFamily = FontFamily.Monospace
                        )
                    ) {
                        append(" via $viaCodes")
                    }
                }
            }

            entries.add(
                ExpandedRouteEntry.StopRow(
                    key = "${prefixKey}_hop_$n",
                    primaryLine = primary,
                    remark = remarkForStop(n + 1),
                    place = if (uiState.rules.showPlaces) network.place(toIdx) else "",
                    globalStep = stepOffset + n
                )
            )
        }
    }

    if (uiState.status == Status.GivenUp) {
        val split = uiState.divergence
        val yoursLeft = split < uiState.route.size
        entries.add(
            ExpandedRouteEntry.SectionTitle(
                key = "title_yours",
                text = "Yours${if (uiState.distancesVisible) ": ${uiState.units.format(uiState.totalDistanceNm)}" else ""}",
                color = FlightDeckColors.AccentSkyBlue
            )
        )
        appendRouteStops(
            prefixKey = "yours",
            route = uiState.route,
            legs = uiState.legs,
            stepOffset = 0,
            codeColorForStop = { _, airportIdx ->
                if (airportIdx == uiState.destinationAirport) {
                    FlightDeckColors.DestinationPurple
                } else {
                    FlightDeckColors.TextPrimary
                }
            },
            remarkForStop = { stopPos ->
                if (yoursLeft && stopPos == split) {
                    YOU_LEFT to FlightDeckColors.WarningOrange
                } else {
                    null
                }
            }
        )

        entries.add(
            ExpandedRouteEntry.SectionTitle(
                key = "title_shortest",
                text = "Shortest${if (uiState.distancesVisible) ": ${uiState.units.format(uiState.bestDistanceNm)}" else ""}",
                color = FlightDeckColors.PositiveGreen
            )
        )
        appendRouteStops(
            prefixKey = "shortest",
            route = uiState.bestRoute,
            legs = uiState.bestLegs,
            stepOffset = uiState.legs.size,
            codeColorForStop = { stopPos, _ ->
                if (stopPos < split) {
                    FlightDeckColors.TextSecondary
                } else {
                    FlightDeckColors.PositiveGreen
                }
            },
            remarkForStop = { stopPos ->
                if (stopPos == split) {
                    val remark = if (yoursLeft) WENT_HERE else NEXT_HOP
                    remark to FlightDeckColors.PositiveGreen
                } else {
                    null
                }
            }
        )
    } else {
        appendRouteStops(
            prefixKey = "playing",
            route = uiState.route,
            legs = uiState.legs,
            stepOffset = 0,
            codeColorForStop = { _, airportIdx ->
                when {
                    airportIdx == uiState.currentAirport && uiState.status == Status.Playing ->
                        FlightDeckColors.PositiveGreen
                    airportIdx == uiState.destinationAirport ->
                        FlightDeckColors.DestinationPurple
                    else ->
                        FlightDeckColors.TextPrimary
                }
            },
            remarkForStop = { null }
        )

        if (!uiState.atDestination) {
            val destPrimary = buildAnnotatedString {
                withStyle(
                    SpanStyle(
                        color = FlightDeckColors.TextSecondary,
                        fontFamily = FontFamily.Monospace
                    )
                ) {
                    append("  … ")
                }
                withStyle(
                    SpanStyle(
                        color = FlightDeckColors.DestinationPurple,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace
                    )
                ) {
                    append(uiState.endCode)
                }
                withStyle(
                    SpanStyle(
                        color = FlightDeckColors.TextSecondary,
                        fontFamily = FontFamily.Monospace
                    )
                ) {
                    append("  destination")
                }
            }
            entries.add(
                ExpandedRouteEntry.StopRow(
                    key = "playing_dest",
                    primaryLine = destPrimary,
                    remark = null,
                    place = if (uiState.rules.showPlaces) network.place(uiState.destinationAirport) else "",
                    globalStep = null
                )
            )
        }
    }

    return entries
}

@Composable
private fun StopSecondLine(
    remark: Pair<String, Color>?,
    place: String
) {
    if (remark == null && place.isEmpty()) return
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = "      ",
            fontFamily = FontFamily.Monospace,
            fontSize = 11.sp
        )
        if (remark != null) {
            Text(
                text = remark.first,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                fontSize = 11.sp,
                color = remark.second
            )
        }
        if (place.isNotEmpty()) {
            val sep = if (remark != null) " · " else "· "
            Text(
                text = "$sep$place",
                fontFamily = FontFamily.Monospace,
                fontSize = 11.sp,
                color = FlightDeckColors.TextMuted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun SmallRouteButton(
    text: String,
    accentColor: Color = FlightDeckColors.TextPrimary,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(FlightDeckColors.SurfaceElevated)
            .border(1.dp, FlightDeckColors.BorderAccent, RoundedCornerShape(6.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Spacer(modifier = Modifier.width(1.dp))
        Text(
            text = text,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            fontSize = 11.sp,
            color = accentColor
        )
    }
}
