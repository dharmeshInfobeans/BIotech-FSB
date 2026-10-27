import { LightningElement, track, api } from 'lwc';
import getProductGroups from '@salesforce/apex/TargetProductConfiguratorController.getProductGroups';
import createTargetLine from '@salesforce/apex/TargetProductConfiguratorController.createTargetLine';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class TargetAddProduct extends LightningElement {
    

    @api recordId;

    @track productFamilyOptions    = [];
    @track groupNameOptions        = [];
    @track selectedProductFamilies = [];
    @track selectedGroupNames      = [];

    @track showFamilyPicklist = true;
    @track showGroupPicklist  = false;

    allProductGroups = [];
    loading          = false;
    _isSaving        = false;

    // ─────────────────────────────────────────────
    // LIFECYCLE
    // ─────────────────────────────────────────────

    connectedCallback() {
        this.loadProductGroups();
    }

    // ─────────────────────────────────────────────
    // DATA LOADING
    // ─────────────────────────────────────────────

    loadProductGroups() {
        getProductGroups()
            .then(result => {
                this.allProductGroups     = result;
                const families            = [...new Set(result.map(r => r.Product_Family__c))];
                this.productFamilyOptions = families.map(fam => ({ label: fam, value: fam }));
            })
            .catch(error => {
                console.error('Error loading product groups:', error);
            });
    }

    // ─────────────────────────────────────────────
    // FAMILY CHANGE
    // ─────────────────────────────────────────────

        handleProductFamilyChange(event) {
        this.selectedProductFamilies = event.detail || [];

        if (!this.selectedProductFamilies.length) {
            this.showGroupPicklist  = false;
            this.groupNameOptions   = [];
            this.selectedGroupNames = [];
            return;
        }

        const filteredGroups  = this.allProductGroups
            .filter(r => this.selectedProductFamilies.includes(r.Product_Family__c));
        const uniqueGroups    = [...new Set(filteredGroups.map(r => r.Brand__c))];
        this.groupNameOptions = uniqueGroups.map(g => ({ label: g, value: g }));
        this.selectedGroupNames = this.selectedGroupNames.filter(n => uniqueGroups.includes(n));
        this.showGroupPicklist = true;
    }

    // ─────────────────────────────────────────────
    // GROUP CHANGE
    // ─────────────────────────────────────────────

    handleGroupNameChange(event) {
        this.selectedGroupNames = event.detail || [];
    }

    // ─────────────────────────────────────────────
    // REMOUNT HELPERS
    // ─────────────────────────────────────────────

    remountFamilyPicklist() {
        this.showFamilyPicklist = false;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showFamilyPicklist = true; }, 0);
    }

    remountGroupPicklist() {
        this.showGroupPicklist = false;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showGroupPicklist = true; }, 0);
    }

    // ─────────────────────────────────────────────
    // CLEAR ALL
    // ─────────────────────────────────────────────

        handleClearAll() {
            this.selectedProductFamilies = [];
            this.selectedGroupNames      = [];
            this.groupNameOptions        = [];
            this.showGroupPicklist       = false;
            this.showFamilyPicklist      = false;
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => { this.showFamilyPicklist = true; }, 0);
        }

    // ─────────────────────────────────────────────
    // SAVE
    // ─────────────────────────────────────────────

    handleSave() {
        if (this._isSaving) return;

        if (!this.selectedProductFamilies.length) {
            this.showToast('Error', 'Please select a Product Family', 'error');
            return;
        }
        if (!this.selectedGroupNames.length) {
            this.showToast('Error', 'Please select a Group Name', 'error');
            return;
        }

        this._isSaving = true;
        this.loading   = true;

        createTargetLine({
            targetId:        this.recordId,
            productFamilies: this.selectedProductFamilies,
            groupNames:      this.selectedGroupNames
        })
            .then(() => {
                this.showToast('Success', 'Target Line(s) created successfully', 'success');

                // Close modal first
                this.dispatchEvent(new CloseActionScreenEvent());

                // Then reload page AFTER modal closes
                setTimeout(() => {
                    window.location.reload();
                }, 500);
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || error.message, 'error');
                this._isSaving = false;
                this.loading   = false;
            });
    }

    // ─────────────────────────────────────────────
    // CLOSE
    // ─────────────────────────────────────────────

        handleClose() {
            this.dispatchEvent(new CloseActionScreenEvent());
        }

    handleSubmit(event) { event.preventDefault(); }
    handleError(event)  { console.error('Form error:', event.detail); }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ─────────────────────────────────────────────
    // UI GETTERS
    // ─────────────────────────────────────────────

    get progressStyle() {
        const f = this.selectedProductFamilies.length > 0 ? 50 : 0;
        const g = this.selectedGroupNames.length > 0 ? 50 : 0;
        return `width: ${f + g}%`;
    }

    get hasFamilySelected()   { return this.selectedProductFamilies.length > 0; }
    get selectedFamilyCount() { return this.selectedProductFamilies.length; }
    get familyCountSuffix()   { return this.selectedProductFamilies.length === 1 ? 'y' : 'ies'; }

    get hasGroupSelected()   { return this.selectedGroupNames.length > 0; }
    get selectedGroupCount() { return this.selectedGroupNames.length; }
    get groupCountSuffix()   { return this.selectedGroupNames.length === 1 ? '' : 's'; }

    get step2DotClass() {
        return this.hasFamilySelected ? 'step-dot step-dot-active' : 'step-dot step-dot-inactive';
    }
    get step2LabelClass() {
        return this.hasFamilySelected ? 'step-label step-label-active' : 'step-label step-label-inactive';
    }

    get summaryFamilyText() {
        return this.hasFamilySelected
            ? `${this.selectedFamilyCount}`
            : 'None';
    }
    get summaryGroupText() {
        return this.hasGroupSelected
            ? `${this.selectedGroupCount}`
            : 'None';
    }

    get summaryFamClass() { return this.hasFamilySelected ? 'summary-value-active' : 'summary-value'; }
    get summaryGrpClass() { return this.hasGroupSelected  ? 'summary-value-active' : 'summary-value'; }

    get isSaveDisabled() {
        return (
            this.selectedProductFamilies.length === 0 ||
            this.selectedGroupNames.length === 0       ||
            this._isSaving
        );
    }
}