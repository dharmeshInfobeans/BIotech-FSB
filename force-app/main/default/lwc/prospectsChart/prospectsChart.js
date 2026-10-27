import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import CHART_JS from '@salesforce/resourceUrl/chartJs';
import getChartData from '@salesforce/apex/ProspectsDashboardController.getChartData';
import getDrillDownRecords from '@salesforce/apex/ProspectsDashboardController.getDrillDownRecords';
import getChartFullDetail from '@salesforce/apex/ProspectsDashboardController.getChartFullDetail';
import { buildSpreadsheetXml, buildWorkbookXml, sanitizeFileNamePart, downloadSpreadsheet } from 'c/spreadsheetExport';

const DRILL_DOWN_PAGE_SIZE = 50;

const PALETTE = ['#8657e4', '#ff9f40', '#c23934', '#0176d3', '#04844b'];
const RATIO_COLOR = '#04844b';

const LABEL_FONT = 'bold 11px Arial, sans-serif';

function hexToRgb(hex) {
    const clean = hex.replace('#', '');
    const bigint = parseInt(clean, 16);
    return { r: (bigint >> 16) & 255, g: (bigint >> 8) & 255, b: bigint & 255 };
}

// Mixes a series color toward white to get a pale, opaque pastel - opaque so the pill always
// reads light regardless of what's drawn underneath it (gridlines, other bars, the plot area),
// unlike a semi-transparent tint whose apparent darkness depends on that background.
// mixWithWhite of 0 is the original color, 1 is pure white; ~0.6-0.7 gives a visible tinted chip.
function pastelize({ r, g, b }, mixWithWhite) {
    const mix = (channel) => Math.round(channel + (255 - channel) * mixWithWhite);
    return `rgb(${mix(r)}, ${mix(g)}, ${mix(b)})`;
}

function tracePillPath(ctx, x, y, width, height, radius) {
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + width - radius, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
    ctx.lineTo(x + width, y + height - radius);
    ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
    ctx.lineTo(x + radius, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
    ctx.lineTo(x, y + radius);
    ctx.quadraticCurveTo(x, y, x + radius, y);
    ctx.closePath();
}

function rectsOverlap(a, b) {
    return !(a.x + a.width < b.x || b.x + b.width < a.x || a.y + a.height < b.y || b.y + b.height < a.y);
}

// Draws each bar's raw count, and each ratio line point's percentage, directly on the chart -
// matching the old Power BI dashboard's data-labeled bars/lines rather than relying on hover
// tooltips - each one on its own rounded, pastel-tinted pill (tinted from the series' own color)
// so bold text stays legible over gridlines, other series, or a busy plot area behind it.
// Percentage formatting is driven by the `isRatio` flag set on the ratio dataset built in
// renderChart, not by inspecting values - a 0 or 100 raw count must never accidentally render
// with a '%' suffix. Zero values are skipped entirely: charts with many empty periods (e.g.
// Prospect Trend) were otherwise wall-to-wall with meaningless "0" pills crowding out the labels
// that actually matter.
//
// Two passes: (1) compute every label's natural pill rect from its data point position, (2)
// resolve overlaps by nudging later labels upward until clear of every already-placed one - Chart.js
// has no built-in collision avoidance for custom-drawn labels, and with many periods on screen two
// pills can easily land on the same spot - then draw. Positions must all be resolved before any
// drawing starts, since a label drawn early can't retroactively move once a later label turns out
// to overlap it. Capped at 3 nudges, matched to the chart's top padding (100px) so even a label
// stacked the full 3 deep still can't clip the canvas's top edge - past that a little residual
// overlap is the lesser problem versus letting the resolver climb unbounded.
const VALUE_LABEL_PLUGIN = {
    id: 'valueLabels',
    afterDatasetsDraw(chart) {
        const { ctx } = chart;
        ctx.save();
        ctx.font = LABEL_FONT;

        const labels = [];
        chart.data.datasets.forEach((dataset, datasetIndex) => {
            const meta = chart.getDatasetMeta(datasetIndex);
            if (meta.hidden) {
                return;
            }
            const rgb = hexToRgb(dataset.isRatio ? dataset.borderColor : dataset.backgroundColor);
            meta.data.forEach((element, index) => {
                const raw = dataset.data[index];
                if (!raw) {
                    return;
                }
                const text = dataset.isRatio ? raw + '%' : String(raw);
                const position = element.tooltipPosition();
                const yOffset = dataset.isRatio ? 14 : 8;
                const paddingX = 6;
                const paddingY = 3;
                const width = ctx.measureText(text).width + paddingX * 2;
                const height = 11 + paddingY * 2;
                // Clamped so the first/last category's pill (wider than its bar) can't print
                // half off the left/right edge of the canvas - shifting x and centerX together
                // keeps the text centered within the (possibly shifted) pill.
                const clampedX = Math.min(Math.max(position.x - width / 2, 0), chart.width - width);
                labels.push({
                    x: clampedX,
                    y: position.y - yOffset - height,
                    centerX: clampedX + width / 2,
                    width,
                    height,
                    text,
                    rgb
                });
            });
        });

        const placed = [];
        labels.forEach((label) => {
            let guard = 0;
            while (guard < 3 && placed.some((other) => rectsOverlap(label, other))) {
                label.y -= label.height + 2;
                guard++;
            }
            placed.push(label);
        });

        placed.forEach((label) => {
            // Flat solid pastel fill, not a gradient: a real CanvasGradient object rendered solid
            // black regardless of its configured colors - consistent with Lightning Web Security
            // altering/breaking that particular canvas API - so every fillStyle here is a plain
            // color string instead, same as the label text below it.
            tracePillPath(ctx, label.x, label.y, label.width, label.height, label.height / 2);
            ctx.fillStyle = pastelize(label.rgb, 0.65);
            ctx.fill();

            ctx.fillStyle = '#3e3e3c';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(label.text, label.centerX, label.y + label.height / 2 + 1);
        });

        ctx.restore();
    }
};

export default class ProspectsChart extends LightningElement {
    @api chartKey;
    @api title;

    chartJsLoaded = false;
    chartJsInitStarted = false;
    chart;
    loadCount = 0;
    _filters = {};
    overallRatioLabel;
    _lastChartData;
    _resizeHandler;
    _resizeTimeout;
    _rawSeries = [];

    // Drill-down modal state - click a bar/point to see the actual Lead__c records behind it.
    drillDownOpen = false;
    drillDownLoading = false;
    drillDownError = false;
    downloadingChart = false;
    drillDownTitle = '';
    drillDownSearchTerm = '';
    drillDownPage = 1;
    _drillDownRecords = [];
    _drillDownRequestId = 0;

    @api
    get filters() {
        return this._filters;
    }

    set filters(value) {
        this._filters = value || {};
        this.loadAndRender();
    }

    disconnectedCallback() {
        if (this.chart) {
            this.chart.destroy();
            this.chart = undefined;
        }
        if (this._resizeHandler) {
            window.removeEventListener('resize', this._resizeHandler);
        }
        window.clearTimeout(this._resizeTimeout);
    }

    renderedCallback() {
        if (this.chartJsInitStarted) {
            return;
        }
        this.chartJsInitStarted = true;
        loadScript(this, CHART_JS)
            .then(() => {
                this.chartJsLoaded = true;
                this.loadAndRender();
            })
            .catch(() => {
                /* Chart.js failed to load; chart simply won't render. */
            });

        // responsive:true (see renderChart) needs ResizeObserver, which Lightning Web Security
        // doesn't expose, so the canvas is manually sized once per render instead - meaning it
        // stays stuck at whatever size it was when data last loaded even if the surrounding layout
        // later changes size (browser zoom, window resize), causing legends/axis labels computed
        // for the old size to overflow or clip against the new one. A plain window resize listener
        // (which also fires on zoom-level changes, unlike ResizeObserver) re-measures the container
        // and rebuilds the chart from the last-loaded data - no extra Apex call needed - so it
        // actually adapts instead of drifting out of sync with its container.
        this._resizeHandler = () => {
            window.clearTimeout(this._resizeTimeout);
            this._resizeTimeout = window.setTimeout(() => {
                if (this._lastChartData) {
                    this.renderChart(this._lastChartData);
                }
            }, 150);
        };
        window.addEventListener('resize', this._resizeHandler);
    }

    loadAndRender() {
        if (!this.chartJsLoaded || !this.chartKey) {
            return;
        }
        this.loadCount += 1;
        const requestId = this.loadCount;
        getChartData({ chartKey: this.chartKey, filtersJson: JSON.stringify(this._filters || {}) })
            .then((data) => {
                if (requestId !== this.loadCount) {
                    return;
                }
                this._lastChartData = data;
                this.renderChart(data);
            })
            .catch(() => {
                /* Swallow; chart simply won't update for this request. */
            });
    }

    renderChart(data) {
        const canvas = this.template.querySelector('canvas');
        if (!canvas || typeof window.Chart === 'undefined' || !data || !data.series || !data.labels) {
            return;
        }
        // Legend click builds an additive selection set (like the filter dropdowns' multi-select -
        // click more legend items to add them to what's shown, click a selected one again to remove
        // it), reset fresh on every reload so a stale index from a previous dataset shape can't
        // leak in. See the legend.onClick handler below for how this set drives visibility.
        this._legendSelectedIndexes = new Set();

        const rawSeries = data.series;
        // Kept for the click-to-drill-down handler below, which needs to map a clicked
        // dataset/point back to which series label and period it belongs to - the same shape
        // getDrillDownRecords expects, independent of however many derived datasets (the ratio
        // line, the trend line) renderChart adds on top of these.
        this._rawSeries = rawSeries;
        this._periodLabels = data.labels;
        // Every chart here is defined as either "Prospect" plus one narrower subset count (the
        // "X to Y Ratio" charts - exactly 2 series), or Prospect Trend's 3-way breakdown (no
        // natural ratio between 3 counts). For the 2-series case, add a derived ratio line -
        // narrower/broader, e.g. Evaluation/Prospect - on its own 0-100% axis, the same
        // second-count-over-first-count relationship each of these charts is named after.
        const hasRatio = rawSeries.length === 2;

        const datasets = rawSeries.map((s, index) => {
            // Prospect Trend (3 series, no ratio) keeps its original look: last series as a
            // trend line. The 2-series ratio charts render both raw counts as bars instead - the
            // ratio line added below takes over the "line" role for those.
            const isTrendLine = !hasRatio && index === rawSeries.length - 1 && rawSeries.length > 1;
            const color = PALETTE[index % PALETTE.length];
            return {
                type: isTrendLine ? 'line' : 'bar',
                label: s.label,
                data: s.data,
                backgroundColor: color,
                borderColor: color,
                fill: false,
                tension: 0.3,
                yAxisID: 'y'
            };
        });

        let ratioData;
        if (hasRatio) {
            const base = rawSeries[0].data;
            const part = rawSeries[1].data;
            ratioData = base.map((b, i) => (b ? Math.round((part[i] / b) * 100) : 0));
            datasets.push({
                type: 'line',
                label: rawSeries[1].label + ' Ratio',
                data: ratioData,
                borderColor: RATIO_COLOR,
                backgroundColor: RATIO_COLOR,
                fill: false,
                tension: 0.3,
                yAxisID: 'ratio',
                isRatio: true
            });

            const totalBase = base.reduce((sum, v) => sum + v, 0);
            const totalPart = part.reduce((sum, v) => sum + v, 0);
            const overallPct = totalBase ? Math.round((totalPart / totalBase) * 100) : 0;
            this.overallRatioLabel = 'Overall ' + rawSeries[1].label + ': ' + overallPct + '%';
        } else {
            this.overallRatioLabel = undefined;
        }

        // LWC can recreate this component instance across re-renders without our own `this.chart`
        // reference surviving, while Chart.js's internal canvas registry still remembers the old
        // chart. Always defer to Chart.js's own registry and destroy-then-recreate.
        const existingChart = window.Chart.getChart(canvas);
        if (existingChart) {
            existingChart.destroy();
        }

        // responsive:true requires ResizeObserver, which Lightning Web Security doesn't expose to
        // component code, so size the canvas explicitly instead. The canvas's drawing buffer is
        // set to CSS size * devicePixelRatio (with devicePixelRatio passed to Chart.js below so it
        // scales its own drawing to match) - setting canvas.width/height directly to the CSS pixel
        // size, as before, left the buffer at 1x resolution on any display denser than that,
        // rendering every label (ours and Chart.js's own) soft/blurry rather than crisp.
        const container = this.template.querySelector('.chart-container');
        const cssWidth = (container && container.clientWidth) || 360;
        const cssHeight = (container && container.clientHeight) || 360;
        const dpr = window.devicePixelRatio || 1;
        canvas.style.width = cssWidth + 'px';
        canvas.style.height = cssHeight + 'px';
        canvas.width = cssWidth * dpr;
        canvas.height = cssHeight * dpr;

        const scales = {
            y: { beginAtZero: true, position: 'left' }
        };
        if (hasRatio) {
            // Ratio can exceed 100%: a chart's two series may come from independent
            // actual-milestone-date counts rather than a strict subset/superset pair (e.g. very few
            // Evaluations against many more Conversions in the same quarter, since a lead evaluated
            // in one quarter can convert in another). This axis auto-scales to its own ratio data,
            // independently of the counts axis on the left, rounding up to the next 10 above the
            // highest ratio value seen (100 as a floor) - an ordinary <=100% chart keeps its
            // familiar 0-100% axis unchanged.
            const ratioMaxValue = ratioData.reduce((max, v) => Math.max(max, v), 0);
            const ratioAxisMax = Math.max(100, Math.ceil(ratioMaxValue / 10) * 10);
            scales.ratio = {
                beginAtZero: true,
                max: ratioAxisMax,
                position: 'right',
                grid: { drawOnChartArea: false },
                ticks: { callback: (v) => v + '%' }
            };
        }

        this.chart = new window.Chart(canvas, {
            type: 'bar',
            data: { labels: data.labels, datasets },
            options: {
                responsive: false,
                devicePixelRatio: dpr,
                // Top padding must clear a pill drawn *above* a point that can legitimately sit at
                // the very top of the plot area - the ratio axis's own max (see above), so a value
                // sitting at that max has zero headroom above it otherwise - plus room for the
                // collision resolver in the valueLabels plugin, which stacks colliding pills upward
                // on a dense chart. Left/right padding guards the first/last category's pill, which
                // is wider than its bar and can otherwise print half off the edge of the canvas.
                layout: { padding: { top: 100, left: 24, right: 24, bottom: 14 } },
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: { boxWidth: 12, font: { size: 10 } },
                        // Additive selection, not Chart.js's default "toggle only the clicked
                        // series": clicking a legend item ADDS it to a selection set and shows only
                        // what's in that set (hiding everything else) - click another item and it
                        // joins the set too, so both stay visible together; click a selected item
                        // again to remove it from the set. An empty set (nothing ever clicked, or
                        // the last selected item just got removed) means "show everything," which is
                        // both the starting state and where clicking back down to zero lands you.
                        // (An earlier version toggled every non-clicked series' hidden flag per
                        // click with no memory of a selection - that flips a series that was already
                        // hidden from a previous click back on/off inconsistently, which is exactly
                        // the bug reported: clicking Opportunity then Evaluation should show both
                        // together, but the flag-flipping version left Evaluation hidden and only
                        // Ratio visible instead.)
                        onClick: (nativeEvent, legendItem, legend) => {
                            const chart = legend.chart;
                            const index = legendItem.datasetIndex;
                            const selected = this._legendSelectedIndexes;
                            if (selected.has(index)) {
                                selected.delete(index);
                            } else {
                                selected.add(index);
                            }
                            chart.data.datasets.forEach((dataset, i) => {
                                chart.getDatasetMeta(i).hidden = selected.size > 0 && !selected.has(i);
                            });
                            chart.update();
                        }
                    }
                },
                scales,
                // Require the cursor to be geometrically over an element's own bar/point rather
                // than Chart.js's default "nearest" matching, which on a dense chart like this one
                // (many categories, multiple bars/a line sharing each category slot) can attribute
                // a hover/click near one bar to its neighbor instead - exactly the mismatch reported
                // against this chart (hovering the 2023-Q2 bar showed the 2023-Q3 tooltip). This
                // applies to both the built-in tooltip and the onClick handler below, since both
                // read from the same interaction settings.
                interaction: { mode: 'nearest', intersect: true },
                onClick: (nativeEvent, elements) => this.handleChartClick(elements),
                onHover: (nativeEvent, elements) => {
                    nativeEvent.native.target.style.cursor = elements.length ? 'pointer' : 'default';
                }
            },
            plugins: [VALUE_LABEL_PLUGIN]
        });
        // Forces Chart.js to fully recompute its internal scale/element geometry against the
        // canvas's actual current on-screen size, rather than whatever it inferred at construction
        // time - defends against any residual mismatch from this component's manual canvas sizing
        // (responsive:true, which would normally keep this in sync automatically, isn't usable here
        // since Lightning Web Security doesn't expose ResizeObserver - see renderedCallback).
        this.chart.resize();
    }

    // ------------------------------------------------------------------
    //  Drill-down: click a bar/point to see the actual records behind it
    // ------------------------------------------------------------------

    // Only the bar/line datasets that map 1:1 to a real series (rawSeries) are click-able - the
    // derived ratio line/trend line Chart.js draws on top isn't a series the Apex layer knows
    // about, so a click landing on one of those (datasetIndex >= rawSeries.length) is ignored.
    handleChartClick(elements) {
        if (!elements || !elements.length || this.drillDownLoading) {
            return;
        }
        const { datasetIndex, index } = elements[0];
        const rawSeries = this._rawSeries || [];
        if (datasetIndex >= rawSeries.length) {
            return;
        }
        const seriesLabel = rawSeries[datasetIndex].label;
        const period = (this._periodLabels || [])[index];
        const value = rawSeries[datasetIndex].data[index];
        if (!period || !value) {
            return;
        }
        this.openDrillDown(seriesLabel, period, value);
    }

    openDrillDown(seriesLabel, period, value) {
        this.drillDownOpen = true;
        this.drillDownLoading = true;
        this.drillDownError = false;
        this.drillDownSearchTerm = '';
        this.drillDownPage = 1;
        this._drillDownRecords = [];
        this._drillDownSeriesLabel = seriesLabel;
        this._drillDownPeriod = period;
        this.drillDownTitle = this.title + ' — ' + seriesLabel + ' — ' + period + ' (' + value + ')';

        this._drillDownRequestId += 1;
        const requestId = this._drillDownRequestId;
        getDrillDownRecords({
            chartKey: this.chartKey,
            seriesLabel,
            period,
            filtersJson: JSON.stringify(this._filters || {})
        })
            .then((records) => {
                if (requestId !== this._drillDownRequestId) {
                    return;
                }
                this._drillDownRecords = records || [];
                this.drillDownLoading = false;
            })
            .catch(() => {
                if (requestId !== this._drillDownRequestId) {
                    return;
                }
                this.drillDownError = true;
                this.drillDownLoading = false;
            });
    }

    closeDrillDown() {
        this.drillDownOpen = false;
        // Invalidate any still-in-flight request so a slow response can't pop the modal back open
        // (or overwrite the next click's data) after the user has already closed it.
        this._drillDownRequestId += 1;
        this._drillDownRecords = [];
    }

    handleDrillDownSearchInput(event) {
        this.drillDownSearchTerm = event.target.value;
        this.drillDownPage = 1;
    }

    // Exports every row matching the current search (not just the current page) - the same set
    // the "X-Y of Z" count reflects, so what downloads always matches what's on screen. See
    // spreadsheetExport.js for why this is SpreadsheetML rather than a true .xlsx.
    handleDrillDownDownloadExcel() {
        const records = this.drillDownFilteredRecords;
        if (!records.length) {
            return;
        }
        const showVia = this.showMatchedViaColumn;
        const headers = [
            'Name',
            'Owner',
            'Zone',
            'Country',
            'Stage',
            'SAP Code',
            'CE/CIS Rating',
            'Phakic Rating',
            'Actual Appointments Week',
            'Converted Date',
            'Unqualified Date'
        ];
        if (showVia) {
            headers.push('Matched Via');
        }
        headers.push('Created');

        const rows = records.map((r) => {
            const cells = [
                r.name,
                r.ownerName,
                r.zone,
                r.country,
                r.stage,
                r.sapCode,
                r.ceCisRating,
                r.phakicRating,
                r.actualAppointmentsWeek,
                r.convertedDate,
                r.unqualifiedDate
            ];
            if (showVia) {
                cells.push(r.matchedVia);
            }
            cells.push(r.createdDate);
            return cells;
        });

        const xml = buildSpreadsheetXml(this._drillDownSeriesLabel, headers, rows);
        const fileNameParts = [this.title, this._drillDownSeriesLabel, this._drillDownPeriod];
        const fileName = fileNameParts.filter(Boolean).map(sanitizeFileNamePart).join('_') + '.xls';
        downloadSpreadsheet(xml, fileName);
    }

    // Exports the WHOLE chart's data - every period, every series, exactly as plotted, PLUS every
    // underlying record behind those numbers - so the customer can deep dive without clicking each
    // bar individually. Two tabs: "Summary" (the same grid the chart plots: one row per period, one
    // column per series) and "Details" (one row per record across every period/series).
    get downloadChartDisabled() {
        return !this._lastChartData || !this._lastChartData.labels || !this._lastChartData.labels.length || this.downloadingChart;
    }

    handleDownloadChartExcel() {
        const data = this._lastChartData;
        if (!data || !data.labels || !data.labels.length || this.downloadingChart) {
            return;
        }
        this.downloadingChart = true;

        const summaryHeaders = ['Period', ...data.series.map((s) => s.label)];
        const summaryRows = data.labels.map((label, i) => [label, ...data.series.map((s) => s.data[i])]);

        getChartFullDetail({ chartKey: this.chartKey, filtersJson: JSON.stringify(this._filters || {}) })
            .then((records) => {
                const detailHeaders = [
                    'Series',
                    'Period',
                    'Name',
                    'Owner',
                    'Zone',
                    'Country',
                    'Stage',
                    'SAP Code',
                    'CE/CIS Rating',
                    'Phakic Rating',
                    'Actual Appointments Week',
                    'Converted Date',
                    'Unqualified Date',
                    'Matched Via',
                    'Created'
                ];
                const detailRows = (records || []).map((r) => [
                    r.seriesLabel,
                    r.period,
                    r.name,
                    r.ownerName,
                    r.zone,
                    r.country,
                    r.stage,
                    r.sapCode,
                    r.ceCisRating,
                    r.phakicRating,
                    r.actualAppointmentsWeek,
                    r.convertedDate,
                    r.unqualifiedDate,
                    r.matchedVia,
                    r.createdDate
                ]);

                const xml = buildWorkbookXml([
                    { name: 'Summary', headers: summaryHeaders, rows: summaryRows },
                    { name: 'Details', headers: detailHeaders, rows: detailRows }
                ]);
                const fileName = sanitizeFileNamePart(this.title) + '.xls';
                downloadSpreadsheet(xml, fileName);
            })
            .catch(() => {
                // Detail lookup failed - still give the user the summary grid rather than nothing.
                const xml = buildSpreadsheetXml(this.title, summaryHeaders, summaryRows);
                const fileName = sanitizeFileNamePart(this.title) + '.xls';
                downloadSpreadsheet(xml, fileName);
            })
            .finally(() => {
                this.downloadingChart = false;
            });
    }

    get showMatchedViaColumn() {
        const vias = new Set(this._drillDownRecords.map((r) => r.matchedVia));
        return vias.size > 1;
    }

    get drillDownFilteredRecords() {
        const term = (this.drillDownSearchTerm || '').trim().toLowerCase();
        if (!term) {
            return this._drillDownRecords;
        }
        return this._drillDownRecords.filter((r) => {
            return (
                (r.name || '').toLowerCase().includes(term) ||
                (r.ownerName || '').toLowerCase().includes(term) ||
                (r.zone || '').toLowerCase().includes(term) ||
                (r.country || '').toLowerCase().includes(term) ||
                (r.stage || '').toLowerCase().includes(term) ||
                (r.sapCode || '').toLowerCase().includes(term) ||
                (r.matchedVia || '').toLowerCase().includes(term)
            );
        });
    }

    get drillDownTotalCount() {
        return this.drillDownFilteredRecords.length;
    }

    get drillDownTotalPages() {
        return Math.max(1, Math.ceil(this.drillDownTotalCount / DRILL_DOWN_PAGE_SIZE));
    }

    get drillDownPagedRecords() {
        const start = (this.drillDownPage - 1) * DRILL_DOWN_PAGE_SIZE;
        return this.drillDownFilteredRecords.slice(start, start + DRILL_DOWN_PAGE_SIZE).map((r) => ({
            ...r,
            recordUrl: '/lightning/r/Lead__c/' + r.recordId + '/view'
        }));
    }

    get drillDownHasResults() {
        return !this.drillDownLoading && !this.drillDownError && this.drillDownTotalCount > 0;
    }

    get drillDownDownloadDisabled() {
        return !this.drillDownHasResults;
    }

    get drillDownHasNoResults() {
        return !this.drillDownLoading && !this.drillDownError && this._drillDownRecords.length > 0 && this.drillDownTotalCount === 0;
    }

    get drillDownIsEmpty() {
        return !this.drillDownLoading && !this.drillDownError && this._drillDownRecords.length === 0;
    }

    get drillDownPageLabel() {
        if (this.drillDownTotalCount === 0) {
            return '';
        }
        const start = (this.drillDownPage - 1) * DRILL_DOWN_PAGE_SIZE + 1;
        const end = Math.min(this.drillDownPage * DRILL_DOWN_PAGE_SIZE, this.drillDownTotalCount);
        return start + '-' + end + ' of ' + this.drillDownTotalCount;
    }

    get drillDownPrevDisabled() {
        return this.drillDownPage <= 1;
    }

    get drillDownNextDisabled() {
        return this.drillDownPage >= this.drillDownTotalPages;
    }

    handleDrillDownPrevPage() {
        if (this.drillDownPage > 1) {
            this.drillDownPage -= 1;
        }
    }

    handleDrillDownNextPage() {
        if (this.drillDownPage < this.drillDownTotalPages) {
            this.drillDownPage += 1;
        }
    }
}