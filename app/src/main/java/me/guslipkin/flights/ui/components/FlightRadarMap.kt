package me.guslipkin.flights.ui.components

import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import me.guslipkin.flights.data.CoastlineData
import me.guslipkin.flights.data.LatLon
import me.guslipkin.flights.data.LonLat
import me.guslipkin.flights.data.MapBounds
import me.guslipkin.flights.data.Network
import me.guslipkin.flights.data.Ticket
import me.guslipkin.flights.game.Status
import me.guslipkin.flights.ui.GameUiState
import me.guslipkin.flights.ui.theme.FlightDeckColors
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.hypot

private data class AirportNodeSpec(
    val airportIdx: Int,
    val code: String,
    val textColor: Color,
    val dotColor: Color,
    val badgeBg: Color? = null,
    val isCurrent: Boolean = false,
    val isDestination: Boolean = false,
    val isSelectedOption: Boolean = false
)

private data class ScreenAirportHit(
    val airportIdx: Int,
    val x: Float,
    val y: Float
)

@Composable
fun FlightRadarMap(
    uiState: GameUiState,
    network: Network,
    coastlines: CoastlineData,
    isFullScreen: Boolean,
    onToggleFullScreen: () -> Unit,
    onAirportTapped: (Int) -> Unit,
    onZoomButton: (Double) -> Unit,
    onTransformGesture: (zoomFactor: Double, panFracX: Double, panFracY: Double, focusFracX: Double, focusFracY: Double) -> Unit,
    onFitMap: () -> Unit,
    onUpdateFittedBounds: (MapBounds) -> Unit,
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current
    val labelTextSizePx = with(density) { 11.5.sp.toPx() }
    val labelPadH = with(density) { 4.dp.toPx() }
    val labelPadV = with(density) { 2.dp.toPx() }
    val dotRadiusPx = with(density) { 3.8.dp.toPx() }
    val tapRadiusPx = with(density) { 28.dp.toPx() }

    val textPaint = remember(labelTextSizePx) {
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            textSize = labelTextSizePx
        }
    }

    val hitTargets = remember { ArrayList<ScreenAirportHit>() }

    val showVia = uiState.rules.showsConnections()
    val selectedOption = uiState.selectedOptionIndex?.let { uiState.options.getOrNull(it) }

    fun pathOf(a: Int, via: List<Int>, b: Int): List<Int> {
        val list = ArrayList<Int>(2 + if (showVia) via.size else 0)
        list.add(a)
        if (showVia) list.addAll(via)
        list.add(b)
        return list
    }

    fun pathsOf(stops: List<Int>, legs: List<Ticket>): List<List<Int>> {
        val list = ArrayList<List<Int>>(legs.size)
        for (i in 0 until minOf(stops.size - 1, legs.size)) {
            list.add(pathOf(stops[i], legs[i].via, stops[i + 1]))
        }
        return list
    }

    val flownPaths = remember(uiState.route, uiState.legs, showVia) {
        pathsOf(uiState.route, uiState.legs)
    }
    val bestPaths = remember(uiState.status, uiState.bestRoute, uiState.bestLegs, showVia) {
        if (uiState.status == Status.GivenUp) {
            pathsOf(uiState.bestRoute, uiState.bestLegs)
        } else {
            emptyList()
        }
    }
    val previewPaths = remember(
        uiState.selectedHop,
        selectedOption,
        uiState.currentAirport,
        showVia
    ) {
        val hop = uiState.selectedHop
        when {
            hop != null -> listOf(pathOf(hop.from, hop.ticket.via, hop.to))
            selectedOption != null -> listOf(
                pathOf(uiState.currentAirport, selectedOption.connections, selectedOption.airport)
            )
            else -> emptyList()
        }
    }

    val fittingPoints = remember(
        uiState.originAirport,
        uiState.destinationAirport,
        uiState.currentAirport,
        flownPaths,
        bestPaths,
        previewPaths,
        uiState.options,
        uiState.curves,
        network
    ) {
        val shown = LinkedHashSet<Int>()
        shown.add(uiState.originAirport)
        shown.add(uiState.destinationAirport)
        shown.add(uiState.currentAirport)
        flownPaths.forEach { shown.addAll(it) }
        bestPaths.forEach { shown.addAll(it) }
        previewPaths.forEach { shown.addAll(it) }
        uiState.options.forEach { shown.add(it.airport) }

        val pts = ArrayList<LatLon>(shown.size * 2)
        for (idx in shown) {
            pts.add(network.coords(idx))
        }
        if (uiState.curves) {
            fun xy(i: Int): LonLat {
                val c = network.coords(i)
                return LonLat(c.lon, c.lat)
            }
            val allPaths = flownPaths + bestPaths + previewPaths
            for (path in allPaths) {
                for (i in 0 until path.size - 1) {
                    val curve = CoastlineData.legPoints(xy(path[i]), xy(path[i + 1]), true)
                    for (pt in curve) {
                        pts.add(LatLon(pt.lat, CoastlineData.wrapLon(pt.lon, 0.0)))
                    }
                }
            }
        }
        pts
    }

    val nodeSpecs = remember(
        uiState.selectedHop,
        uiState.destinationAirport,
        uiState.status,
        uiState.currentAirport,
        uiState.originAirport,
        selectedOption,
        uiState.options,
        uiState.route,
        uiState.bestRoute,
        flownPaths,
        bestPaths,
        previewPaths,
        network
    ) {
        val labelled = HashSet<Int>()
        val list = ArrayList<AirportNodeSpec>()

        fun addLabel(
            idx: Int,
            textColor: Color,
            dotColor: Color,
            badgeBg: Color? = null,
            isCurrent: Boolean = false,
            isDestination: Boolean = false,
            isSelectedOption: Boolean = false
        ) {
            if (labelled.add(idx)) {
                val baseCode = network.code(idx)
                val displayCode = if (idx == uiState.destinationAirport) "$baseCode★" else baseCode
                list.add(
                    AirportNodeSpec(
                        airportIdx = idx,
                        code = displayCode,
                        textColor = textColor,
                        dotColor = dotColor,
                        badgeBg = badgeBg,
                        isCurrent = isCurrent,
                        isDestination = isDestination,
                        isSelectedOption = isSelectedOption
                    )
                )
            }
        }

        // Priority 1: Picked hop endpoints (post-game hop stepping)
        uiState.selectedHop?.let { hop ->
            addLabel(
                idx = hop.to,
                textColor = Color.Black,
                dotColor = FlightDeckColors.WarningOrange,
                badgeBg = FlightDeckColors.WarningOrange,
                isSelectedOption = true
            )
            addLabel(
                idx = hop.from,
                textColor = FlightDeckColors.WarningOrange,
                dotColor = FlightDeckColors.WarningOrange
            )
        }

        // Priority 2: Destination
        addLabel(
            idx = uiState.destinationAirport,
            textColor = FlightDeckColors.DestinationPurple,
            dotColor = FlightDeckColors.DestinationPurple,
            badgeBg = if (selectedOption?.airport == uiState.destinationAirport) {
                FlightDeckColors.WarningOrange
            } else {
                null
            },
            isDestination = true,
            isSelectedOption = selectedOption?.airport == uiState.destinationAirport
        )

        // Priority 3: Current airport while playing
        if (uiState.status == Status.Playing) {
            addLabel(
                idx = uiState.currentAirport,
                textColor = FlightDeckColors.PositiveGreen,
                dotColor = FlightDeckColors.PositiveGreen,
                isCurrent = true
            )
        }

        // Priority 4: Origin
        addLabel(
            idx = uiState.originAirport,
            textColor = FlightDeckColors.TextPrimary,
            dotColor = FlightDeckColors.TextPrimary
        )

        // Priority 5: Currently selected option (black text on orange badge)
        selectedOption?.let { opt ->
            addLabel(
                idx = opt.airport,
                textColor = Color.Black,
                dotColor = FlightDeckColors.WarningOrange,
                badgeBg = FlightDeckColors.WarningOrange,
                isSelectedOption = true
            )
        }

        // Priority 6: Remaining options
        for (opt in uiState.options) {
            addLabel(
                idx = opt.airport,
                textColor = FlightDeckColors.WarningOrange,
                dotColor = FlightDeckColors.WarningOrange
            )
        }

        // Priority 7: Flown route stops
        for (idx in uiState.route) {
            addLabel(
                idx = idx,
                textColor = FlightDeckColors.AccentSkyBlue,
                dotColor = FlightDeckColors.AccentSkyBlue
            )
        }

        // Priority 8: Shortest route stops on Give Up
        if (uiState.status == Status.GivenUp) {
            for (idx in uiState.bestRoute.asReversed()) {
                addLabel(
                    idx = idx,
                    textColor = FlightDeckColors.PositiveGreen,
                    dotColor = FlightDeckColors.PositiveGreen
                )
            }
        }

        // Priority 9: Connection-only intermediate airports
        val allPaths = flownPaths + bestPaths + previewPaths
        for (path in allPaths) {
            for (i in 1 until path.size - 1) {
                addLabel(
                    idx = path[i],
                    textColor = FlightDeckColors.TextMuted,
                    dotColor = FlightDeckColors.TextSecondary
                )
            }
        }

        list
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(FlightDeckColors.RadarBackground)
            .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(12.dp))
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    detectTransformGestures { centroid, pan, zoom, _ ->
                        val w = size.width.toDouble().coerceAtLeast(1.0)
                        val h = size.height.toDouble().coerceAtLeast(1.0)
                        val zoomFactor = if (zoom > 0f) (1.0 / zoom.toDouble()) else 1.0
                        val panFracX = pan.x.toDouble() / w
                        val panFracY = pan.y.toDouble() / h
                        val focusFracX = (centroid.x.toDouble() / w).coerceIn(0.0, 1.0)
                        val focusFracY = (centroid.y.toDouble() / h).coerceIn(0.0, 1.0)
                        onTransformGesture(zoomFactor, panFracX, panFracY, focusFracX, focusFracY)
                    }
                }
                .pointerInput(uiState.options, uiState.selectedOptionIndex) {
                    detectTapGestures(
                        onTap = { tapOffset ->
                            val nearest = hitTargets
                                .map { it to hypot(it.x - tapOffset.x, it.y - tapOffset.y) }
                                .filter { it.second <= tapRadiusPx }
                                .minByOrNull { it.second }
                            if (nearest != null) {
                                onAirportTapped(nearest.first.airportIdx)
                            }
                        },
                        onDoubleTap = { tapOffset ->
                            val w = size.width.toDouble().coerceAtLeast(1.0)
                            val h = size.height.toDouble().coerceAtLeast(1.0)
                            onTransformGesture(
                                1.0 / 1.5,
                                0.0,
                                0.0,
                                (tapOffset.x / w).coerceIn(0.0, 1.0),
                                (tapOffset.y / h).coerceIn(0.0, 1.0)
                            )
                        }
                    )
                }
        ) {
            val w = size.width
            val h = size.height
            if (w < 8f || h < 8f) return@Canvas

            val fitted = CoastlineData.mapBounds(
                points = fittingPoints,
                aspectRatio = (w / h).toDouble()
            )
            onUpdateFittedBounds(fitted)
            val bounds = uiState.userMapBounds ?: fitted

            fun toScreen(lon: Double, lat: Double): Offset {
                val sx = ((lon - bounds.lonMin) / bounds.lonSpan * w.toDouble()).toFloat()
                val sy = ((bounds.latMax - lat) / bounds.latSpan * h.toDouble()).toFloat()
                return Offset(sx, sy)
            }

            // 1. Subtle radar graticule grid (every 30 degrees)
            drawRadarGrid(bounds, ::toScreen)

            // 2. Natural Earth vector coastlines
            val activeCoastlines = coastlines.forCanvasView(bounds.latSpan)
            val turns = CoastlineData.turns(bounds)
            for (turn in turns) {
                for (line in activeCoastlines) {
                    val bbox = line.bbox
                    if (bbox.lonMax + turn < bounds.lonMin ||
                        bbox.lonMin + turn > bounds.lonMax ||
                        bbox.latMax < bounds.latMin ||
                        bbox.latMin > bounds.latMax
                    ) {
                        continue
                    }
                    val count = line.size
                    for (i in 0 until count - 1) {
                        val ax = line.lonAt(i) + turn
                        val ay = line.latAt(i)
                        val bx = line.lonAt(i + 1) + turn
                        val by = line.latAt(i + 1)
                        val seg = CoastlineData.clip(ax, ay, bx, by, bounds)
                        if (seg != null) {
                            drawLine(
                                color = FlightDeckColors.CoastlineVector,
                                start = toScreen(seg.ax, seg.ay),
                                end = toScreen(seg.bx, seg.by),
                                strokeWidth = 1.25.dp.toPx(),
                                cap = StrokeCap.Round
                            )
                        }
                    }
                }
            }

            // 3. Flight paths (Flown in Sky Blue, Best in Green on GiveUp, Preview in Orange)
            fun drawFlightPaths(
                paths: List<List<Int>>,
                color: Color,
                strokeWidthDp: Float,
                dashed: Boolean = false
            ) {
                if (paths.isEmpty()) return
                val strokePx = strokeWidthDp.dp.toPx()
                val glowPx = (strokeWidthDp * 2.4f).dp.toPx()
                val effect = if (dashed) {
                    PathEffect.dashPathEffect(floatArrayOf(14f, 9f), 0f)
                } else {
                    null
                }
                for (path in paths) {
                    for (i in 0 until path.size - 1) {
                        val ca = network.coords(path[i])
                        val cb = network.coords(path[i + 1])
                        val legPts = CoastlineData.legPoints(
                            LonLat(ca.lon, ca.lat),
                            LonLat(cb.lon, cb.lat),
                            uiState.curves
                        )
                        for (turn in turns) {
                            for (j in 0 until legPts.size - 1) {
                                val p0 = legPts[j]
                                val p1 = legPts[j + 1]
                                val seg = CoastlineData.clip(
                                    p0.lon + turn,
                                    p0.lat,
                                    p1.lon + turn,
                                    p1.lat,
                                    bounds
                                )
                                if (seg != null) {
                                    val startOff = toScreen(seg.ax, seg.ay)
                                    val endOff = toScreen(seg.bx, seg.by)
                                    drawLine(
                                        color = color.copy(alpha = 0.22f),
                                        start = startOff,
                                        end = endOff,
                                        strokeWidth = glowPx,
                                        cap = StrokeCap.Round
                                    )
                                    drawLine(
                                        color = color,
                                        start = startOff,
                                        end = endOff,
                                        strokeWidth = strokePx,
                                        cap = StrokeCap.Round,
                                        pathEffect = effect
                                    )
                                }
                            }
                        }
                    }
                }
            }

            drawFlightPaths(flownPaths, FlightDeckColors.AccentSkyBlue, 2.3f)
            if (uiState.status == Status.GivenUp) {
                drawFlightPaths(bestPaths, FlightDeckColors.PositiveGreen, 2.5f)
            }
            drawFlightPaths(
                paths = previewPaths,
                color = FlightDeckColors.WarningOrange,
                strokeWidthDp = 2.6f,
                dashed = uiState.status == Status.Playing
            )

            // 4. Airport dots and non-overlapping monospace code labels
            hitTargets.clear()
            val occupiedRects = ArrayList<Rect>(nodeSpecs.size * 2)
            val centerLon = bounds.centerLon

            for (spec in nodeSpecs) {
                val coord = network.coords(spec.airportIdx)
                val lon = CoastlineData.wrapLon(coord.lon, centerLon)
                val lat = coord.lat
                if (lon < bounds.lonMin || lon > bounds.lonMax || lat < bounds.latMin || lat > bounds.latMax) {
                    continue
                }
                val pt = toScreen(lon, lat)
                hitTargets.add(ScreenAirportHit(spec.airportIdx, pt.x, pt.y))

                // Draw airport node dot & outer halo ring for key nodes
                if (spec.isCurrent || spec.isDestination || spec.isSelectedOption) {
                    drawCircle(
                        color = spec.dotColor.copy(alpha = 0.28f),
                        radius = dotRadiusPx * 2.2f,
                        center = pt
                    )
                    drawCircle(
                        color = spec.dotColor,
                        radius = dotRadiusPx * 1.25f,
                        center = pt
                    )
                } else {
                    drawCircle(
                        color = spec.dotColor,
                        radius = dotRadiusPx,
                        center = pt
                    )
                }

                // Reserve a small box around the airport dot itself
                val dotBox = Rect(
                    left = pt.x - dotRadiusPx - 2f,
                    top = pt.y - dotRadiusPx - 2f,
                    right = pt.x + dotRadiusPx + 2f,
                    bottom = pt.y + dotRadiusPx + 2f
                )

                val textWidth = textPaint.measureText(spec.code)
                val boxW = textWidth + labelPadH * 2f
                val boxH = labelTextSizePx + labelPadV * 2f
                val gap = dotRadiusPx + 4f

                val candidates = arrayOf(
                    Offset(pt.x + gap, pt.y - boxH / 2f),
                    Offset(pt.x - gap - boxW, pt.y - boxH / 2f),
                    Offset(pt.x - boxW / 2f, pt.y - gap - boxH),
                    Offset(pt.x - boxW / 2f, pt.y + gap),
                    Offset(pt.x + gap, pt.y - gap - boxH),
                    Offset(pt.x - gap - boxW, pt.y - gap - boxH),
                    Offset(pt.x + gap, pt.y + gap),
                    Offset(pt.x - gap - boxW, pt.y + gap)
                )

                var chosenRect: Rect? = null
                for (cand in candidates) {
                    val rect = Rect(
                        left = cand.x,
                        top = cand.y,
                        right = cand.x + boxW,
                        bottom = cand.y + boxH
                    )
                    if (rect.left < 2f || rect.right > w - 2f || rect.top < 2f || rect.bottom > h - 2f) {
                        continue
                    }
                    val overlaps = occupiedRects.any { it.overlaps(rect) }
                    if (!overlaps) {
                        chosenRect = rect
                        break
                    }
                }

                occupiedRects.add(dotBox)

                if (chosenRect != null) {
                    occupiedRects.add(chosenRect)
                    val bg = spec.badgeBg
                    if (bg != null) {
                        drawRoundRect(
                            color = bg,
                            topLeft = Offset(chosenRect.left, chosenRect.top),
                            size = Size(chosenRect.width, chosenRect.height),
                            cornerRadius = CornerRadius(4.dp.toPx(), 4.dp.toPx())
                        )
                    } else {
                        drawRoundRect(
                            color = FlightDeckColors.RadarBackground.copy(alpha = 0.82f),
                            topLeft = Offset(chosenRect.left, chosenRect.top),
                            size = Size(chosenRect.width, chosenRect.height),
                            cornerRadius = CornerRadius(4.dp.toPx(), 4.dp.toPx())
                        )
                    }

                    textPaint.color = if (bg != null) {
                        Color.Black.toArgb()
                    } else {
                        spec.textColor.toArgb()
                    }
                    val baselineY = chosenRect.top + labelPadV + labelTextSizePx * 0.84f
                    drawContext.canvas.nativeCanvas.drawText(
                        spec.code,
                        chosenRect.left + labelPadH,
                        baselineY,
                        textPaint
                    )
                }
            }
        }

        // Top-left map legend pill
        Row(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(8.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(FlightDeckColors.SurfaceCard.copy(alpha = 0.86f))
                .border(1.dp, FlightDeckColors.BorderSubtle, RoundedCornerShape(6.dp))
                .padding(horizontal = 8.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            LegendDot(color = FlightDeckColors.PositiveGreen, label = uiState.currentCode)
            LegendDot(color = FlightDeckColors.DestinationPurple, label = "${uiState.endCode}★")
            if (uiState.status == Status.GivenUp) {
                LegendDot(color = FlightDeckColors.AccentSkyBlue, label = "Yours")
                LegendDot(color = FlightDeckColors.PositiveGreen, label = "Shortest")
            } else {
                LegendDot(color = FlightDeckColors.WarningOrange, label = "Options")
            }
        }

        // Top-right Full Screen Toggle Button
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(8.dp)
        ) {
            RadarHudButton(
                text = if (isFullScreen) "Exit Full" else "Full",
                accent = isFullScreen,
                onClick = onToggleFullScreen
            )
        }

        // Floating Zoom / Fit HUD controls in bottom-right corner
        Column(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
            horizontalAlignment = Alignment.End
        ) {
            if (uiState.userMapBounds != null) {
                RadarHudButton(
                    text = "Fit",
                    accent = true,
                    onClick = onFitMap
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                RadarHudButton(
                    text = "−",
                    onClick = { onZoomButton(1.5) }
                )
                RadarHudButton(
                    text = "+",
                    onClick = { onZoomButton(1.0 / 1.5) }
                )
            }
        }
    }
}

private fun DrawScope.drawRadarGrid(
    bounds: MapBounds,
    toScreen: (lon: Double, lat: Double) -> Offset
) {
    val step = 30.0
    val firstLon = ceil(bounds.lonMin / step) * step
    val lastLon = floor(bounds.lonMax / step) * step
    var lon = firstLon
    while (lon <= lastLon) {
        val top = toScreen(lon, bounds.latMax)
        val bottom = toScreen(lon, bounds.latMin)
        drawLine(
            color = FlightDeckColors.RadarGrid,
            start = top,
            end = bottom,
            strokeWidth = 1f
        )
        lon += step
    }

    val firstLat = ceil(bounds.latMin / step) * step
    val lastLat = floor(bounds.latMax / step) * step
    var lat = firstLat
    while (lat <= lastLat) {
        if (lat in -90.0..90.0) {
            val left = toScreen(bounds.lonMin, lat)
            val right = toScreen(bounds.lonMax, lat)
            drawLine(
                color = FlightDeckColors.RadarGrid,
                start = left,
                end = right,
                strokeWidth = 1f
            )
        }
        lat += step
    }
}

@Composable
private fun LegendDot(color: Color, label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Canvas(modifier = Modifier.padding(end = 1.dp)) {
            drawCircle(color = color, radius = 3.5.dp.toPx())
        }
        Text(
            text = label,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            fontSize = 11.sp,
            color = FlightDeckColors.TextSecondary
        )
    }
}

@Composable
private fun RadarHudButton(
    text: String,
    accent: Boolean = false,
    onClick: () -> Unit
) {
    val borderColor = if (accent) FlightDeckColors.AccentSkyBlue else FlightDeckColors.BorderAccent
    val textColor = if (accent) FlightDeckColors.AccentSkyBlue else FlightDeckColors.TextPrimary
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(FlightDeckColors.SurfaceCard.copy(alpha = 0.90f))
            .border(1.dp, borderColor, RoundedCornerShape(6.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            fontSize = 12.5.sp,
            color = textColor
        )
    }
}
