import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import CHART_JS from '@salesforce/resourceUrl/chartJs';
import getProductFamilyStageBreakdown from '@salesforce/apex/ProspectsDashboardController.getProductFamilyStageBreakdown';
import getProductFamilyFullDetail from '@salesforce/apex/ProspectsDashboardController.getProductFamilyFullDetail';
import { buildSpreadsheetXml, buildWorkbookXml, sanitizeFileNamePart, downloadSpreadsheet } from 'c/spreadsheetExport';

const CHART_TITLE = 'Product Family — Prospects by Stage';

// Fixed colors for the stage values this org actually uses, so a given stage always reads as the
// same color across sessions/screens rather than shifting depending on which stages happen to be
// present in the current filtered data. Won/Lost/Unqualified/No Stage get meaningful colors
// (green/red/grey/light grey); anything else cycles through FALLBACK_PALETTE, so a future new
// stage value still renders distinctly instead of breaking.
const STAGE_COLORS = {
    Won: '#04844b',
    Lost: '#c23934',
    Unqualified: '#706e6b',
    'No Stage': '#c9c7c5',
    Appointments: '#0176d3',
    Presentation: '#8657e4',
    'Product Demo': '#ff9f40',
    Evaluations: '#06a59a',
    Commercialization: '#ffb400',
    Upgrade: '#e6550e',
    Converted: '#756bb1'
};
const FALLBACK_PALETTE = ['#8657e4', '#ff9f40', '#0176d3', '#04844b', '#c23934', '#06a59a'];

function colorForStage(stage, fallbackIndex) {
    return STAGE_COLORS[stage] || FALLBACK_PALETTE[fallbackIndex % FALLBACK_PALETTE.length];
}

export default class ProspectsProductFamilyChart extends LightningElement {
    chartJsLoaded = false;
    chartJsInitStarted = false;
    chart;
    loadCount = 0;
    _filters = {};
    _resizeHandler;
    _resizeTimeout;
    _lastChartData;
    downloadingChart = false;

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

        // Same manual-resize approach as prospectsChart, for the same reason: Lightning Web
        // Security doesn't expose ResizeObserver, so responsive:true can't keep the canvas in
        // sync with its container on its own.
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
        if (!this.chartJsLoaded) {
            return;
        }
        this.loadCount += 1;
        const requestId = this.loadCount;
        getProductFamilyStageBreakdown({ filtersJson: JSON.stringify(this._filters || {}) })
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

        const datasets = data.series.map((s, index) => ({
            label: s.label,
            data: s.data,
            backgroundColor: colorForStage(s.label, index)
        }));

        const existingChart = window.Chart.getChart(canvas);
        if (existingChart) {
            existingChart.destroy();
        }

        // Same manual devicePixelRatio-aware sizing as prospectsChart - see that component for
        // the full explanation of why (no ResizeObserver under Lightning Web Security).
        const container = this.template.querySelector('.chart-container');
        const cssWidth = (container && container.clientWidth) || 360;
        const cssHeight = (container && container.clientHeight) || 360;
        const dpr = window.devicePixelRatio || 1;
        canvas.style.width = cssWidth + 'px';
        canvas.style.height = cssHeight + 'px';
        canvas.width = cssWidth * dpr;
        canvas.height = cssHeight * dpr;

        this.chart = new window.Chart(canvas, {
            type: 'bar',
            data: { labels: data.labels, datasets },
            options: {
                responsive: false,
                devicePixelRatio: dpr,
                layout: { padding: { top: 10, left: 12, right: 12, bottom: 10 } },
                plugins: {
                    legend: { position: 'bottom', labels: { boxWidth: 12, font: { size: 10 } } },
                    tooltip: { mode: 'index', intersect: false }
                },
                // Stacked, not grouped: with up to 11 stage values, side-by-side bars per family
                // would be too thin to read. A stacked bar keeps each family's total height
                // meaningful (see it at a glance) while still breaking it down by stage color.
                scales: {
                    x: { stacked: true, ticks: { autoSkip: false, maxRotation: 60, minRotation: 30, font: { size: 9 } } },
                    y: { stacked: true, beginAtZero: true }
                },
                interaction: { mode: 'nearest', intersect: true }
            }
        });
        this.chart.resize();
    }

    // Exports the whole grid - every product family, every stage - exactly as plotted, PLUS every
    // underlying record behind those numbers, so the customer can deep dive without clicking each
    // bar individually. Two tabs: "Summary" (the plotted grid) and "Details" (one row per record).
    // See spreadsheetExport.js for why this is SpreadsheetML rather than a true .xlsx.
    get downloadChartDisabled() {
        return !this._lastChartData || !this._lastChartData.labels || !this._lastChartData.labels.length || this.downloadingChart;
    }

    handleDownloadChartExcel() {
        const data = this._lastChartData;
        if (!data || !data.labels || !data.labels.length || this.downloadingChart) {
            return;
        }
        this.downloadingChart = true;

        const summaryHeaders = ['Product Family', ...data.series.map((s) => s.label)];
        const summaryRows = data.labels.map((label, i) => [label, ...data.series.map((s) => s.data[i])]);

        getProductFamilyFullDetail({ filtersJson: JSON.stringify(this._filters || {}) })
            .then((records) => {
                const detailHeaders = [
                    'Product Family',
                    'Stage',
                    'Name',
                    'Owner',
                    'Zone',
                    'Country',
                    'SAP Code',
                    'CE/CIS Rating',
                    'Phakic Rating',
                    'Actual Appointments Week',
                    'Converted Date',
                    'Unqualified Date',
                    'Created'
                ];
                const detailRows = (records || []).map((r) => [
                    r.matchedVia,
                    r.seriesLabel,
                    r.name,
                    r.ownerName,
                    r.zone,
                    r.country,
                    r.sapCode,
                    r.ceCisRating,
                    r.phakicRating,
                    r.actualAppointmentsWeek,
                    r.convertedDate,
                    r.unqualifiedDate,
                    r.createdDate
                ]);

                const xml = buildWorkbookXml([
                    { name: 'Summary', headers: summaryHeaders, rows: summaryRows },
                    { name: 'Details', headers: detailHeaders, rows: detailRows }
                ]);
                const fileName = sanitizeFileNamePart(CHART_TITLE) + '.xls';
                downloadSpreadsheet(xml, fileName);
            })
            .catch(() => {
                const xml = buildSpreadsheetXml(CHART_TITLE, summaryHeaders, summaryRows);
                const fileName = sanitizeFileNamePart(CHART_TITLE) + '.xls';
                downloadSpreadsheet(xml, fileName);
            })
            .finally(() => {
                this.downloadingChart = false;
            });
    }
}