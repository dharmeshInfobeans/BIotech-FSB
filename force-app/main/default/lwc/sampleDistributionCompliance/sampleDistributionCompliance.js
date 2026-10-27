import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getComplianceRows from '@salesforce/apex/SampleDistributionComplianceController.getComplianceRows';

const MISSING = 'Not recorded';
const DONUT_SEGMENTS = 8;
const clean = value => (!value || String(value).trim() === '-' ? '' : String(value).trim());
const label = value => clean(value) || MISSING;
const percentage = (part, whole) => whole ? Math.round((part / whole) * 100) : 0;

export default class SampleDistributionCompliance extends NavigationMixin(LightningElement) {
    rows = [];
    error;
    zone = '';
    division = '';
    status = '';
    search = '';
    searchTimer;

    @wire(getComplianceRows)
    wiredRows({ data, error }) {
        if (data) {
            this.rows = data;
            this.error = undefined;
        } else if (error) {
            this.error = 'Unable to load compliance data.';
        }
    }

    disconnectedCallback() {
        clearTimeout(this.searchTimer);
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get filtered() {
        const needle = this.search.toLowerCase();
        return this.rows.filter(row => (
            (!this.zone || label(row.zone) === this.zone)
            && (!this.division || label(row.division) === this.division)
            && (!this.status || this.feedbackBucket(row.feedbackStatus) === this.status)
            && (!needle || `${row.accountName || ''} ${row.product || ''}`.toLowerCase().includes(needle))
        ));
    }

    get zoneOptions() {
        return this.options('zone');
    }

    get divisionOptions() {
        return this.options('division');
    }

    get statusOptions() {
        return [{ label: 'All feedback statuses', value: '' }, ...['Approved', 'Pending', MISSING].map(value => ({ label: value, value }))];
    }

    options(field) {
        const values = [...new Set(this.rows.map(row => label(row[field])))].sort();
        return [{ label: `All ${field}s`, value: '' }, ...values.map(value => ({ label: value, value }))];
    }

    get kpis() {
        const rows = this.filtered;
        const total = rows.length;
        const feedback = rows.filter(row => clean(row.feedbackStatus)).length;
        const trace = rows.filter(row => clean(row.batchNumber) && clean(row.serialNumber)).length;
        return [
            this.kpi('Samples Distributed', rows.reduce((sum, row) => sum + (Number(row.quantity) || 0), 0)),
            this.kpi('Accounts Reached', new Set(rows.map(row => row.accountId).filter(Boolean)).size),
            this.kpi('Products in Circulation', new Set(rows.map(row => clean(row.product)).filter(Boolean)).size),
            this.kpi('Feedback Recorded', `${feedback} / ${total}`),
            this.kpi('Traceability Captured', `${trace} / ${total}`)
        ];
    }

    kpi(labelText, value) {
        return { label: labelText, value: Number.isFinite(value) ? value.toLocaleString() : value };
    }

    get gauges() {
        const rows = this.filtered;
        const total = rows.length;
        const feedback = rows.filter(row => clean(row.feedbackStatus)).length;
        const trace = rows.filter(row => clean(row.batchNumber) && clean(row.serialNumber)).length;
        return [this.gauge('Feedback compliance', feedback, total), this.gauge('Traceability compliance', trace, total)];
    }

    gauge(title, count, total) {
        const value = percentage(count, total);
        return { title, value, detail: `${count} of ${total} records`, style: `--gauge-value:${value}%` };
    }

    get callout() {
        const [feedback, trace] = this.gauges;
        return `Feedback is ${feedback.value}% complete and traceability is ${trace.value}% complete for the selected population.`;
    }

    feedbackBucket(value) {
        const normalized = clean(value);
        return normalized === 'Approved' ? 'Approved' : normalized ? 'Pending' : MISSING;
    }

    get productBars() {
        return this.groupBars(this.filtered, row => label(row.product), row => Number(row.quantity) || 0);
    }

    get recipientBars() {
        return this.groupBars(this.filtered, row => label(row.accountName), row => Number(row.quantity) || 0);
    }

    get zoneBars() {
        return this.groupBars(this.filtered, row => label(row.zone), row => Number(row.quantity) || 0);
    }

    get feedbackMix() {
        return this.groupDonut(this.filtered, row => this.feedbackBucket(row.feedbackStatus));
    }

    get divisionMix() {
        return this.groupDonut(this.filtered, row => label(row.division));
    }

    groupBars(rows, group, measure) {
        const sums = new Map();
        rows.forEach(row => sums.set(group(row), (sums.get(group(row)) || 0) + measure(row)));
        const max = Math.max(...sums.values(), 1);
        return [...sums.entries()]
            .sort((left, right) => right[1] - left[1])
            .slice(0, DONUT_SEGMENTS)
            .map(([name, value]) => ({ name, value: value.toLocaleString(), style: `width:${Math.round((value / max) * 100)}%` }));
    }

    groupDonut(rows, group) {
        const sums = new Map();
        rows.forEach(row => sums.set(group(row), (sums.get(group(row)) || 0) + 1));
        const total = rows.length;
        let cumulative = 0;
        const segments = [...sums.entries()]
            .sort((left, right) => right[1] - left[1])
            .slice(0, DONUT_SEGMENTS)
            .map(([name, value], index) => {
                cumulative += percentage(value, total);
                return {
                    name,
                    value: value.toLocaleString(),
                    percentage: percentage(value, total),
                    style: `--donut-swatch:var(--donut-color-${index + 1})`,
                    key: `${name}-${index}`
                };
            });
        const segmentStyles = Array.from({ length: DONUT_SEGMENTS }, (_, index) => {
            const segment = segments[index];
            return `--segment-${index + 1}:${segment ? segments.slice(0, index + 1).reduce((sum, item) => sum + item.percentage, 0) : cumulative}%`;
        });
        const detail = total ? `${total.toLocaleString()} records` : 'No records';
        const ariaLabel = segments.length
            ? `Distribution: ${segments.map(segment => `${segment.name} ${segment.percentage}%`).join(', ')}`
            : 'No records in this distribution';
        return { segments, total: detail, style: segmentStyles.join(';'), ariaLabel };
    }

    get outstanding() {
        return this.filtered
            .filter(row => !clean(row.feedbackStatus))
            .slice(0, 10)
            .map(row => ({ ...row, displayStatus: MISSING, hasAccount: Boolean(row.accountId), lineItemLabel: 'Open sample line item' }));
    }

    get traceable() {
        return this.filtered
            .filter(row => clean(row.batchNumber) && clean(row.serialNumber))
            .slice(0, 10)
            .map(row => ({ ...row, displayStatus: this.feedbackBucket(row.feedbackStatus), hasAccount: Boolean(row.accountId), lineItemLabel: 'Open sample line item' }));
    }

    get emptyMessage() {
        return this.hasRows ? 'No records match the active filters.' : 'No sample records are available to you.';
    }

    handleFilter(event) {
        this[event.target.name] = event.target.value;
    }

    handleSearch(event) {
        clearTimeout(this.searchTimer);
        const value = event.target.value;
        this.searchTimer = setTimeout(() => {
            this.search = value;
        }, 250);
    }

    resetFilters() {
        this.zone = '';
        this.division = '';
        this.status = '';
        this.search = '';
        const search = this.template.querySelector('[data-id="search"]');
        if (search) {
            search.value = '';
        }
    }

    handleNavigate(event) {
        const recordId = event.currentTarget.dataset.recordId;
        const objectApiName = event.currentTarget.dataset.objectApiName;
        if (!recordId || !objectApiName) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName,
                actionName: 'view'
            }
        });
    }
}