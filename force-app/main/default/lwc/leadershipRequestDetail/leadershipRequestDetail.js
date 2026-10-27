import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getRequestDetail        from '@salesforce/apex/LeadershipRequestDetailController.getRequestDetail';
import getProductsWithDetails  from '@salesforce/apex/LeadershipRequestDetailController.getProductsWithDetails';
import saveFGCodes             from '@salesforce/apex/LeadershipRequestDetailController.saveFGCodes';

const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

const AUDIT_LABEL = {
    'SUBMITTED':         'Request Submitted',
    'LEADERSHIP_REVIEW': 'Forwarded to Leadership',
    'APPROVED':          'Approved by Leadership',
    'REJECTED':          'Rejected',
    'ESCALATION':        'Escalation Triggered'
};

export default class LeadershipRequestDetail extends NavigationMixin(LightningElement) {

    @api recordId;
    @track detail;
    error;
    _wiredResult;

    @track productRows = [];

    // ── Resolve recordId from URL on Experience Cloud pages ───────────────────
    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        if (this.recordId) return;
        const id = pageRef?.attributes?.recordId ?? pageRef?.state?.recordId;
        if (id) this.recordId = id;
    }

    // ── Wire ─────────────────────────────────────────────────────────────────
    @wire(getRequestDetail, { recordId: '$recordId' })
    wiredDetail(result) {
        this._wiredResult = result;
        if (result.data) {
            this.detail = result.data;
            this.error  = undefined;
            this._loadProductDetails();
        } else if (result.error) {
            this.error  = result.error.body?.message || 'Failed to load request details.';
            this.detail = undefined;
        }
    }

    async _loadProductDetails() {
        if (!this.recordId) return;
        try {
            const products = await getProductsWithDetails({ requestId: this.recordId });
            this.productRows = products.map(p => ({ ...p }));
        } catch (e) {
            // silent — product rows stay empty
        }
    }

    // ── FG Code section ───────────────────────────────────────────────────────
    get hasFGProducts()      { return this.productRows.length > 0; }
    get isEditableFGStage()  {
        const s = this.detail?.status;
        return s === 'Submitted' || s === 'Under Leadership Review';
    }

    async handleFGCodeChange(e) {
        const id  = e.currentTarget.dataset.id;
        const val = e.detail.value;

        // Update value, clear previous indicators
        this.productRows = this.productRows.map(r =>
            r.id === id ? { ...r, fgCode: val, _saving: false, _saved: false, _error: null } : r
        );

        if (!val?.trim()) {
            this.productRows = this.productRows.map(r =>
                r.id === id ? { ...r, _error: 'FG Code is required.' } : r
            );
            return;
        }

        this.productRows = this.productRows.map(r =>
            r.id === id ? { ...r, _saving: true } : r
        );
        try {
            await saveFGCodes({ rrpDataJson: JSON.stringify([{ id, fgCode: val.trim() }]) });
            this.productRows = this.productRows.map(r =>
                r.id === id ? { ...r, _saving: false, _saved: true } : r
            );
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.productRows = this.productRows.map(r =>
                    r.id === id ? { ...r, _saved: false } : r
                );
            }, 3000);
        } catch (err) {
            this.productRows = this.productRows.map(r =>
                r.id === id ? { ...r, _saving: false, _error: err?.body?.message || 'Save failed. Please try again.' } : r
            );
        }
    }

    // ── Section visibility ────────────────────────────────────────────────────
    get hasDetail()    { return !!this.detail; }
    get hasParent()    { return !!this.detail?.parentRequestId; }
    get hasChildren()  { return (this.detail?.childRequests?.length || 0) > 0; }
    get hasHistory()   { return (this.detail?.auditHistory?.length || 0) > 0; }
    get hasRemarks()   { return !!this.detail?.remarks; }
    get hasRejection() { return !!this.detail?.rejectionComments; }
    get hasDocTypes()           { return !!this.detail?.documentTypes; }
    get hasDocumentsByProduct() { return (this.detail?.documentsByProduct?.length || 0) > 0; }
    get isLoading()    { return !this.detail && !this.error; }

    // ── Formatted values ──────────────────────────────────────────────────────
    get formattedSubmittedDate() {
        return this._formatDate(this.detail?.submittedDate);
    }

    _getLastDayOfWeek(weekNum, year) {
        const lastDay = new Date(year, 0, weekNum * 7);
        const dec31   = new Date(year, 11, 31);
        return lastDay > dec31 ? dec31 : lastDay;
    }

    _formatLastDay(d) {
        return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get forecastWeekLabel() {
        const w = this.detail?.forecastWeek;
        const y = this.detail?.forecastYear;
        if (!w || !y) return '—';
        const lastDay = this._getLastDayOfWeek(w, y);
        return 'Week ' + w + ', ' + y + ' · ' + this._formatLastDay(lastDay);
    }

    get actualCompletionLabel() {
        const w = this.detail?.actualCompletionWeek;
        const y = this.detail?.actualCompletionYear;
        if (!w || !y) return '—';
        const lastDay = this._getLastDayOfWeek(w, y);
        return 'Week ' + w + ', ' + y + ' · ' + this._formatLastDay(lastDay);
    }

    get isCompleted() { return this.detail?.status === 'Completed'; }

    get childRequestCount() {
        return this.detail?.childRequests?.length || 0;
    }

    get statusClass() {
        return this._statusClass(this.detail?.status);
    }

    get documentTypeList() {
        if (!this.detail?.documentTypes) return [];
        return this.detail.documentTypes.split(';')
            .map((v, i) => ({ key: i, label: v.trim() }))
            .filter(d => d.label);
    }

    get childRequests() {
        return (this.detail?.childRequests || []).map(c => ({
            ...c,
            statusClass:   this._statusClass(c.status),
            formattedDate: this._formatDate(c.submittedDate),
            productName:   c.productName || '—',
            requestType:   c.requestType || '—'
        }));
    }

    get auditHistory() {
        return (this.detail?.auditHistory || []).map((a, i) => {
            const typeKey = this._auditTypeKey(a.subject);
            return {
                ...a,
                entryKey:       i,
                formattedDate:  this._formatDate(a.activityDate),
                displaySubject: this._auditLabel(a.subject),
                dotClass:       typeKey === 'REJECTED'    ? 'timeline-dot dot-rejected'
                              : typeKey === 'APPROVED'    ? 'timeline-dot dot-approved'
                              : typeKey === 'ESCALATION'  ? 'timeline-dot dot-escalation'
                              : 'timeline-dot dot-default'
            };
        });
    }

    // ── Handlers ──────────────────────────────────────────────────────────────
    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            //attributes: { url: '/leadership-requests' }
            attributes: { url: '/leadership-queue' }
        });
    }

    handleViewParent() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/leadership-request-detail?recordId=${this.detail.parentRequestId}` }
        });
    }

    handleViewChild(e) {
        const recId = e.currentTarget.dataset.recid;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/leadership-request-detail?recordId=${recId}` }
        });
    }

    handleRefresh() {
        refreshApex(this._wiredResult).catch(e => {
            this.error = e?.body?.message || 'Refresh failed. Please try again.';
        });
        const timeline = this.template.querySelector('c-approval-history-timeline');
        if (timeline) timeline.refresh();
    }

    handleActionComplete() {
        refreshApex(this._wiredResult).catch(e => {
            this.error = e?.body?.message || 'Refresh failed. Please try again.';
        });
        const timeline = this.template.querySelector('c-approval-history-timeline');
        if (timeline) timeline.refresh();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    _formatDate(dateStr) {
        if (!dateStr) return '—';
        const [year, month, day] = dateStr.split('-');
        return `${day} ${MONTHS[parseInt(month, 10) - 1]} ${year}`;
    }

    _statusClass(status) {
        const map = {
            'Submitted':               'status-pill status-submitted',
            'Under Leadership Review':   'status-pill status-leadership',
            'Under Management Approval': 'status-pill status-management',
            'Approved by Leadership':    'status-pill status-approved',
            'Submitted to Regulatory': 'status-pill status-regulatory',
            'Under Regulatory Review': 'status-pill status-regulatory',
            'Completed':               'status-pill status-completed',
            'Rejected':                'status-pill status-rejected',
            'Sent Back':               'status-pill status-sent-back',
            'On Hold':                 'status-pill status-on-hold'
        };
        return map[status] || 'status-pill status-default';
    }

    _auditTypeKey(subject) {
        if (!subject) return '';
        const s = subject.toUpperCase();
        if (s.includes('ESCALATION')) return 'ESCALATION';
        for (const key of Object.keys(AUDIT_LABEL)) {
            if (s.includes(key)) return key;
        }
        return '';
    }

    _auditLabel(subject) {
        if (!subject) return subject;
        const key = this._auditTypeKey(subject);
        return AUDIT_LABEL[key] || subject.replace('[Reg Audit] ', '').replace('[Reg Escalation] ', 'Escalation — ');
    }
}