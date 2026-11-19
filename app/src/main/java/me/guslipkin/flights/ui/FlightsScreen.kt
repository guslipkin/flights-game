package me.guslipkin.flights.ui

import android.content.Intent
import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import me.guslipkin.flights.game.Status
import me.guslipkin.flights.ui.components.DifficultyDialog
import me.guslipkin.flights.ui.components.FlightRadarMap
import me.guslipkin.flights.ui.components.HelpDialog
import me.guslipkin.flights.ui.components.OptionsPanel
import me.guslipkin.flights.ui.components.RoutePanel
import me.guslipkin.flights.ui.components.SettingsDialog
import me.guslipkin.flights.ui.theme.FlightDeckColors

@Composable
fun FlightsScreen(viewModel: FlightsViewModel) {
    val uiState = viewModel.uiState
    val network = viewModel.currentNetwork
    val coastlines = viewModel.coastlines
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    // Only use side-by-side layout on large tablet screens (smallestScreenWidthDp >= 600)
    val isLargeTabletLandscape = configuration.smallestScreenWidthDp >= 600 &&
        configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    fun shareResults() {
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, uiState.shareCardText)
        }
        val chooser = Intent.createChooser(sendIntent, "Share Flights Route")
        context.startActivity(chooser)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FlightDeckColors.Background)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // 1. Flight-Deck Header Bar
        FlightDeckHeader(
            uiState = uiState,
            onOpenDifficulty = { viewModel.setDifficultyDialogVisible(true) },
            onCycleUnits = viewModel::cycleUnits,
            onOpenHelp = { viewModel.setHelpVisible(true) }
        )

        // 2. Main Body
        if (uiState.mapFullScreen && uiState.rules.showsMap()) {
            // Full-Screen Map Mode
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FlightRadarMap(
                    uiState = uiState,
                    network = network,
                    coastlines = coastlines,
                    isFullScreen = true,
                    onToggleFullScreen = viewModel::toggleMapFullScreen,
                    onAirportTapped = viewModel::onMapAirportTapped,
                    onZoomButton = { factor -> viewModel.zoomMap(factor) },
                    onTransformGesture = viewModel::transformMap,
                    onFitMap = viewModel::fitMap,
                    onUpdateFittedBounds = viewModel::updateFittedBounds,
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                )

                RoutePanel(
                    uiState = uiState,
                    network = network,
                    alwaysExpanded = false,
                    maxExpandedHeight = 140.dp,
                    onToggleExpanded = viewModel::toggleRouteExpanded,
                    onGoBack = viewModel::goBack,
                    onStepHop = viewModel::stepRouteHop,
                    onSelectHopStep = viewModel::selectRouteHop,
                    onShare = ::shareResults,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        } else if (!isLargeTabletLandscape) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (uiState.rules.showsMap()) {
                    FlightRadarMap(
                        uiState = uiState,
                        network = network,
                        coastlines = coastlines,
                        isFullScreen = false,
                        onToggleFullScreen = viewModel::toggleMapFullScreen,
                        onAirportTapped = viewModel::onMapAirportTapped,
                        onZoomButton = { factor -> viewModel.zoomMap(factor) },
                        onTransformGesture = viewModel::transformMap,
                        onFitMap = viewModel::fitMap,
                        onUpdateFittedBounds = viewModel::updateFittedBounds,
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(if (uiState.status == Status.Playing) 0.44f else 0.46f)
                    )
                }

                StatusBanner(
                    uiState = uiState,
                    onShare = ::shareResults
                )

                if (uiState.status == Status.Playing) {
                    OptionsPanel(
                        uiState = uiState,
                        network = network,
                        onOptionTapped = viewModel::onOptionTapped,
                        onFlySelected = viewModel::flyToSelected,
                        onGoBack = viewModel::goBack,
                        onNewGame = { viewModel.startNewGame(null) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(0.56f)
                    )

                    RoutePanel(
                        uiState = uiState,
                        network = network,
                        alwaysExpanded = false,
                        maxExpandedHeight = 175.dp,
                        onToggleExpanded = viewModel::toggleRouteExpanded,
                        onGoBack = viewModel::goBack,
                        onStepHop = viewModel::stepRouteHop,
                        onSelectHopStep = viewModel::selectRouteHop,
                        onShare = ::shareResults,
                        modifier = Modifier.fillMaxWidth()
                    )
                } else {
                    RoutePanel(
                        uiState = uiState,
                        network = network,
                        alwaysExpanded = true,
                        onToggleExpanded = viewModel::toggleRouteExpanded,
                        onGoBack = viewModel::goBack,
                        onStepHop = viewModel::stepRouteHop,
                        onSelectHopStep = viewModel::selectRouteHop,
                        onShare = ::shareResults,
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(0.54f)
                    )
                }
            }
        } else {
            // Tablet Landscape Layout
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (uiState.rules.showsMap()) {
                    FlightRadarMap(
                        uiState = uiState,
                        network = network,
                        coastlines = coastlines,
                        isFullScreen = false,
                        onToggleFullScreen = viewModel::toggleMapFullScreen,
                        onAirportTapped = viewModel::onMapAirportTapped,
                        onZoomButton = { factor -> viewModel.zoomMap(factor) },
                        onTransformGesture = viewModel::transformMap,
                        onFitMap = viewModel::fitMap,
                        onUpdateFittedBounds = viewModel::updateFittedBounds,
                        modifier = Modifier
                            .weight(0.54f)
                            .fillMaxHeight()
                    )
                    Column(
                        modifier = Modifier
                            .weight(0.46f)
                            .fillMaxHeight(),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        StatusBanner(
                            uiState = uiState,
                            onShare = ::shareResults
                        )
                        if (uiState.status == Status.Playing) {
                            OptionsPanel(
                                uiState = uiState,
                                network = network,
                                onOptionTapped = viewModel::onOptionTapped,
                                onFlySelected = viewModel::flyToSelected,
                                onGoBack = viewModel::goBack,
                                onNewGame = { viewModel.startNewGame(null) },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .weight(0.58f)
                            )
                            RoutePanel(
                                uiState = uiState,
                                network = network,
                                alwaysExpanded = true,
                                onToggleExpanded = viewModel::toggleRouteExpanded,
                                onGoBack = viewModel::goBack,
                                onStepHop = viewModel::stepRouteHop,
                                onSelectHopStep = viewModel::selectRouteHop,
                                onShare = ::shareResults,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .weight(0.42f)
                            )
                        } else {
                            RoutePanel(
                                uiState = uiState,
                                network = network,
                                alwaysExpanded = true,
                                onToggleExpanded = viewModel::toggleRouteExpanded,
                                onGoBack = viewModel::goBack,
                                onStepHop = viewModel::stepRouteHop,
                                onSelectHopStep = viewModel::selectRouteHop,
                                onShare = ::shareResults,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .weight(1f)
                            )
                        }
                    }
                } else {
                    OptionsPanel(
                        uiState = uiState,
                        network = network,
                        onOptionTapped = viewModel::onOptionTapped,
                        onFlySelected = viewModel::flyToSelected,
                        onGoBack = viewModel::goBack,
                        onNewGame = { viewModel.startNewGame(null) },
                        modifier = Modifier
                            .weight(0.5f)
                            .fillMaxHeight()
                    )
                    Column(
                        modifier = Modifier
                            .weight(0.5f)
                            .fillMaxHeight(),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        StatusBanner(
                            uiState = uiState,
                            onShare = ::shareResults
                        )
                        RoutePanel(
                            uiState = uiState,
                            network = network,
                            alwaysExpanded = true,
                            onToggleExpanded = viewModel::toggleRouteExpanded,
                            onGoBack = viewModel::goBack,
                            onStepHop = viewModel::stepRouteHop,
                            onSelectHopStep = viewModel::selectRouteHop,
                            onShare = ::shareResults,
                            modifier = Modifier
                                .fillMaxWidth()
                                .weight(1f)
                        )
                    }
                }
            }
        }

        // 3. Bottom Action Bar (New Game, Daily, Give Up / Share, Settings)
        FlightDeckBottomBar(
            uiState = uiState,
            onNewGame = { viewModel.startNewGame(null) },
            onDaily = viewModel::startDailyGame,
            onGiveUp = viewModel::triggerGiveUp,
            onShare = ::shareResults,
            onOpenSettings = { viewModel.setSettingsVisible(true) }
        )
    }

    if (uiState.showDifficultyDialog) {
        DifficultyDialog(
            uiState = uiState,
            networkProvider = viewModel.networkProvider,
            onSelectDifficulty = viewModel::selectDifficultyFromDialog,
            onConfigureCustom = viewModel::openCustomFromDifficultyDialog,
            onDismiss = { viewModel.setDifficultyDialogVisible(false) }
        )
    }

    if (uiState.showSettings) {
        SettingsDialog(
            uiState = uiState,
            networkProvider = viewModel.networkProvider,
            onApply = viewModel::applySettings,
            onDismiss = { viewModel.setSettingsVisible(false) }
        )
    }

    if (uiState.showHelp) {
        HelpDialog(
            uiState = uiState,
            networkProvider = viewModel.networkProvider,
            onDismiss = { viewModel.setHelpVisible(false) }
        )
    }
}

@Composable
private fun FlightDeckHeader(
    uiState: GameUiState,
    onOpenDifficulty: () -> Unit,
    onCycleUnits: () -> Unit,
    onOpenHelp: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(FlightDeckColors.SurfaceCard)
            .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(10.dp))
            .padding(horizontal = 10.dp, vertical = 7.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Title + Route Pill
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                Text(
                    text = "FLIGHTS",
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    letterSpacing = 1.2.sp,
                    color = FlightDeckColors.TextPrimary
                )
                if (uiState.dailyDate != null) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .background(FlightDeckColors.AccentSkyBlue.copy(alpha = 0.2f))
                            .border(
                                1.dp,
                                FlightDeckColors.AccentSkyBlue.copy(alpha = 0.6f),
                                RoundedCornerShape(4.dp)
                            )
                            .padding(horizontal = 5.dp, vertical = 1.dp)
                    ) {
                        Text(
                            text = "DAILY",
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                            fontSize = 9.sp,
                            color = FlightDeckColors.AccentSkyBlue
                        )
                    }
                }
            }

            // Route Badge: LAX → LOS★
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(FlightDeckColors.RadarBackground)
                    .border(1.dp, FlightDeckColors.BorderAccent, RoundedCornerShape(6.dp))
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = uiState.startCode,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                    color = FlightDeckColors.TextPrimary
                )
                Text(
                    text = " → ",
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                    color = FlightDeckColors.TextMuted
                )
                Text(
                    text = "${uiState.endCode}★",
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                    color = FlightDeckColors.DestinationPurple
                )
            }
        }

        // Right Badges & Quick Buttons
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // Difficulty Chip (opens DifficultyDialog with descriptions)
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(FlightDeckColors.SurfaceElevated)
                    .border(
                        1.dp,
                        FlightDeckColors.AccentSkyBlue.copy(alpha = 0.6f),
                        RoundedCornerShape(6.dp)
                    )
                    .clickable(onClick = onOpenDifficulty)
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(
                    text = "${uiState.difficulty.label} ▾",
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 11.sp,
                    color = FlightDeckColors.AccentSkyBlue
                )
            }

            // Distance / Units Chip (tapping cycles nm -> mi -> km)
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(FlightDeckColors.SurfaceElevated)
                    .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(6.dp))
                    .clickable(onClick = onCycleUnits)
                    .padding(horizontal = 7.dp, vertical = 4.dp)
            ) {
                val text = if (uiState.distancesVisible) {
                    uiState.units.format(uiState.totalDistanceNm)
                } else {
                    uiState.units.label
                }
                Text(
                    text = text,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 11.sp,
                    color = FlightDeckColors.TextSecondary
                )
            }

            // Help ?
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(FlightDeckColors.SurfaceElevated)
                    .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(6.dp))
                    .clickable(onClick = onOpenHelp)
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(
                    text = "?",
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp,
                    color = FlightDeckColors.TextPrimary
                )
            }
        }
    }
}

@Composable
private fun StatusBanner(
    uiState: GameUiState,
    onShare: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(FlightDeckColors.SurfaceCard)
            .border(
                1.dp,
                when (uiState.status) {
                    Status.Won -> FlightDeckColors.PositiveGreen.copy(alpha = 0.7f)
                    Status.GivenUp -> FlightDeckColors.WarningOrange.copy(alpha = 0.7f)
                    Status.Playing -> FlightDeckColors.BorderSubtle
                },
                RoundedCornerShape(10.dp)
            )
            .padding(horizontal = 10.dp, vertical = 7.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            val currentInfo = buildString {
                append("At ")
                append(uiState.currentCode)
                if (uiState.rules.showPlaces && uiState.currentPlace.isNotEmpty()) {
                    append(" (${uiState.currentPlace})")
                }
            }
            val destInfo = buildString {
                append("Target: ")
                append(uiState.endCode)
                if (uiState.rules.showPlaces && uiState.endPlace.isNotEmpty()) {
                    append(" (${uiState.endPlace})")
                }
            }

            Text(
                text = currentInfo,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.SemiBold,
                fontSize = 11.5.sp,
                color = FlightDeckColors.PositiveGreen,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = destInfo,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.SemiBold,
                fontSize = 11.5.sp,
                color = FlightDeckColors.DestinationPurple,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = uiState.statusMessage,
                fontSize = 12.5.sp,
                color = uiState.statusColor,
                modifier = Modifier.weight(1f)
            )
            if (uiState.status == Status.Won) {
                Spacer(modifier = Modifier.width(8.dp))
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(FlightDeckColors.PositiveGreen)
                        .clickable(onClick = onShare)
                        .padding(horizontal = 10.dp, vertical = 5.dp)
                ) {
                    Text(
                        text = "Share",
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        color = Color.Black
                    )
                }
            }
        }
    }
}

@Composable
private fun FlightDeckBottomBar(
    uiState: GameUiState,
    onNewGame: () -> Unit,
    onDaily: () -> Unit,
    onGiveUp: () -> Unit,
    onShare: () -> Unit,
    onOpenSettings: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(FlightDeckColors.SurfaceCard)
            .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(10.dp))
            .padding(horizontal = 6.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        BottomActionButton(
            label = "New Game",
            accentColor = FlightDeckColors.AccentSkyBlue,
            onClick = onNewGame,
            modifier = Modifier.weight(1f)
        )
        BottomActionButton(
            label = "Daily",
            accentColor = if (uiState.dailyDate != null) {
                FlightDeckColors.PositiveGreen
            } else {
                FlightDeckColors.TextPrimary
            },
            onClick = onDaily,
            modifier = Modifier.weight(0.9f)
        )
        if (uiState.status == Status.Playing) {
            BottomActionButton(
                label = "Give Up",
                accentColor = FlightDeckColors.WarningOrange,
                onClick = onGiveUp,
                modifier = Modifier.weight(1f)
            )
        } else {
            BottomActionButton(
                label = "Share",
                accentColor = FlightDeckColors.PositiveGreen,
                onClick = onShare,
                modifier = Modifier.weight(1f)
            )
        }
        BottomActionButton(
            label = "Settings",
            accentColor = FlightDeckColors.TextSecondary,
            onClick = onOpenSettings,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun BottomActionButton(
    label: String,
    accentColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .height(36.dp)
            .clip(RoundedCornerShape(7.dp))
            .background(FlightDeckColors.SurfaceElevated)
            .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(7.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            fontSize = 12.sp,
            color = accentColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}
