import { LightningElement, track, api } from 'lwc';
import getProductGroups from '@salesforce/apex/TargetProductConfiguratorController.getProductGroups';
import createLeadProduct from '@salesforce/apex/LeadProductConfiguratorController.createLeadProduct';
import getExistingProductFamilies from '@salesforce/apex/LeadProductConfiguratorController.getExistingProductFamilies';
import getExistingProductGroups from '@salesforce/apex/LeadProductConfiguratorController.getExistingProductGroups';
import deleteLeadProductsByGroups from '@salesforce/apex/LeadProductConfiguratorController.deleteLeadProductsByGroups';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LeadAddProduct extends LightningElement {
    @api recordId;

    @track productFamilyOptions    = [];
    @track groupNameOptions        = [];
    @track selectedProductFamilies = [];
    @track selectedGroupNames      = [];
    @track lockedFamilies          = [];
    @track lockedGroups            = [];

    @track showFamilyPicklist = true;
    @track showGroupPicklist  = false;

    allProductGroups = [];
    loading          = false;
    _isSaving        = false;
    _lockedGroupMap  = {};

    // ── LIFECYCLE ──
    connectedCallback() {
        this.loadProductGroups();
    }

    // ── DATA LOADING ──
    loadProductGroups() {
        getProductGroups()
            .then(result => {
                this.allProductGroups = result || [];
                const families = [...new Set(
                    this.allProductGroups.map(r => r.Product_Family__c).filter(f => f)
                )];
                this.productFamilyOptions = families.map(fam => ({ label: fam, value: fam }));

                if (this.recordId) {
                    this.loadExistingFamilies();
                }
            })
            .catch(error => {
                console.error('Error loading product groups:', error);
            });
    }

    loadExistingFamilies() {
        getExistingProductFamilies({ leadId: this.recordId })
            .then(result => {
                this.lockedFamilies = (result || []).filter(f => f);
                return getExistingProductGroups({ leadId: this.recordId });
            })
            .then(groupResult => {
                const rows = groupResult || [];
                this.lockedGroups = rows.map(r => r.brand).filter(b => b);
                this._lockedGroupMap = {};
                rows.forEach(r => { this._lockedGroupMap[r.brand] = r.leadProductId; });

                if (this.lockedFamilies.length) {
                    this.selectedProductFamilies = [...this.lockedFamilies];
                    // Seed selectedGroupNames with locked groups BEFORE calling refresh
                    this.selectedGroupNames = [...this.lockedGroups];
                    this.refreshGroupOptions();
                }
            })
            .catch(error => {
                console.error('Error loading existing families/groups:', error);
            });
    }

    // Show the editable family dropdown ONLY when there are no locked families
    get showFamilyPicklistEditable() {
        return this.showFamilyPicklist && !this.hasLockedFamilies;
    }

    // ── FAMILY CHANGE ──
    handleProductFamilyChange(event) {
        const incoming = event.detail || [];
        const merged = [...new Set([...this.lockedFamilies, ...incoming])];
        this.selectedProductFamilies = merged;
        this.refreshGroupOptions();
    }

   refreshGroupOptions() {
    if (!this.selectedProductFamilies.length) {
        this.showGroupPicklist  = false;
        this.groupNameOptions   = [];
        this.selectedGroupNames = [];
        return;
    }

    const filteredGroups = this.allProductGroups
        .filter(r => this.selectedProductFamilies.includes(r.Product_Family__c));

    const uniqueGroups = [...new Set(filteredGroups.map(r => r.Brand__c).filter(g => g))];

    this.groupNameOptions = uniqueGroups
        .filter(g => !this.lockedGroups.includes(g))
        .map(g => ({ label: g, value: g }));

    const lockedPresent = this.lockedGroups.filter(g => uniqueGroups.includes(g));
    const userPicks = this.selectedGroupNames.filter(
        n => uniqueGroups.includes(n) && !this.lockedGroups.includes(n)
    );
    this.selectedGroupNames = [...new Set([...lockedPresent, ...userPicks])];

    this.showGroupPicklist = true;
}

    // ── GROUP CHANGE ──
    handleGroupNameChange(event) {
        const userPicks = event.detail || [];
        // Merge locked groups + new user picks (avoid duplicates)
        this.selectedGroupNames = [...new Set([...this.lockedGroups, ...userPicks])];
    }

    // ── REMOUNT HELPERS ──
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

    // ── CLEAR ALL ──
    handleClearAll() {
    this.selectedProductFamilies = [...this.lockedFamilies];
    this.selectedGroupNames      = [...this.lockedGroups];

    if (this.lockedFamilies.length) {
        this.refreshGroupOptions();
    } else {
        this.groupNameOptions  = [];
        this.showGroupPicklist = false;
    }

    this.showFamilyPicklist = false;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => { this.showFamilyPicklist = true; }, 0);
    }

    // ── REMOVE LOCKED GROUP (pill X click) ──
    handleRemoveLockedGroup(event) {
        const grp = event.currentTarget.dataset.group;
        this.lockedGroups = this.lockedGroups.filter(g => g !== grp);
        this.selectedGroupNames = this.selectedGroupNames.filter(g => g !== grp);
        this.refreshGroupOptions();
    }

    // ── SAVE ──
    handleSave() {
        if (this._isSaving) return;

        if (!this.selectedProductFamilies.length) {
            this.showToast('Error', 'Please select a Product Family', 'error');
            return;
        }

        // Groups removed by clicking X on locked pills
        const removedGroups = this.lockedGroups.filter(
            g => !this.selectedGroupNames.includes(g)
        );

        // Brand-new selections (not already on the lead)
        const newGroups = this.selectedGroupNames.filter(
            g => !this.lockedGroups.includes(g)
        );

        // Nothing changed
        if (!removedGroups.length && !newGroups.length) {
            this.showToast('Info', 'The lead already has the selected product associated with the family, so you can proceed.', 'info');
            return;
        }

        this._isSaving = true;
        this.loading   = true;

        // 1) Delete removed locked groups (if any)
        const deletePromise = removedGroups.length
            ? deleteLeadProductsByGroups({ leadId: this.recordId, brands: removedGroups })
            : Promise.resolve();

        deletePromise
            .then(() => {
                // 2) Create new selections (if any)
                if (newGroups.length) {
                    return createLeadProduct({
                        LeadId:          this.recordId,
                        productFamilies: this.selectedProductFamilies,
                        groupNames:      newGroups
                    });
                }
                return null;
            })
            .then(() => {
                this.showToast('Success', 'Lead Product(s) updated successfully', 'success');
                this.loading   = false;
                this._isSaving = false;
                this.handleClose();
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || error.message, 'error');
                this._isSaving = false;
                this.loading   = false;
            });
    }

    // ── CLOSE ──
    handleClose() {
        window.history.back();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            window.location.reload();
        }, 500);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ── UI GETTERS ──
    get hasLockedFamilies() { return this.lockedFamilies.length > 0; }
    get hasLockedGroups()   { return this.lockedGroups.length > 0; }

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
        return this.hasFamilySelected ? `${this.selectedFamilyCount}` : 'None';
    }
    get summaryGroupText() {
        return this.hasGroupSelected ? `${this.selectedGroupCount}` : 'None';
    }

    get summaryFamClass() { return this.hasFamilySelected ? 'summary-value-active' : 'summary-value'; }
    get summaryGrpClass() { return this.hasGroupSelected  ? 'summary-value-active' : 'summary-value'; }

    get isSaveDisabled() {
        if (this._isSaving) return true;
        if (this.selectedProductFamilies.length === 0) return true;

        // Allow save if a locked group was removed
        const hasRemoval = this.lockedGroups.some(g => !this.selectedGroupNames.includes(g));
        // Or a new group was added
        const hasNewSelection = this.selectedGroupNames.some(g => !this.lockedGroups.includes(g));

        return !hasRemoval && !hasNewSelection;
    }
}