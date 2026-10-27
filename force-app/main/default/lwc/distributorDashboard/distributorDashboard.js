import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getMyRequests from '@salesforce/apex/DistributorMyRequestsController.getMyRequests';

const STATUS_CLASSES = {
    'Draft':                          'status-pill pill-grey',
    'Submitted':                      'status-pill pill-blue',
    'Under Leadership Review':        'status-pill pill-orange',
    'Under Management Approval':      'status-pill pill-orange',
    'Sent Back':                      'status-pill pill-yellow',
    'On Hold':                        'status-pill pill-yellow',
    'Approved by Leadership':         'status-pill pill-green',
    'Submitted to Regulatory':        'status-pill pill-blue',
    'Under Regulatory Review':        'status-pill pill-orange',
    'Additional Documents Requested': 'status-pill pill-yellow',
    'Pending Customer Response':      'status-pill pill-yellow',
    'Completed':                      'status-pill pill-green',
    'Rejected':                       'status-pill pill-red'
};

const PASSPORT_STAGES = [
    { key: 's', label: 'Sub' },
    { key: 'l', label: 'Lead' },
    { key: 'r', label: 'Reg' },
    { key: 'c', label: 'Cert' },
    { key: 'd', label: 'Done' }
];

const STAGE_IDX = {
    'Distributor Submission':          0,
    'Functional Head Review':          1,
    'Under Leadership Review':         1,
    'Under Management Approval':       1,
    'Approved by Leadership':          1,
    'Sent Back':                       1,
    'On Hold':                         1,
    'Submitted to Regulatory':         2,
    'Under Regulatory Review':         2,
    'Regulatory Processing':           2,
    'Additional Documents Requested':  3,
    'Pending Customer Response':       3,
    'CRM Review':                      3,
    'Certificate Verification':        3,
    'Completed':                       4
};

export default class DistributorDashboard extends NavigationMixin(LightningElement) {
    @track requests = [];
    @track isLoading = true;
    @track error = false;
    @track errorMessage = '';
    @track certDisplayCount = 5;
    @track passportDisplayCount = 10;

    connectedCallback() {
        this.loadRequests();
    }

    loadRequests() {
        this.isLoading = true;
        this.error = false;
        getMyRequests({ statusFilter: 'All' })
            .then(data => {
                this.requests = this.enrichRecords(data);
                this.isLoading = false;
            })
            .catch(err => {
                this.error = true;
                this.errorMessage = (err && err.body && err.body.message)
                    ? err.body.message
                    : 'Unable to load data. Please refresh the page.';
                this.isLoading = false;
            });
    }

    enrichRecords(data) {
        return data.map(rec => {
            const certStatus = this.getCertStatus(rec);
            return {
                ...rec,
                productName: rec.Product__r ? rec.Product__r.Name : '—',
                typeLabel: rec.Request_Type__c === 'Additional Document Request' ? 'Add. Docs' : 'New Reg',
                statusClass: STATUS_CLASSES[rec.Status__c] || 'status-pill pill-grey',
                stamps: this.buildStamps(rec),
                actionReason: this.getActionReason(rec),
                certFromLabel: rec.Certificate_Valid_From__c
                    ? new Date(rec.Certificate_Valid_From__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
                    : '—',
                certToLabel: rec.Certificate_Valid_To__c
                    ? new Date(rec.Certificate_Valid_To__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
                    : '—',
                certStatusLabel: certStatus.label,
                certStatusCls: certStatus.cls
            };
        });
    }

    buildStamps(rec) {
        const idx = STAGE_IDX[rec.Current_Stage__c] ?? 0;
        const isRejected = rec.Status__c === 'Rejected';
        const isCompleted = rec.Status__c === 'Completed';

        return PASSPORT_STAGES.map((stage, i) => {
            let cls = 'pp-stamp';
            let icon = stage.label;

            if (isCompleted) {
                cls += ' pp-stamp-done';
                icon = '✓';
            } else if (isRejected && i === idx) {
                cls += ' pp-stamp-rejected';
                icon = '✕';
            } else if (!isRejected && i < idx) {
                cls += ' pp-stamp-done';
                icon = '✓';
            } else if (i === idx) {
                cls += ' pp-stamp-current';
            }

            const pastConn = isCompleted || (!isRejected && i < idx);
            return {
                key: stage.key + rec.Id,
                cls,
                icon,
                showConn: i < PASSPORT_STAGES.length - 1,
                connCls: pastConn ? 'pp-conn pp-conn-done' : 'pp-conn'
            };
        });
    }

    getActionReason(rec) {
        if (rec.Status__c === 'Sent Back') return 'Sent back — review feedback';
        if (rec.Status__c === 'Pending Customer Response') return 'Response required from you';
        if (rec.Request_Type__c === 'Additional Document Request'
            && !rec.Certificate_Uploaded__c
            && rec.Status__c !== 'Completed'
            && rec.Status__c !== 'Rejected') {
            return 'Certificate upload pending';
        }
        return '';
    }

    getCertStatus(rec) {
        if (!rec.Certificate_Valid_To__c) return { label: '', cls: '' };
        const toDate = new Date(rec.Certificate_Valid_To__c);
        const daysLeft = Math.round((toDate - new Date()) / 86400000);
        if (daysLeft < 0)   return { label: 'Expired', cls: 'cert-pill cert-expired' };
        if (daysLeft <= 90) return { label: 'Expires in ' + daysLeft + 'd', cls: 'cert-pill cert-warning' };
        return { label: 'Valid · ' + daysLeft + 'd left', cls: 'cert-pill cert-valid' };
    }

    handleCardClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/request-detail?id=' + recordId }
        });
    }

    handleNewRegistration() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/registration' }
        });
    }

    get isReady()        { return !this.isLoading && !this.error; }
    get hasPassport()    { return this.requests.length > 0; }
    get hasCertRecords() { return this.certRecords.length > 0; }
    get hasActionItems() { return this.actionItems.length > 0; }
    get actionCount()    { return this.actionItems.length; }

    get kpiCards() {
        const total       = this.requests.length;
        const inProgress  = this.requests.filter(r => r.Status__c !== 'Completed' && r.Status__c !== 'Rejected').length;
        const completed   = this.requests.filter(r => r.Status__c === 'Completed').length;
        const actionNeeded = this.actionItems.length;
        return [
            { key: 'total', label: 'Total Requests', count: total,        cls: 'dmr-kpi dmr-kpi-slate' },
            { key: 'prog',  label: 'In Progress',    count: inProgress,   cls: 'dmr-kpi dmr-kpi-amber' },
            { key: 'done',  label: 'Completed',      count: completed,    cls: 'dmr-kpi dmr-kpi-green' },
            { key: 'act',   label: 'Action Needed',  count: actionNeeded, cls: actionNeeded > 0 ? 'dmr-kpi dmr-kpi-red' : 'dmr-kpi dmr-kpi-green' }
        ];
    }

    get actionItems() {
        return this.requests.filter(r =>
            r.Status__c === 'Sent Back' ||
            r.Status__c === 'Pending Customer Response' ||
            (r.Request_Type__c === 'Additional Document Request'
                && !r.Certificate_Uploaded__c
                && r.Status__c !== 'Completed'
                && r.Status__c !== 'Rejected')
        );
    }

    get passportRows() {
        return this.requests.slice(0, this.passportDisplayCount);
    }

    get showPassportViewMore() {
        return this.passportDisplayCount < this.requests.length;
    }

    handlePassportViewMore() {
        this.passportDisplayCount += 10;
    }

    handlePassportViewAll() {
        this.passportDisplayCount = this.requests.length;
    }

    get certRecords() {
        return this.requests.filter(r => r.Certificate_Valid_To__c);
    }

    get certRecordsVisible() {
        return this.certRecords.slice(0, this.certDisplayCount);
    }

    get showCertViewMore() {
        return this.certDisplayCount < this.certRecords.length;
    }

    get showCertViewAll() {
        return this.certDisplayCount < this.certRecords.length;
    }

    handleCertViewMore() {
        this.certDisplayCount += 5;
    }

    handleCertViewAll() {
        this.certDisplayCount = this.certRecords.length;
    }

    get donutData() {
        const total = this.requests.length;
        if (!total) return null;
        const completed  = this.requests.filter(r => r.Status__c === 'Completed').length;
        const rejected   = this.requests.filter(r => r.Status__c === 'Rejected').length;
        const inProgress = total - completed - rejected;
        const cp = Math.round((completed  / total) * 100);
        const ip = Math.round((inProgress / total) * 100);
        return {
            style: 'background:conic-gradient(#4F7869 0% ' + cp + '%,#C98A3E ' + cp + '% ' + (cp + ip) + '%,#A8452F ' + (cp + ip) + '% 100%)',
            legend: [
                { key: 'c', dotStyle: 'background:#4F7869', label: 'Completed',  count: completed },
                { key: 'i', dotStyle: 'background:#C98A3E', label: 'In progress', count: inProgress },
                { key: 'r', dotStyle: 'background:#A8452F', label: 'Rejected',   count: rejected }
            ].filter(s => s.count > 0)
        };
    }

    get weeklyChartProps() {
        const W = 300, H = 110, PL = 8, PR = 8, PT = 10, PB = 20;
        const iW = W - PL - PR, iH = H - PT - PB;

        const weekMap = {};
        this.requests.forEach(r => {
            const dateStr = r.Submitted_Date__c || r.CreatedDate;
            if (!dateStr) return;
            const d = new Date(dateStr);
            if (isNaN(d.getTime())) return;
            const wk = new Date(d.getTime());
            wk.setDate(d.getDate() - d.getDay() + (d.getDay() === 0 ? -6 : 1));
            wk.setHours(0, 0, 0, 0);
            const key = wk.toISOString().slice(0, 10);
            weekMap[key] = (weekMap[key] || 0) + 1;
        });

        const sorted = Object.entries(weekMap).sort((a, b) => a[0].localeCompare(b[0])).slice(-8);
        if (sorted.length < 2) return null;

        const maxCount = Math.max(...sorted.map(([, c]) => c));
        const pts = sorted.map(([date, count], i) => ({
            x: PL + (i / (sorted.length - 1)) * iW,
            y: PT + iH - (count / maxCount) * iH,
            label: date.slice(5)
        }));

        const linePath = 'M ' + pts.map(p => p.x.toFixed(1) + ' ' + p.y.toFixed(1)).join(' L ');
        const areaPath = 'M ' + PL + ' ' + (H - PB) +
            ' L ' + pts.map(p => p.x.toFixed(1) + ' ' + p.y.toFixed(1)).join(' L ') +
            ' L ' + (W - PR) + ' ' + (H - PB) + ' Z';

        const step = Math.max(1, Math.ceil(pts.length / 4));
        const seen = new Set([0, pts.length - 1]);
        for (let i = step; i < pts.length - 1; i += step) seen.add(i);
        const labels = pts
            .filter((_, i) => seen.has(i))
            .map((p, i) => ({ key: 'l' + i, text: p.label }));

        const yMid = Math.round(maxCount / 2);
        return { linePath, areaPath, labels, yMax: maxCount, yMid };
    }
}