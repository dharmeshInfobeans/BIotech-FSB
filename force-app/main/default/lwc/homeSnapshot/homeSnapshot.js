import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import CHART_JS from '@salesforce/resourceUrl/chartJs';
import getHomeSnapshot from '@salesforce/apex/HomeSnapshotController.getHomeSnapshot';

const QUARTER_OPTIONS = [
    { label: 'Q1', value: 'Q1' },
    { label: 'Q2', value: 'Q2' },
    { label: 'Q3', value: 'Q3' },
    { label: 'Q4', value: 'Q4' }
];
const EARLIEST_YEAR = 2018;
const PALETTE = ['#8657e4', '#ff9f40', '#0176d3', '#04844b', '#c23934', '#06a59a'];

// Ordered so each dashboard tile's card number/position is stable regardless of which ones a
// given profile can see - explicit order requested: Pro-Active Pipeline, Campaign Metrics &
// Target Tracking, Opportunity Overview, Sample Request Dashboard, Opportunity History Tracking.
const DASHBOARD_TILE_DEFS = [
    { key: 'proactivePipeline', idKey: null, title: 'Proactive Pipeline', subtitle: 'Potential and conversion' },
    { key: 'campaignMetrics', idKey: 'campaignMetricsId', title: 'Campaign Metrics & Target Tracking', subtitle: 'Campaign performance vs target' },
    { key: 'opportunityOverview', idKey: 'opportunityOverviewId', title: 'Opportunity Overview', subtitle: 'Stage, value, closure and aging' },
    { key: 'sampleRequestDashboard', idKey: 'sampleRequestDashboardId', title: 'Sample Request Dashboard', subtitle: 'Requests and fulfillment' },
    { key: 'opportunityHistoryTracking', idKey: 'opportunityHistoryTrackingId', title: 'Opportunity History Tracking', subtitle: 'Changes and movement over time' }
];

export default class HomeSnapshot extends NavigationMixin(LightningElement) {
    chartJsLoaded = false;
    chartJsInitStarted = false;
    loadCount = 0;
    isLoading = true;
    hasError = false;
    snapshot;
    selectedYear = new Date().getFullYear();
    selectedQuarter;
    _generationChart;
    _pipelineChart;

    get yearOptions() {
        const options = [];
        for (let y = new Date().getFullYear(); y >= EARLIEST_YEAR; y--) {
            options.push({ label: String(y), value: String(y) });
        }
        return options;
    }

    get quarterOptions() {
        return QUARTER_OPTIONS;
    }

    get kpiTiles() {
        if (!this.snapshot) {
            return [];
        }
        const t = this.snapshot.tiles;
        return [
            { key: 'prospects', label: 'Prospects Generated', value: this.formatNumber(t.prospectsGenerated), cssClass: 'tile tile-info' },
            { key: 'lost', label: 'Prospects Lost (Unqualified)', value: this.formatNumber(t.prospectsLost), cssClass: 'tile tile-danger' },
            { key: 'revenue', label: 'Opportunity Revenue (Won)', value: this.formatCurrency(t.opportunityRevenueWon), cssClass: 'tile tile-success' },
            { key: 'pipeline', label: 'Opportunity Pipeline', value: this.formatCurrency(t.opportunityPipeline), cssClass: 'tile tile-warning' },
            { key: 'samples', label: 'Samples Issued', value: this.formatNumber(t.samplesRequested), cssClass: 'tile tile-total' }
        ];
    }

    get dashboardTiles() {
        if (!this.snapshot) {
            return [];
        }
        const access = this.snapshot.dashboardAccess;
        return DASHBOARD_TILE_DEFS.filter((def) => access[def.key])
            .map((def, index) => ({
                key: def.key,
                number: index + 1,
                title: def.title,
                subtitle: def.subtitle,
                recordId: def.idKey ? access[def.idKey] : null
            }));
    }

    get noDashboardTilesVisible() {
        return !this.isLoading && this.dashboardTiles.length === 0;
    }

    get periodLabel() {
        return this.snapshot ? `${this.snapshot.quarter} ${this.snapshot.year}` : '';
    }

    connectedCallback() {
        const now = new Date();
        this.selectedYear = String(now.getFullYear());
        const month = now.getMonth() + 1;
        this.selectedQuarter = month <= 3 ? 'Q1' : month <= 6 ? 'Q2' : month <= 9 ? 'Q3' : 'Q4';
    }

    renderedCallback() {
        if (this.chartJsInitStarted) {
            return;
        }
        this.chartJsInitStarted = true;
        loadScript(this, CHART_JS)
            .then(() => {
                this.chartJsLoaded = true;
                this.loadSnapshot();
            })
            .catch(() => {
                this.hasError = true;
                this.isLoading = false;
            });
    }

    handleYearChange(event) {
        this.selectedYear = event.detail.value;
        this.loadSnapshot();
    }

    handleQuarterChange(event) {
        this.selectedQuarter = event.detail.value;
        this.loadSnapshot();
    }

    loadSnapshot() {
        if (!this.chartJsLoaded) {
            return;
        }
        this.isLoading = true;
        this.hasError = false;
        this.loadCount += 1;
        const requestId = this.loadCount;

        getHomeSnapshot({ year: Number(this.selectedYear), quarter: this.selectedQuarter })
            .then((result) => {
                if (requestId !== this.loadCount) {
                    return;
                }
                this.snapshot = result;
                this.isLoading = false;
                // Chart canvases only exist in the DOM once isLoading flips false and the template
                // re-renders - draw on the next microtask so that's already happened.
                Promise.resolve().then(() => this.renderCharts());
            })
            .catch(() => {
                if (requestId !== this.loadCount) {
                    return;
                }
                this.hasError = true;
                this.isLoading = false;
            });
    }

    renderCharts() {
        this.renderGenerationChart();
        this.renderPipelineChart();
    }

    renderGenerationChart() {
        const canvas = this.template.querySelector('canvas.generation-chart');
        if (!canvas || typeof window.Chart === 'undefined' || !this.snapshot) {
            return;
        }
        const data = this.snapshot.generationByMonth;
        if (this._generationChart) {
            this._generationChart.destroy();
        }
        this.sizeCanvas(canvas);
        this._generationChart = new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: data.labels,
                datasets: data.series.map((s, i) => ({
                    label: s.label,
                    data: s.data,
                    backgroundColor: PALETTE[i % PALETTE.length]
                }))
            },
            options: {
                responsive: false,
                devicePixelRatio: window.devicePixelRatio || 1,
                plugins: { legend: { position: 'bottom', labels: { boxWidth: 12, font: { size: 10 } } } },
                scales: { y: { beginAtZero: true } },
                interaction: { mode: 'nearest', intersect: true }
            }
        });
        this._generationChart.resize();
    }

    renderPipelineChart() {
        const canvas = this.template.querySelector('canvas.pipeline-chart');
        if (!canvas || typeof window.Chart === 'undefined' || !this.snapshot) {
            return;
        }
        const data = this.snapshot.pipelineByStage;
        if (this._pipelineChart) {
            this._pipelineChart.destroy();
        }
        this.sizeCanvas(canvas);
        const series = data.series[0];
        this._pipelineChart = new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: data.labels,
                datasets: [
                    {
                        label: series ? series.label : 'Pipeline Value',
                        data: series ? series.data : [],
                        backgroundColor: (data.labels || []).map((_, i) => PALETTE[i % PALETTE.length])
                    }
                ]
            },
            options: {
                indexAxis: 'y',
                responsive: false,
                devicePixelRatio: window.devicePixelRatio || 1,
                plugins: { legend: { display: false } },
                scales: { x: { beginAtZero: true } },
                interaction: { mode: 'nearest', intersect: true }
            }
        });
        this._pipelineChart.resize();
    }

    sizeCanvas(canvas) {
        const container = canvas.closest('.chart-container');
        const cssWidth = (container && container.clientWidth) || 360;
        const cssHeight = (container && container.clientHeight) || 300;
        const dpr = window.devicePixelRatio || 1;
        canvas.style.width = cssWidth + 'px';
        canvas.style.height = cssHeight + 'px';
        canvas.width = cssWidth * dpr;
        canvas.height = cssHeight * dpr;
    }

    handleDashboardTileClick(event) {
        const recordId = event.currentTarget.dataset.recordId;
        const key = event.currentTarget.dataset.key;
        if (key === 'proactivePipeline') {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: { apiName: 'Prospects_Dashboard' }
            });
            return;
        }
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: 'Dashboard', actionName: 'view' }
        });
    }

    formatNumber(value) {
        return value == null ? '0' : Number(value).toLocaleString();
    }

    formatCurrency(value) {
        if (value == null) {
            return '0';
        }
        return Number(value).toLocaleString(undefined, { maximumFractionDigits: 0 });
    }
}