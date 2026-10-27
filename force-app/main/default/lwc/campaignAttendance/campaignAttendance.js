import { LightningElement, track, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getAttendees from '@salesforce/apex/AttendanceController.getAttendees';
import getAttendeesRefresh from '@salesforce/apex/AttendanceController.getAttendeesRefresh';
import markAttendance from '@salesforce/apex/AttendanceController.markAttendance';
import checkCampaignLockStatus from '@salesforce/apex/AttendanceController.checkCampaignLockStatus';
import reopenCampaign from '@salesforce/apex/AttendanceController.reopenCampaign';

export default class CampaignAttendance extends NavigationMixin(LightningElement) {

    @api recordId;

    @track attendeesList = [];
    @track spinner = false;
    @track saveButtonDisabled = false;
    @track campaignName = '';

    // Lock / Re-open state
    @track isLocked = false;
    @track canReopen = false;
    @track lockWarningMsg = '';
    @track isReopenLoading = false;
    @track isSaveClicked=false;

    // Confirmation modal
    @track showReopenConfirm = false;

    // Post-save summary modal
    @track showSaveSummary = false;
    @track summaryCreated = [];
    @track summarySkipped = [];

    @track errorMessage = false;

    @track skippedDetails = [];


    allProductGroups = [];
    attendessMap = new Map();

    // ── Getters ───────────────────────────────────────────────────────────────
    errorCallback(error, stack) {
        console.log('error', error);
        console.log('stack', stack);
    }

    get hasAttendees() {
        console.log('attendence list', this.attendeesList);
        return this.attendeesList && this.attendeesList.length > 0;
    }
    get totalCount() {
        return this.attendeesList.length;
    }
    get errorMessage() {
        return this.errorMessage;
    }
    get markedCount() {
        return this.attendeesList.filter(a => a.checked || a.disable).length;
    }
    get progressStyle() {
        const pct = this.totalCount > 0
            ? Math.round((this.markedCount / this.totalCount) * 100) : 0;
        return `width:${pct}%`;
    }
    get isSaveDisabled() {
        return this.isLocked || this.saveButtonDisabled;
    }
    get reopenLabel() {
        return this.isReopenLoading ? 'Opening...' : 'Re-open Campaign';
    }
    get reopenVariant() {
        return this.canReopen ? 'brand' : 'neutral';
    }
    get lockBannerClass() {
        return this.canReopen
            ? 'lock-banner lock-banner--privileged'
            : 'lock-banner lock-banner--restricted';
    }
    get hasSummaryCreated() {
        return this.summaryCreated && this.summaryCreated.length > 0;
    }
    get hasSummarySkipped() {
        return this.summarySkipped && this.summarySkipped.length > 0;
    }
    get summaryCreatedCount() {
        return this.summaryCreated ? this.summaryCreated.length : 0;
    }
    get summarySkippedCount() {
        return this.summarySkipped ? this.summarySkipped.length : 0;
    }

    @api invoke() { }

    // ── Wire ──────────────────────────────────────────────────────────────────
    @wire(getAttendees, { campaignId: '$recordId' })
    wiredData(result) {
        console.log('result====> 97', result);
        if (result.data) {
            if (result.data.activity) {
                this._applyData(result.data);
                this._checkLockStatus();
            } else {
                this._toast('Warning',
                    'Please complete Login before performing activities.', 'warning');
                this.closeAction();
            }
        }
        if (result.error) {
            const msg = result.error?.body?.message || 'Failed to load attendees.';
            this._toast('Error', msg, 'error');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FIX: _applyData now always clears and re-seeds attendessMap.
    //
    // Root cause of "only 4 / 2 leads created":
    //   attendessMap started empty and only got entries when the user manually
    //   fired handleToggle.  Members whose toggle was disabled (Attended__c=true
    //   from a prior partial save) could never be toggled → never entered the map
    //   → silently dropped from the Apex call.  count=4 in your debug log
    //   confirmed exactly this — 2 members were already attended and invisible.
    //
    // Fix: after building attendeesList, immediately seed the map for every
    // member that is checked (attended).  The map is cleared first so stale
    // entries from a previous load / re-open never bleed through.
    // ─────────────────────────────────────────────────────────────────────────
    _applyData(data) {
        this.allProductGroups = data.campaignProductGroups
            ? JSON.parse(JSON.stringify(data.campaignProductGroups)) : [];

        const raw = JSON.parse(JSON.stringify(data.attendees));
        const builtItems = raw.map(item => this._buildItem(item));
        this.attendeesList = builtItems;

        // Always wipe and re-seed so the map reflects the current server state
        this.attendessMap.clear();
        builtItems.forEach(item => {
            // Seed every member that is already attended (disable=true means
            // Attended__c was true on the server — their toggle is locked).
            // Also seed members whose toggle the user turned on before a reload.
            if (item.disable || item.checked) {
                this.attendessMap.set(item.Id, this._buildMapEntry(item));
            }
        });

        this.saveButtonDisabled = data.SaveButtonDisable;
        if (data.campaignName) this.campaignName = data.campaignName;
        if (data.isLocked !== undefined) {
            this.isLocked = data.isLocked;
            this.canReopen = data.canReopen;
            this.lockWarningMsg = data.lockWarningMsg || '';
        }
    }

    _checkLockStatus() {
        if (!this.recordId) return;
        checkCampaignLockStatus({ campaignId: this.recordId })
            .then(result => {
                this.isLocked = result.locked;
                this.canReopen = result.canReopen;
                this.lockWarningMsg = result.warningMsg || '';

                if (!result.locked) return;

                if (result.canReopen) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Campaign Locked',
                        message: 'Attendance was already saved. You are authorised to re-open this campaign.',
                        variant: 'info'
                    }));
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Attendance Marking Disabled',
                        message: this.lockWarningMsg || 'Attendance marking is disabled for this campaign.',
                        variant: 'warning',
                        mode: 'sticky'
                    }));
                    this.closeAction();
                }
            })
            .catch(error => console.error('checkCampaignLockStatus error:', JSON.stringify(error)));
    }

    // ── Re-open ───────────────────────────────────────────────────────────────
    handleReopenClick() {
        if (!this.canReopen) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Approval Required',
                message: this.lockWarningMsg,
                variant: 'warning',
                mode: 'sticky'
            }));
            return;
        }
        this.showReopenConfirm = true;
    }

    handleConfirmCancel() {
        this.showReopenConfirm = false;
    }

    handleConfirmReopen() {
        this.showReopenConfirm = false;
        this.isReopenLoading = true;

        reopenCampaign({ campaignId: this.recordId })
            .then(result => {
                if (result === 'SUCCESS') {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Campaign Re-opened',
                        message: 'Attendance marking is now enabled. The campaign will auto-lock again after saving.',
                        variant: 'success'
                    }));
                    this.isLocked = false;
                    this.saveButtonDisabled = false;
                    this._reloadAttendees();
                } else if (result && result.startsWith('UNAUTHORIZED|')) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Not Authorised',
                        message: result.split('|')[1] || result,
                        variant: 'error',
                        mode: 'sticky'
                    }));
                } else {
                    this._toast('Error', result || 'Could not re-open campaign.', 'error');
                }
            })
            .catch(error => {
                this._toast('Error', error?.body?.message || 'An unexpected error occurred.', 'error');
            })
            .finally(() => { this.isReopenLoading = false; });
    }

    // FIX: removed the premature attendessMap.clear() that was here before.
    // _applyData now owns the clear+reseed, so clearing here just meant the
    // map was empty if the reload was slow and the user clicked Save early.
    _reloadAttendees() {
        this.spinner = true;
        getAttendeesRefresh({ campaignId: this.recordId })
            .then(data => {
                if (data && data.attendees) {
                    console.log('data on line 238', data);
                    this._applyData(data);   // _applyData clears + reseeds map
                    this.isLocked = false;
                    this.saveButtonDisabled = false;
                }
            })
            .catch(error => this._toast('Error', 'Failed to refresh attendees.', 'error'))
            .finally(() => { this.spinner = false; });
    }

    // ── Build item ────────────────────────────────────────────────────────────
    _buildItem(item, overrides = {}) {
        const base = { ...item, ...overrides };
        // const isDisabled = !!base.Attended__c;
        const isDisabled = overrides.hasOwnProperty('disable')
            ? !!overrides.disable
            : !!base.Attended__c;
        const rawFilterValue = base.FilterValue || base.filtervalue || base.filterValue || [];
        const rawFilterLabels = base.FilterValueLabels || base.filtervaluelabels || base.filterValueLabels || [];
        const safeFilterIds = Array.isArray(rawFilterValue) ? [...rawFilterValue] : [];

        const pgExistingLeadMap = base.pgExistingLeadMap || {};

        let selectedSet = {};
        if (isDisabled) {
            const serverLabels = Array.isArray(rawFilterLabels) ? rawFilterLabels : [];
            serverLabels.forEach(fl => { if (fl && (fl.id || fl.Id)) selectedSet[fl.id || fl.Id] = true; });
            if (Object.keys(selectedSet).length === 0) safeFilterIds.forEach(id => { selectedSet[id] = true; });
        } else {
            safeFilterIds.forEach(id => { selectedSet[id] = true; });
        }

        const checkboxOptions = this.allProductGroups.map(pg => {
            const existingInfo = pgExistingLeadMap[pg.value];
            return {
                id: pg.value,
                label: pg.label,
                checked: !!selectedSet[pg.value],
                disabled: isDisabled,
                hasExistingLead: !!existingInfo,
                existingLeadName: existingInfo ? existingInfo.leadName : ''
            };
        });

        let filterValueLabels = [];
        if (isDisabled) {
            const serverLabels = Array.isArray(rawFilterLabels) ? rawFilterLabels : [];
            filterValueLabels = serverLabels.filter(fl => fl && (fl.id || fl.Id))
                .map(fl => ({ id: fl.id || fl.Id, label: fl.label || fl.Label || fl.id || fl.Id }));
            if (filterValueLabels.length === 0 && safeFilterIds.length > 0) {
                filterValueLabels = safeFilterIds.map(pgId => {
                    const found = this.allProductGroups.find(pg => pg.value === pgId);
                    return { id: pgId, label: found ? found.label : pgId };
                });
            }
        } else {
            filterValueLabels = safeFilterIds.map(pgId => {
                const found = this.allProductGroups.find(pg => pg.value === pgId);
                return { id: pgId, label: found ? found.label : pgId };
            });
        }

        return {
            ...base,
            FilterValue: safeFilterIds,
            FilterValueLabels: filterValueLabels,
            checkboxOptions,
            disable: isDisabled,
            //checked: isDisabled,
            checked: overrides.hasOwnProperty('checked') ? !!overrides.checked : isDisabled,
            disableToggle: isDisabled,
            rowClass: isDisabled ? 'row-marked' : '',
            isExisting: base.Type ? base.Type.toLowerCase().includes('exist') : false
        };
    }

    _refreshList(updatedItem) {
        this.attendeesList = this.attendeesList.map(i =>
            i.Id === updatedItem.Id ? updatedItem : i
        );
    }

    _buildMapEntry(attendee) {
        let products = [...(attendee.FilterValue || [])];
        if (products.length === 0 && Array.isArray(attendee.checkboxOptions)) {
            products = attendee.checkboxOptions
                .filter(opt => opt.checked)
                .map(opt => opt.id);
        }
        return {
            Id: attendee.Id,
            Name: attendee.Name || '',
            Product: products,
            FilterValue: products,
            Account: attendee.Account || '',
            FirstName: attendee.FirstName || '',
            LastName: attendee.LastName || '',
            Email: attendee.Email || '',
            Company: attendee.Company || '',
            Street: attendee.Street || '',
            City: attendee.City || '',
            State: attendee.State || '',
            Country: attendee.Country || '',
            Mobile: attendee.Mobile || '',
            zipCode: attendee.zipCode || '',
            CeRating: attendee.CeRating || '',
            PhakicRating: attendee.PhakicRating || '',
            SAPCode: attendee.SAPCode || '',
            memberType: attendee.memberType || '',
            CampaignStage: attendee.CampaignStage || ''
        };
    }

    // FIX: handleProductCheck now upserts the map even if the user ticked a
    // product before firing the attendance toggle.  Previously the map entry
    // was only created inside handleToggle, so product selections made before
    // the toggle were silently lost.
    handleProductCheck(event) {
        const memberId = event.currentTarget.dataset.id;
        const pgId = event.currentTarget.dataset.pgid;
        const isChecked = event.target.checked;
        const attendee = this.attendeesList.find(e => e.Id === memberId);
        if (!attendee || attendee.disable) return;

        let newFilterIds = [...(attendee.FilterValue || [])];
        if (isChecked) { if (!newFilterIds.includes(pgId)) newFilterIds.push(pgId); }
        else { newFilterIds = newFilterIds.filter(id => id !== pgId); }

        const newCheckboxOptions = attendee.checkboxOptions.map(opt => ({
            ...opt,
            checked: newFilterIds.includes(opt.id)
        }));
        const newFilterLabels = newFilterIds.map(id => {
            const found = this.allProductGroups.find(pg => pg.value === id);
            return { id, label: found ? found.label : id };
        });

        const updatedAttendee = {
            ...attendee,
            FilterValue: newFilterIds,
            FilterValueLabels: newFilterLabels,
            checkboxOptions: newCheckboxOptions
        };

        // Always upsert — ensures the member is in the map even without a toggle
        this.attendessMap.set(memberId, this._buildMapEntry(updatedAttendee));
        this._refreshList(updatedAttendee);
    }

    // handleToggle(event) {
    //     if (this.isLocked) {
    //         event.target.checked = false;
    //         this.dispatchEvent(new ShowToastEvent({
    //             title: 'Campaign Locked',
    //             message: this.lockWarningMsg,
    //             variant: 'warning',
    //             mode: 'sticky'
    //         }));
    //         return;
    //     }
    //     const recordId = event.currentTarget.dataset.id;
    //     const attendee = this.attendeesList.find(e => e.Id === recordId);
    //     if (!attendee) return;
    //     if (event.target.checked) {
    //         // Read the live item so any prior product checkbox selections are captured
    //         const liveAttendee = this.attendeesList.find(e => e.Id === recordId) || attendee;
    //         this.attendessMap.set(recordId, this._buildMapEntry(liveAttendee));
    //         this._refreshList({ ...liveAttendee, checked: true, rowClass: 'row-marked' });
    //     } else {
    //         this.attendessMap.delete(recordId);
    //         this._refreshList({ ...attendee, checked: false, rowClass: '' });
    //     }
    // }
    handleToggle(event) {
        if (this.isLocked) {
            event.target.checked = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Campaign Locked',
                message: this.lockWarningMsg,
                variant: 'warning',
                mode: 'sticky'
            }));
            return;
        }

        const recordId = event.currentTarget.dataset.id;
        const isChecked = event.target.checked;                        // ← read from the actual toggle
        const attendee = this.attendeesList.find(e => e.Id === recordId);
        if (!attendee) return;

        if (isChecked) {
            const liveAttendee = this.attendeesList.find(e => e.Id === recordId) || attendee;
            this.attendessMap.set(recordId, this._buildMapEntry(liveAttendee));
            this._refreshList({ ...liveAttendee, checked: true, rowClass: 'row-marked' });
        } else {
            // ── KEY FIX: delete from map AND force checked=false / rowClass='' ──
            this.attendessMap.delete(recordId);

            // Rebuild the item with Attended__c forced to false so _buildItem
            // does NOT re-derive checked=true from the original server value
            const uncheckedItem = this._buildItem(
                { ...attendee, Attended__c: false },   // ← override server value
                { checked: false, disable: false, disableToggle: false, rowClass: '' }
            );
            this._refreshList(uncheckedItem);
        }
    }

    // handleSave() {
    //     if (this.isLocked) {
    //         this.dispatchEvent(new ShowToastEvent({
    //             title: 'Campaign Locked',
    //             message: this.lockWarningMsg,
    //             variant: 'warning',
    //             mode: 'sticky'
    //         }));
    //         return;
    //     }
    //     console.log('attence on handle Save ', this.attendeesList);

    //     // const finalList = Array.from(this.attendessMap.values());
    //     const checkedIds = new Set(
    //         this.attendeesList.filter(a => a.checked).map(a => a.Id)
    //     );
    //     // const finalList = Array.from(this.attendessMap.values())
    //     //     .filter(entry => checkedIds.has(entry.Id));              // ← drop any ghost entries
    //     const finalList = Array.from(this.attendessMap.values())
    // .filter(entry => checkedIds.has(entry.Id) && !entry.disable);   // ← drop ghosts AND disabled rows

    //     if (finalList.length === 0) {
    //         this._toast('Warning', 'Please mark attendance for at least one attendee before saving.', 'warning');
    //         return;
    //     }

    //     for (const att of finalList) {
    //         if (!att.Product || att.Product.length === 0) {
    //             const name = `${att.FirstName || ''} ${att.LastName || ''}`.trim() || att.Name || att.Id;
    //             this._toast('Error', `Please select at least one Product Group for: ${name}`, 'error');
    //             return;
    //         }
    //     }
    //     console.log('OUTPUT : finalList ', JSON.stringify(finalList), 'record Id', this.recordId);
    //     this.spinner = true;
    //     markAttendance({ attendees: finalList, campaignId: this.recordId })
    //         .then(result => {
    //             this.spinner = false;

    //             if (!result || typeof result !== 'object') {
    //                 this._toast('Error', result || 'Unexpected response from server.', 'error');
    //                 return;
    //             }

    //             const status = result.status || '';

    //             if (status && status.toLowerCase().includes('success')) {

    //                 this.isLocked = true;
    //                 const created = result.leadsCreated || [];
    //                 const skipped = result.leadsSkipped || [];
    //                 const errorMessage = result.error?.error || result.error || '';

    //                 this.skippedDetails = skipped;
    //                 const skippedDetails = skipped.length > 0 ? `\nSkipped (already exist):\n${skipped.join('\n')}` : '';
    //                 console.log('442-----', JSON.stringify(result));
    //                 console.log('443-----', JSON.stringify(created));
    //                 console.log('444-----', JSON.stringify(skipped));
    //                 console.log('890-----', JSON.stringify(errorMessage));

    //                 // Per-product sticky toast for every skipped lead

    //                 /*  commented by Ankit 
    //                     skipped.forEach(item => {
    //                     this.dispatchEvent(new ShowToastEvent({
    //                         title  : `Lead Already Exists — ${item.pgLabel}`,
    //                         message: `"${item.leadName}" already exists for ${item.memberName} (${item.pgLabel}). No duplicate was created.`,
    //                         variant: 'warning',
    //                         mode   : 'sticky'
    //                     }));
    //                 }); */

    //                 // Summary toast
    //                 // if(errorMessage != null && errorMessage != ''){
    //                 //    this.errorMessage = true;
    //                 //    this.dispatchEvent(new ShowToastEvent({
    //                 //         title  : 'Error',
    //                 //         message: errorMessage,
    //                 //         variant: 'error',
    //                 //         mode   : 'sticky'
    //                 //     }));
    //                 // }
    //                 // else 
    //                 if (created.length > 0 && skipped.length > 0) {
    //                     this.dispatchEvent(new ShowToastEvent({
    //                         title: 'Attendance Saved — Partial',
    //                         message: `${created.length} Prospect(s) created. ${skipped.length} Prospect(s) Skipped`,
    //                         variant: 'success',
    //                         mode: 'sticky'
    //                     }));
    //                 } else if (created.length > 0) {
    //                     this._toast('Success', `${created.length} Prospect(s) created successfully.`, 'success');
    //                 } else if (skipped.length > 0) {
    //                     this.dispatchEvent(new ShowToastEvent({
    //                         title: 'No New Leads Created',
    //                         message: `All ${skipped.length} Prospect(s) already exist.${skipped.length} Prospect(s) Skipped`,
    //                         variant: 'warning',
    //                         mode: 'sticky'
    //                     }));
    //                 }

    //                 // Show summary modal if any skipped, otherwise close
    //                 if (skipped.length > 0) {
    //                     this.summaryCreated = created;
    //                     this.summarySkipped = skipped;
    //                     this.showSaveSummary = true;
    //                 } else {
    //                     this._navigateAndClose();
    //                 }

    //             } else if (status === 'LOCKED' || (result.message && result.message.startsWith('LOCKED|'))) {
    //                 this.isLocked = true;
    //                 const msg = result.message || '';
    //                 this.dispatchEvent(new ShowToastEvent({
    //                     title: 'Campaign Locked',
    //                     message: msg.startsWith('LOCKED|') ? msg.split('|')[1] : msg,
    //                     variant: 'warning',
    //                     mode: 'sticky'
    //                 }));

    //             } else if (status === 'ACTIVITY_BLOCKED' || (result.message && result.message.startsWith('ACTIVITY_BLOCKED|'))) {
    //                 const msg = result.message || '';
    //                 this.dispatchEvent(new ShowToastEvent({
    //                     title: 'Beat Plan Login Required',
    //                     message: msg.startsWith('ACTIVITY_BLOCKED|') ? msg.split('|')[1] : msg,
    //                     variant: 'warning',
    //                     mode: 'sticky'
    //                 }));

    //             } else {
    //                 const msg = result.message || '';
    //                 this._toast(
    //                     'Error saving records',
    //                     !msg ? 'Please select a product group.' : msg,
    //                     'error'
    //                 );
    //             }
    //         })
    //         .catch(error => {
    //             this.spinner = false;
    //             this._toast('Unexpected Error', error?.body?.message || 'An unexpected error occurred.', 'error');
    //         });
    // }
    handleSave() {
    if(this.isSaveClicked){ return }
    this.isSaveClicked=true;
    this.saveButtonDisabled = true;

    if (this.isLocked) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Campaign Locked',
            message: this.lockWarningMsg,
            variant: 'warning',
            mode: 'sticky'
        }));
        this.saveButtonDisabled = false;
        this.isSaveClicked=false;
        return;
    }

    const checkedIds = new Set(
        this.attendeesList.filter(a => a.checked).map(a => a.Id)
    );

    const alreadyMarkedIds = new Set(
        this.attendeesList.filter(a => a.disable).map(a => a.Id)
    );

    const finalList = Array.from(this.attendessMap.values())
        .filter(entry => checkedIds.has(entry.Id) && !alreadyMarkedIds.has(entry.Id));

    if (finalList.length === 0) {
        this.saveButtonDisabled = false;
        this.isSaveClicked=false;
        this._toast(
            'Warning',
            'Please mark attendance for at least one attendee before saving.',
            'warning'
        );
        return;
    }

    for (const att of finalList) {
        if (!att.Product || att.Product.length === 0) {
            const name = `${att.FirstName || ''} ${att.LastName || ''}`.trim()
                || att.Name
                || att.Id;

            this._toast(
                'Error',
                `Please select at least one Product Group for: ${name}`,
                'error'
            );
            this.isSaveClicked=false;
            this.saveButtonDisabled = false;
            return;
        }
    }

    console.log('OUTPUT : finalList ', JSON.stringify(finalList));

    this.spinner = true;

    markAttendance({
        attendees: finalList,
        campaignId: this.recordId
    })
        .then(result => {
            this.spinner = false;

            // Always enable button when server response is received
            this.saveButtonDisabled = false;
            this.isSaveClicked=false;

            if (!result || typeof result !== 'object') {
                this._toast(
                    'Error',
                    result || 'Unexpected response from server.',
                    'error'
                );
                return;
            }

            const status = result.status || '';

            if (status && status.toLowerCase().includes('success')) {

                this.isLocked = true;

                const created = result.leadsCreated || [];
                const skipped = result.leadsSkipped || [];
                const errorMessage = result.error?.error || result.error || '';

                this.skippedDetails = skipped;

                console.log('442-----', JSON.stringify(result));
                console.log('443-----', JSON.stringify(created));
                console.log('444-----', JSON.stringify(skipped));
                console.log('890-----', JSON.stringify(errorMessage));

                if (created.length > 0 && skipped.length > 0) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Attendance Saved — Partial',
                        message: `${created.length} Prospect(s) created. ${skipped.length} Prospect(s) Skipped`,
                        variant: 'success',
                        mode: 'sticky'
                    }));

                } else if (created.length > 0) {

                    this._toast(
                        'Success',
                        `${created.length} Prospect(s) created successfully.`,
                        'success'
                    );

                } else if (skipped.length > 0) {

                    this.dispatchEvent(new ShowToastEvent({
                        title: 'No New Leads Created',
                        message: `All ${skipped.length} Prospect(s) already exist. ${skipped.length} Prospect(s) Skipped`,
                        variant: 'warning',
                        mode: 'sticky'
                    }));
                }

                if (skipped.length > 0) {
                    this.summaryCreated = created;
                    this.summarySkipped = skipped;
                    this.showSaveSummary = true;
                } else {
                    this._navigateAndClose();
                }

            } else if (
                status === 'LOCKED' ||
                (result.message && result.message.startsWith('LOCKED|'))
            ) {

                this.isLocked = true;

                const msg = result.message || '';

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Campaign Locked',
                    message: msg.startsWith('LOCKED|')
                        ? msg.split('|')[1]
                        : msg,
                    variant: 'warning',
                    mode: 'sticky'
                }));

            } else if (
                status === 'ACTIVITY_BLOCKED' ||
                (result.message && result.message.startsWith('ACTIVITY_BLOCKED|'))
            ) {

                const msg = result.message || '';

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Beat Plan Login Required',
                    message: msg.startsWith('ACTIVITY_BLOCKED|')
                        ? msg.split('|')[1]
                        : msg,
                    variant: 'warning',
                    mode: 'sticky'
                }));

            } else {

                const msg = result.message || '';

                this._toast(
                    'Error saving records',
                    !msg ? 'Please select a product group.' : msg,
                    'error'
                );
            }
        })
        .catch(error => {
            this.spinner = false;

            // Re-enable button if Apex call fails
            this.saveButtonDisabled = false;
            this.isSaveClicked=false;

            this._toast(
                'Unexpected Error',
                error?.body?.message || 'An unexpected error occurred.',
                'error'
            );
        });
}

    handleSummaryClose() {
        this.showSaveSummary = false;
        this._navigateAndClose();
    }

    _navigateAndClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Campaign__c',
                actionName: 'view'
            }
        });
        setTimeout(() => { window.location.reload(); }, 1000);
    }

    closeAction() { this.dispatchEvent(new CloseActionScreenEvent()); }
    _toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
}