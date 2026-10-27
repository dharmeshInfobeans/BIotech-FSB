import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference }  from 'lightning/navigation';
import getHistory from '@salesforce/apex/RegistrationApprovalHistoryController.getHistory';

export default class ApprovalHistoryTimeline extends LightningElement {

    @api recordId;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        if (this.recordId) return;
        const id = pageRef?.attributes?.recordId ?? pageRef?.state?.recordId;
        if (id) {
            this.recordId = id;
        }
    }

    // ── State ─────────────────────────────────────────────────────────────────
    @track _entries      = [];
    @track _stats        = null;
    @track isLoading     = false;
    @track loadError     = null;
    @track activeView    = 'timeline'; // 'timeline' | 'table'

    // ── Load on connect ───────────────────────────────────────────────────────
    connectedCallback() {
        this._load();
    }

    async _load() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.loadError = null;
        try {
            const result     = await getHistory({ recordId: this.recordId });
            this._entries    = result?.entries  ?? [];
            this._stats      = result?.stats    ?? null;
        } catch (e) {
            this.loadError = this._msg(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Public refresh (parent can call this after an approval action) ─────────
    @api
    refresh() {
        this._load();
    }

    // ── Computed properties ───────────────────────────────────────────────────
    get entries()       { return this._entries; }
    get stats()         { return this._stats; }
    get hasEntries()    { return this._entries.length > 0; }
    get isEmpty()       { return !this.isLoading && !this.loadError && this._entries.length === 0; }
    get isTimelineView(){ return this.activeView === 'timeline'; }
    get isTableView()   { return this.activeView === 'table'; }

    get timelineTabClass() {
        return this.activeView === 'timeline'
            ? 'tab-btn tab-btn-active' : 'tab-btn';
    }
    get tableTabClass() {
        return this.activeView === 'table'
            ? 'tab-btn tab-btn-active' : 'tab-btn';
    }

    // ── Handlers ──────────────────────────────────────────────────────────────
    showTimeline()   { this.activeView = 'timeline'; }
    showTable()      { this.activeView = 'table';    }
    handleRefresh()  { this._load(); }

    // ── Error helper ──────────────────────────────────────────────────────────
    _msg(error) {
        if (typeof error === 'string')  return error;
        if (error?.body?.message)       return error.body.message;
        if (error?.message)             return error.message;
        return 'An unexpected error occurred.';
    }
}