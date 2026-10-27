import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent }                    from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues }  from 'lightning/uiObjectInfoApi';
import { refreshApex }                       from '@salesforce/apex';
import getActionItems        from '@salesforce/apex/MomMeetingService.getActionItems';
import saveActionItems       from '@salesforce/apex/MomMeetingService.saveActionItems';
import getDeptsByCategory    from '@salesforce/apex/MomMeetingService.getDeptsByCategory';

import TASK_OBJECT    from '@salesforce/schema/Task';
import STATUS_FIELD   from '@salesforce/schema/Task.Status';
import PRIORITY_FIELD from '@salesforce/schema/Task.Priority';

export default class MomMeetingCreator extends LightningElement {

    @api recordId;

    @track rows      = [];
    @track isLoading = true;
    @track isSaving  = false;
    @track isEditing = false;

    _keyCounter  = 0;
    _deletedIds  = [];
    _wiredResult;
    _deptsMap    = {};

    // ── Wire: object info ─────────────────────────────────────────────────────
    @wire(getObjectInfo, { objectApiName: TASK_OBJECT })
    taskObjectInfo;

    // ── Wire: picklist values ─────────────────────────────────────────────────
    @wire(getPicklistValues, {
        recordTypeId: '$momActionItemRtId',
        fieldApiName: STATUS_FIELD
    })
    wiredStatus;

    @wire(getPicklistValues, {
        recordTypeId: '$taskObjectInfo.data.defaultRecordTypeId',
        fieldApiName: PRIORITY_FIELD
    })
    wiredPriority;

    @wire(getDeptsByCategory)
    wiredDeptsByCategory({ data }) {
        if (data) {
            this._deptsMap = data;
            if (this.rows.length > 0) {
                this.rows = this.rows.map(r => ({
                    ...r,
                    departmentOptions: this._getDeptOptions(r.category)
                }));
            }
        }
    }

    // ── Wire: action items for this meeting ───────────────────────────────────
    @wire(getActionItems, { meetingId: '$recordId' })
    wiredActionItems(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.rows      = data.map(item => this._buildRow(item));
            this.isLoading = false;
        } else if (error) {
            this._toast(
                'Could Not Load Action Items',
                error.body?.message || 'Please refresh the page and try again.',
                'error'
            );
            this.isLoading = false;
        }
    }

    // ── Getters ───────────────────────────────────────────────────────────────
    get momActionItemRtId() {
        const infos = this.taskObjectInfo?.data?.recordTypeInfos;
        if (!infos) return null;
        const entry = Object.entries(infos).find(([, v]) => v.developerName === 'MOM_Action_Item');
        return entry ? entry[0] : null;
    }

    get hasRows()       { return this.rows.length > 0; }
    get showGrid()      { return !this.isLoading && this.rows.length > 0; }
    get showEmptyState(){ return !this.isLoading && this.rows.length === 0; }
    get rowCountLabel() { return String(this.rows.length); }
    get isSaveDisabled(){ return !this.hasRows || this.isSaving; }
    get tableClass()    { return this.isEditing ? 'table-wrapper editing' : 'table-wrapper'; }

    get statusOptions() {
        return this.wiredStatus?.data?.values || [];
    }

    get priorityOptions() {
        return this.wiredPriority?.data?.values || [];
    }

    get categoryOptions() {
        return Object.keys(this._deptsMap).sort().map(c => ({ label: c, value: c }));
    }

    _getDeptOptions(category) {
        if (!category || !this._deptsMap[category]) return [];
        return this._deptsMap[category].map(l => ({ label: l, value: l }));
    }

    get _currentWeek() {
        const now          = new Date();
        const startOfYear  = new Date(now.getFullYear(), 0, 1);
        const dayOfYear    = Math.floor((now - startOfYear) / 86400000) + 1;
        return Math.ceil(dayOfYear / 7);
    }

    _statusInfo(status, targetWeek, completionWeek) {
        if (status === 'No Action Required') {
            return { badgeClass: 'status-badge badge-no-action', label: 'NA' };
        }
        if (status === 'Completed') {
            const tw = (targetWeek     != null && targetWeek     !== '—') ? Number(targetWeek)     : null;
            const cw = (completionWeek != null && completionWeek !== '—') ? Number(completionWeek) : null;
            if (tw != null && cw != null && cw <= tw) {
                return { badgeClass: 'status-badge badge-completed-ontime', label: 'Done' };
            }
            return { badgeClass: 'status-badge badge-completed-late', label: 'Completed' };
        }
        const tw = (targetWeek != null && targetWeek !== '—') ? Number(targetWeek) : null;
        if (tw != null && this._currentWeek >= tw) {
            return { badgeClass: 'status-badge badge-wip-overdue', label: 'Delayed' };
        }
        return { badgeClass: 'status-badge badge-wip-pending', label: 'WIP' };
    }

    _statusRowClass(status, targetWeek, completionWeek) {
        return 'grid-row';
    }

    // ── Row factory ───────────────────────────────────────────────────────────
    _buildRow(item) {
        this._keyCounter += 1;
        const status   = item.status || 'Open';
        const tw       = item.targetWeek     != null ? item.targetWeek     : '—';
        const cw       = item.completionWeek != null ? item.completionWeek : '—';
        const sInfo    = this._statusInfo(status, tw, cw);
        return {
            key                   : 'row_' + this._keyCounter,
            id                    : item.id                    || null,
            taskIdsJson           : item.taskIdsJson           || null,
            subject               : item.subject               || '',
            activityDate          : item.activityDate          || '',
            formattedActivityDate : this._formatDate(item.activityDate || ''),
            targetWeek            : tw,
            completionWeek        : cw,
            status                : status,
            statusLabel           : sInfo.label,
            statusBadgeClass      : sInfo.badgeClass,
            priority              : item.priority              || 'Normal',
            category              : item.category              || '',
            departmentOptions     : this._getDeptOptions(item.category || ''),
            isCategoryEmpty       : !item.category,
            responsibleDepartment : item.responsibleDepartment || '',
            attendees             : item.attendeesJson ? this._parseAttendees(item.attendeesJson) : [],
            currentEmail          : '',
            rowClass              : 'grid-row',
            subjectClass          : ''
        };
    }

_formatDate(dateStr) {
    if (!dateStr) return '—';
    try {
        const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        const d = new Date(dateStr + 'T00:00:00');
        return `${String(d.getDate()).padStart(2,'0')} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
    } catch (e) {
        return dateStr;
    }
}

    _blankRow() {
        return this._buildRow({
            id: null, subject: '', activityDate: '',
            status: 'Work in Progress', priority: 'Normal',
            category: '', responsibleDepartment: '', attendeesJson: null
        });
    }

    // ── Handlers ──────────────────────────────────────────────────────────────
    handleEdit() {
        this.isEditing = true;
    }

    handleAddRow() {
        this.rows = [...this.rows, this._blankRow()];
    }

    handleDeleteRow(event) {
        const key = event.currentTarget.dataset.key;
        const row = this.rows.find(r => r.key === key);
        if (!row) return;
        if (row.taskIdsJson) {
            try {
                JSON.parse(row.taskIdsJson).forEach(id => this._deletedIds.push(id));
            } catch (e) {
                if (row.id) this._deletedIds.push(row.id);
            }
        } else if (row.id) {
            this._deletedIds.push(row.id);
        }
        this.rows = this.rows.filter(r => r.key !== key);
    }

    handleAttendeeEmailInput(event) {
        const key = event.currentTarget.dataset.key;
        this.rows = this.rows.map(r =>
            r.key !== key ? r : { ...r, currentEmail: event.target.value }
        );
    }

    handleAttendeeKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this._addAttendeeForRow(event.currentTarget.dataset.key);
        }
    }

    handleAttendeeAdd(event) {
        this._addAttendeeForRow(event.currentTarget.dataset.key);
    }

    _addAttendeeForRow(key) {
        const row = this.rows.find(r => r.key === key);
        if (!row) return;
        const email = (row.currentEmail || '').trim().toLowerCase();
        if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return;
        if (row.attendees.includes(email)) return;
        this.rows = this.rows.map(r =>
            r.key !== key ? r : { ...r, attendees: [...r.attendees, email], currentEmail: '' }
        );
        const input = this.template.querySelector(`input[data-key="${key}"]`);
        if (input) input.value = '';
    }

    handleAttendeeRemove(event) {
        const key   = event.currentTarget.dataset.key;
        const email = event.currentTarget.dataset.email;
        this.rows = this.rows.map(r =>
            r.key !== key ? r : { ...r, attendees: r.attendees.filter(e => e !== email) }
        );
    }

    _parseAttendees(attendeesJson) {
        try {
            const parsed = JSON.parse(attendeesJson);
            if (!Array.isArray(parsed) || parsed.length === 0) return [];
            // backward-compat: old format was [{id, name}], new format is ["email"]
            return typeof parsed[0] === 'string' ? parsed : parsed.map(a => a.name || '').filter(Boolean);
        } catch (e) {
            return [];
        }
    }

    handleFieldChange(event) {
        const key   = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value = event.detail.value;
        this.rows = this.rows.map(r => {
            if (r.key !== key) return r;
            const newStatus = field === 'status' ? value : r.status;
            const sInfo     = this._statusInfo(newStatus, r.targetWeek, r.completionWeek);
            const updated = {
                ...r,
                [field]          : value,
                rowClass         : 'grid-row',
                statusLabel      : sInfo.label,
                statusBadgeClass : sInfo.badgeClass,
                subjectClass     : field === 'subject' ? '' : r.subjectClass
            };
            if (field === 'category') {
                updated.responsibleDepartment = '';
                updated.departmentOptions     = this._getDeptOptions(value);
                updated.isCategoryEmpty       = !value;
            }
            return updated;
        });
    }

    async handleCancel() {
        this._deletedIds = [];
        this.isEditing   = false;
        await refreshApex(this._wiredResult);
        this._toast('Changes Discarded', 'All unsaved changes have been reverted.', 'info');
    }

    async handleSaveAll() {
        if (!this._validate()) return;

        this.isSaving = true;
        try {
            await saveActionItems({
                meetingId       : this.recordId,
                itemsToSaveJson : JSON.stringify(this.rows.map(r => ({
                    id                    : r.id                    || null,
                    taskIdsJson           : r.taskIdsJson           || null,
                    subject               : r.subject,
                    activityDate          : r.activityDate          || null,
                    status                : r.status,
                    priority              : r.priority,
                    responsibleDepartment : r.responsibleDepartment,
                    attendeesJson         : r.attendees.length > 0 ? JSON.stringify(r.attendees) : null
                }))),
                itemsToDelete : this._deletedIds
            });

            this._deletedIds = [];
            this.isEditing   = false;
            await refreshApex(this._wiredResult);
            this._toast(
                'Saved Successfully',
                `${this.rows.length} action item${this.rows.length === 1 ? '' : 's'} saved.`,
                'success'
            );
        } catch (error) {
            this._toast(
                'Save Failed',
                error.body?.message || 'An unexpected error occurred. Please try again.',
                'error'
            );
        } finally {
            this.isSaving = false;
        }
    }

    // ── Validation ────────────────────────────────────────────────────────────
    _validate() {
        let isValid     = true;
        const errorRows = [];

        this.rows = this.rows.map((r, index) => {
            const subjectMissing = !r.subject?.trim();

            if (subjectMissing) {
                isValid = false;
                errorRows.push(index + 1);
            }

            return {
                ...r,
                rowClass     : subjectMissing ? 'grid-row row-error' : this._statusRowClass(r.status, r.targetWeek, r.completionWeek),
                subjectClass : subjectMissing ? 'input-error'        : ''
            };
        });

        if (!isValid) {
            const rowLabel = errorRows.length === 1 ? 'Row' : 'Rows';
            this._toast(
                'Required Fields Missing',
                `${rowLabel} ${errorRows.join(', ')}: Description is required.`,
                'error'
            );

            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const firstError = this.template.querySelector('.row-error');
                if (firstError) firstError.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }, 50);
        }

        return isValid;
    }

    // ── Toast helper ──────────────────────────────────────────────────────────
    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}