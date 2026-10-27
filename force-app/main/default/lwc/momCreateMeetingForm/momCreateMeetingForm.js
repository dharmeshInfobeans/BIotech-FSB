import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent }               from 'lightning/platformShowToastEvent';
import { NavigationMixin }              from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import createMeetingWithActionItems from '@salesforce/apex/MomCreateMeetingService.createMeetingWithActionItems';
import getDeptsByCategory           from '@salesforce/apex/MomMeetingService.getDeptsByCategory';

import MOM_MEETING_OBJECT from '@salesforce/schema/MOM_Meeting__c';
import REGION_SET_FIELD   from '@salesforce/schema/MOM_Meeting__c.Region_Set__c';

import TASK_OBJECT    from '@salesforce/schema/Task';
import PRIORITY_FIELD from '@salesforce/schema/Task.Priority';
// Responsible_Function__c passed as plain string — avoids compile-time schema error

const MEETING_TYPE_OPTIONS = [
    { label: 'Monthly',   value: 'Monthly'   },
    { label: 'Quarterly', value: 'Quarterly' }
];

const BLANK_MEETING = () => ({
    meetingTopic      : '',
    meetingDate       : '',
    meetingType       : '',
    region            : '',
    discussionSummary : ''
});

export default class MomCreateMeetingForm extends NavigationMixin(LightningElement) {

    @track meeting           = BLANK_MEETING();
    @track meetingAttendees  = [];
    @track rows              = [];
    @track isSubmitting      = false;
    @track showPickers       = true;
    @track distributorError  = false;

    _distributorId       = null;
    _meetingAttendeeEmail = '';
    _keyCounter          = 0;
    _deptsMap            = {};

    // ── Wire: Task object info ────────────────────────────────────────────────
    @wire(getObjectInfo, { objectApiName: TASK_OBJECT })
    taskObjectInfo;

    // ── Wire: MOM Meeting picklist values (Region) ────────────────────────────
    @wire(getObjectInfo, { objectApiName: MOM_MEETING_OBJECT })
    momMeetingObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$momMeetingObjectInfo.data.defaultRecordTypeId',
        fieldApiName: REGION_SET_FIELD
    })
    wiredRegion;

    // ── Wire: Task picklist values ────────────────────────────────────────────
    @wire(getPicklistValues, {
        recordTypeId: '$taskObjectInfo.data.defaultRecordTypeId',
        fieldApiName: PRIORITY_FIELD
    })
    wiredPriority;

    @wire(getDeptsByCategory)
    wiredDeptsByCategory({ data }) {
        if (data) {
            this._deptsMap = data;
        }
    }

    // ── Getters ───────────────────────────────────────────────────────────────
    get meetingTypeOptions()         { return MEETING_TYPE_OPTIONS; }
    get regionOptions()              { return this.wiredRegion?.data?.values              || []; }
    get priorityOptions()            { return this.wiredPriority?.data?.values            || []; }
    get categoryOptions() {
        return Object.keys(this._deptsMap).sort().map(c => ({ label: c, value: c }));
    }

    _getDeptOptions(category) {
        if (!category || !this._deptsMap[category]) return [];
        return this._deptsMap[category].map(l => ({ label: l, value: l }));
    }

    get hasRows()        { return this.rows.length > 0; }
    get showGrid()       { return this.rows.length > 0; }
    get showEmptyState() { return this.rows.length === 0; }
    get rowCountLabel()  { return String(this.rows.length); }
    get canDeleteRow()   { return this.rows.length > 1; }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this.handleAddRow();
    }

    // ── Meeting Details handlers ──────────────────────────────────────────────
    handleDistributorChange(event) {
        const recordId = event.detail.recordId;
        if (recordId !== undefined) {
            this._distributorId   = recordId || null;
            this.distributorError = !recordId;
        }
    }

    // ── Meeting Attendees handlers ────────────────────────────────────────────
    handleMeetingAttendeeInput(event) {
        this._meetingAttendeeEmail = event.target.value;
    }

    handleMeetingAttendeeKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this._addMeetingAttendee(event.target);
        }
    }

    handleMeetingAttendeeAdd(event) {
        const input = this.template.querySelector('.attendees-cell .attendee-email-input');
        this._addMeetingAttendee(input);
    }

    _addMeetingAttendee(inputEl) {
        const email = (this._meetingAttendeeEmail || '').trim().toLowerCase();
        if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return;
        if (this.meetingAttendees.includes(email)) return;
        this.meetingAttendees = [...this.meetingAttendees, email];
        this._meetingAttendeeEmail = '';
        if (inputEl) inputEl.value = '';
    }

    handleMeetingAttendeeRemove(event) {
        const email = event.currentTarget.dataset.email;
        this.meetingAttendees = this.meetingAttendees.filter(e => e !== email);
    }

    handleMeetingFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.detail.value;
        this.meeting = { ...this.meeting, [field]: value };
    }

    // ── Action Item row handlers ──────────────────────────────────────────────
    handleAddRow() {
        this._keyCounter += 1;
        this.rows = [
            ...this.rows,
            {
                key                   : 'row_' + this._keyCounter,
                subject               : '',
                priority              : 'Normal',
                category              : '',
                departmentOptions     : [],
                isCategoryEmpty       : true,
                responsibleDepartment : '',
                attendees             : [],
                currentEmail          : '',
                rowClass              : 'grid-row',
                subjectClass          : ''
            }
        ];
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

    handleDeleteRow(event) {
        if (this.rows.length <= 1) return;
        const key = event.currentTarget.dataset.key;
        this.rows = this.rows.filter(r => r.key !== key);
    }

    handleFieldChange(event) {
        const key   = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value = event.detail.value;
        this.rows = this.rows.map(r => {
            if (r.key !== key) return r;
            const updated = {
                ...r,
                [field]      : value,
                rowClass     : 'grid-row',
                subjectClass : field === 'subject' ? '' : r.subjectClass
            };
            if (field === 'category') {
                updated.responsibleDepartment = '';
                updated.departmentOptions     = this._getDeptOptions(value);
                updated.isCategoryEmpty       = !value;
            }
            return updated;
        });
    }

    // ── Reset ─────────────────────────────────────────────────────────────────
    handleReset() {
        this._distributorId       = null;
        this._meetingAttendeeEmail = '';
        this.distributorError     = false;
        this.meetingAttendees     = [];
        this.rows                 = [];
        this.meeting              = BLANK_MEETING();
        this.showPickers      = false;
        Promise.resolve().then(() => {
            this.showPickers = true;
            this.handleAddRow();
        });
    }

    // ── Submit ────────────────────────────────────────────────────────────────
    async handleSubmit() {
        if (!this._validate()) return;

        this.isSubmitting = true;
        try {
            const actionItems = this.rows.map(r => ({
                subject               : r.subject               || null,
                status                : 'Work in Progress',
                priority              : r.priority              || null,
                responsibleDepartment : r.responsibleDepartment || null,
                attendeesJson         : r.attendees.length > 0 ? JSON.stringify(r.attendees) : null
            }));

            const newMeetingId = await createMeetingWithActionItems({
                distributorId       : this._distributorId,
                meetingTopic        : this.meeting.meetingTopic,
                meetingAttendeesJson: this.meetingAttendees.length > 0 ? JSON.stringify(this.meetingAttendees) : null,
                meetingDate         : this.meeting.meetingDate,
                meetingType         : this.meeting.meetingType,
                region              : this.meeting.region,
                discussionSummary   : this.meeting.discussionSummary || null,
                actionItemsJson     : JSON.stringify(actionItems)
            });

            this._toast(
                'Meeting Created',
                `MOM Meeting created with ${this.rows.length} action item${this.rows.length === 1 ? '' : 's'}.`,
                'success'
            );

            this[NavigationMixin.Navigate]({
                type       : 'standard__recordPage',
                attributes : { recordId: newMeetingId, actionName: 'view' }
            });

        } catch (error) {
            this._toast(
                'Creation Failed',
                error.body?.message || 'An unexpected error occurred. Please try again.',
                'error'
            );
        } finally {
            this.isSubmitting = false;
        }
    }

    // ── Validation ────────────────────────────────────────────────────────────
    _validate() {
        let isValid = true;

        this.template.querySelectorAll(
            'lightning-input[required], lightning-combobox[required]'
        ).forEach(f => f.reportValidity());

        let futureDateError = false;
        if (!this.meeting.meetingDate) {
            isValid = false;
        } else {
            const today = new Date();
            const todayStr = [
                today.getFullYear(),
                String(today.getMonth() + 1).padStart(2, '0'),
                String(today.getDate()).padStart(2, '0')
            ].join('-');
            if (this.meeting.meetingDate > todayStr) {
                isValid = false;
                futureDateError = true;
            }
        }
        if (!this.meeting.meetingTopic?.trim())      isValid = false;
        if (this.meetingAttendees.length === 0)      isValid = false;
        if (!this.meeting.meetingType)              isValid = false;
        if (!this.meeting.region)                  isValid = false;
        if (!this.meeting.discussionSummary?.trim()) isValid = false;

        this.distributorError = false;

        const errorRows = [];
        this.rows = this.rows.map((r, idx) => {
            const subjectMissing  = !r.subject?.trim();
            const priorityMissing = !r.priority?.trim();
            const categoryMissing = !r.category?.trim();
            const deptMissing     = !r.responsibleDepartment?.trim();
            const rowHasError = subjectMissing || priorityMissing || categoryMissing || deptMissing;

            if (rowHasError) {
                isValid = false;
                errorRows.push(idx + 1);
            }

            return {
                ...r,
                rowClass     : rowHasError    ? 'grid-row row-error' : 'grid-row',
                subjectClass : subjectMissing ? 'input-error'        : ''
            };
        });

        if (!isValid) {
            let message = futureDateError
                ? 'Meeting Date cannot be in the future. Please select today\'s date or a past date.'
                : 'Please complete all required fields.';
            if (!futureDateError && errorRows.length > 0) {
                const label = errorRows.length === 1 ? 'Row' : 'Rows';
                message += ` Action item ${label} ${errorRows.join(', ')}: all fields including Attendees are required.`;
            }
            this._toast('Required Fields Missing', message, 'error');

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