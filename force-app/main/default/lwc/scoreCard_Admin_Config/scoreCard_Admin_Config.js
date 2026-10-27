import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getScorecardStructure from '@salesforce/apex/ScorecardFormController.getScorecardStructure';
import updateSectionWeightage from '@salesforce/apex/ScorecardFormController.updateSectionWeightage';
import batchUpdateOptionScores from '@salesforce/apex/ScorecardFormController.batchUpdateOptionScores';
import batchUpdateQuestions from '@salesforce/apex/ScorecardFormController.batchUpdateQuestions';
import getAvailableRegions from '@salesforce/apex/ScorecardFormController.getAvailableRegions';
import getRegionApprover from '@salesforce/apex/ScorecardFormController.getRegionApprover';
import saveRegionApprover from '@salesforce/apex/ScorecardFormController.saveRegionApprover';

export default class ScoreCard_Admin_Config extends LightningElement {
    @track sections = [];
    @track selectedSectionKey = '';
    @track isLoading = true;
    @track isSaving = false;
    error = null;
    successMessage = null;
    
    // Track changes for batch update
    @track scoreChanges = {};
    @track weightageChange = null;
    @track questionChanges = {};
    
    // Region Approver Configuration
    @track activeTab = 'scorecard'; // 'scorecard' or 'regionApprovers'
    @track regionOptions = [];
    @track selectedRegion = '';
    @track approver1Id = '';
    @track approver2Id = '';
    @track regionApproverRecordId = '';
    @track isLoadingRegionApprover = false;
    @track formKey = 0; // Key to force form re-render

    @wire(getScorecardStructure)
    wiredScorecardData({ error, data }) {
        if (data) {
            // Deep copy and sort by order field
            this.sections = JSON.parse(JSON.stringify(data));
            
            // Sort sections by order field (ascending order)
            this.sections.sort((a, b) => {
                const orderA = a.order || 999;
                const orderB = b.order || 999;
                return orderA - orderB;
            });
            
            if (this.sections.length > 0) {
                this.selectedSectionKey = this.sections[0].sectionKey;
            }
            this.isLoading = false;
            this.error = null;
        } else if (error) {
            this.error = 'Error loading scorecard structure: ' + (error.body ? error.body.message : error.message);
            this.isLoading = false;
            console.error('Error:', error);
        }
    }

    get selectedSection() {
        return this.sections.find(section => section.sectionKey === this.selectedSectionKey);
    }

    handleTabSelect(event) {
        this.selectedSectionKey = event.detail.value;
        this.clearMessages();
    }

    handleWeightageChange(event) {
        const weightage = parseFloat(event.target.value);
        const sectionKey = event.target.dataset.sectionKey;
        
        if (sectionKey) {
            const section = this.sections.find(s => s.sectionKey === sectionKey);
            if (section) {
                section.weightage = weightage;
                this.weightageChange = {
                    sectionKey: sectionKey,
                    weightage: weightage
                };
            }
        }
    }

    handleScoreChange(event) {
        const score = parseFloat(event.target.value);
        const optionKey = event.target.dataset.optionKey;
        const sectionKey = event.target.dataset.sectionKey;
        
        if (optionKey && sectionKey) {
            // Update the score in the data structure
            const section = this.sections.find(s => s.sectionKey === sectionKey);
            if (section && section.questions) {
                for (let question of section.questions) {
                    if (question.options) {
                        const option = question.options.find(opt => opt.optionKey === optionKey);
                        if (option) {
                            option.score = score;
                            // Track the change
                            this.scoreChanges[optionKey] = score;
                            break;
                        }
                    }
                }
            }
        }
    }

    handleQuestionMandatoryChange(event) {
        const isMandatory = event.target.checked;
        const questionKey = event.target.dataset.questionKey;
        const sectionKey = event.target.dataset.sectionKey;
        
        if (questionKey && sectionKey) {
            const section = this.sections.find(s => s.sectionKey === sectionKey);
            if (section && section.questions) {
                const question = section.questions.find(q => q.questionKey === questionKey);
                if (question) {
                    question.isMandatory = isMandatory;
                    // Track the change
                    if (!this.questionChanges[questionKey]) {
                        this.questionChanges[questionKey] = {};
                    }
                    this.questionChanges[questionKey].isMandatory = isMandatory;
                }
            }
        }
    }

    handleQuestionActiveChange(event) {
        const isActive = event.target.checked;
        const questionKey = event.target.dataset.questionKey;
        const sectionKey = event.target.dataset.sectionKey;
        
        if (questionKey && sectionKey) {
            const section = this.sections.find(s => s.sectionKey === sectionKey);
            if (section && section.questions) {
                const question = section.questions.find(q => q.questionKey === questionKey);
                if (question) {
                    question.isActive = isActive;
                    // Track the change
                    if (!this.questionChanges[questionKey]) {
                        this.questionChanges[questionKey] = {};
                    }
                    this.questionChanges[questionKey].isActive = isActive;
                }
            }
        }
    }

    async handleSaveWeightage() {
        if (!this.weightageChange) {
            this.showToast('No Changes', 'No weightage changes to save', 'warning');
            return;
        }

        this.isSaving = true;
        this.clearMessages();

        try {
            const jobId = await updateSectionWeightage({
                sectionKey: this.weightageChange.sectionKey,
                weightage: this.weightageChange.weightage
            });

            this.showToast('Success', 'Weightage update queued. Job ID: ' + jobId, 'success');
            this.successMessage = 'Weightage update queued. Please check deployment status.';
            this.weightageChange = null;
        } catch (error) {
            this.error = 'Error saving weightage: ' + (error.body ? error.body.message : error.message);
            this.showToast('Error', this.error, 'error');
            console.error('Error saving weightage:', error);
        } finally {
            this.isSaving = false;
        }
    }

    async handleSaveAll() {
        const changesToSave = [];
        
        // Add weightage change if exists
        if (this.weightageChange) {
            changesToSave.push('weightage');
        }

        // Add score changes if exist
        if (Object.keys(this.scoreChanges).length > 0) {
            changesToSave.push('scores');
        }

        // Add question changes if exist
        if (Object.keys(this.questionChanges).length > 0) {
            changesToSave.push('questions');
        }

        if (changesToSave.length === 0) {
            this.showToast('No Changes', 'No changes to save', 'warning');
            return;
        }

        this.isSaving = true;
        this.clearMessages();

        try {
            // Save weightage if changed
            if (this.weightageChange) {
                await updateSectionWeightage({
                    sectionKey: this.weightageChange.sectionKey,
                    weightage: this.weightageChange.weightage
                });
            }

            // Save score changes if any
            if (Object.keys(this.scoreChanges).length > 0) {
                const scoreMap = { ...this.scoreChanges };

                await batchUpdateOptionScores({
                    optionScoreMap: scoreMap
                });
            }

            // Save question changes if any
            if (Object.keys(this.questionChanges).length > 0) {
                const questionUpdates = { ...this.questionChanges };

                const jobId = await batchUpdateQuestions({
                    questionUpdates: questionUpdates
                });

                this.showToast('Success', 'All changes queued for deployment. Job ID: ' + jobId, 'success');
                this.successMessage = 'All changes queued for deployment. Please check deployment status.';
            } else if (Object.keys(this.scoreChanges).length > 0 || this.weightageChange) {
                this.showToast('Success', 'Changes queued for deployment', 'success');
                this.successMessage = 'Changes queued for deployment. Please check deployment status.';
            }

            // Clear changes after successful save
            this.scoreChanges = {};
            this.weightageChange = null;
            this.questionChanges = {};

        } catch (error) {
            this.error = 'Error saving changes: ' + (error.body ? error.body.message : error.message);
            this.showToast('Error', this.error, 'error');
            console.error('Error saving changes:', error);
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    clearMessages() {
        this.error = null;
        this.successMessage = null;
    }

    // Region Approver Configuration Methods
    @wire(getAvailableRegions)
    wiredRegions({ error, data }) {
        if (data) {
            this.regionOptions = data.map(region => ({
                label: region.label,
                value: region.value
            }));
        } else if (error) {
            console.error('Error loading regions:', error);
        }
    }

    handleMainTabChange(event) {
        event.preventDefault();
        const tabValue = event.currentTarget.dataset.tab;
        this.activeTab = tabValue;
        this.clearMessages();
        // Reset region approver fields when switching tabs
        if (this.activeTab === 'regionApprovers') {
            this.selectedRegion = '';
            this.approver1Id = '';
            this.approver2Id = '';
            this.regionApproverRecordId = '';
        }
    }

    get isScorecardTabActive() {
        return this.activeTab === 'scorecard';
    }

    get isRegionApproversTabActive() {
        return this.activeTab === 'regionApprovers';
    }

    handleRegionChange(event) {
        this.selectedRegion = event.detail.value;
        this.clearMessages();
        this.loadRegionApprover();
    }

    loadRegionApprover() {
        if (!this.selectedRegion) {
            this.approver1Id = '';
            this.approver2Id = '';
            this.regionApproverRecordId = '';
            this.formKey = 0; // Reset form key
            return;
        }

        this.isLoadingRegionApprover = true;
        getRegionApprover({ region: this.selectedRegion })
            .then(result => {
                if (result && result.recordId) {
                    // Existing record found - set record ID so lightning-record-edit-form can load it
                    this.regionApproverRecordId = result.recordId;
                    this.approver1Id = result.approver1Id || '';
                    this.approver2Id = result.approver2Id || '';
                } else {
                    // No existing record - clear record ID so form can create new record
                    this.approver1Id = '';
                    this.approver2Id = '';
                    this.regionApproverRecordId = null; // Use null for new records
                }
                // Increment form key to force form re-render
                this.formKey = Date.now();
                this.isLoadingRegionApprover = false;
            })
            .catch(error => {
                console.error('Error loading region approver:', error);
                this.error = 'Error loading region approver: ' + (error.body ? error.body.message : error.message);
                this.showToast('Error', this.error, 'error');
                this.isLoadingRegionApprover = false;
            });
    }

    handleFormLoad(event) {
        // Form has loaded - fields should be visible now
        console.log('Form loaded with record ID:', this.regionApproverRecordId);
    }

    handleApprover1Change(event) {
        // For lookup fields in lightning-input-field, value can be a string (Id) or array with objects
        const value = event.detail.value;
        console.log('Approver1 change event - value:', value, 'type:', typeof value, 'isArray:', Array.isArray(value));
        
        // Extract the ID from various possible formats
        let extractedId = '';
        
        if (!value || value === null || value === undefined) {
            extractedId = '';
        } else if (typeof value === 'string') {
            // Simple string ID (most common case)
            extractedId = value;
        } else if (Array.isArray(value)) {
            // Array format: [{id: 'xxx', label: 'xxx'}] or ['xxx']
            if (value.length > 0) {
                const firstItem = value[0];
                if (typeof firstItem === 'string') {
                    extractedId = firstItem;
                } else if (firstItem && typeof firstItem === 'object') {
                    extractedId = firstItem.id || firstItem.Id || firstItem.value || '';
                }
            }
        } else if (value && typeof value === 'object') {
            // Object format: {id: 'xxx', label: 'xxx'}
            extractedId = value.id || value.Id || value.value || '';
        }
        
        this.approver1Id = extractedId;
        console.log('Extracted Approver1 ID:', this.approver1Id);
        this.clearMessages();
    }

    handleApprover2Change(event) {
        // For lookup fields in lightning-input-field, value can be a string (Id) or array with objects
        const value = event.detail.value;
        console.log('Approver2 change event - value:', value, 'type:', typeof value, 'isArray:', Array.isArray(value));
        
        // Extract the ID from various possible formats
        let extractedId = '';
        
        if (!value || value === null || value === undefined) {
            extractedId = '';
        } else if (typeof value === 'string') {
            // Simple string ID (most common case)
            extractedId = value;
        } else if (Array.isArray(value)) {
            // Array format: [{id: 'xxx', label: 'xxx'}] or ['xxx']
            if (value.length > 0) {
                const firstItem = value[0];
                if (typeof firstItem === 'string') {
                    extractedId = firstItem;
                } else if (firstItem && typeof firstItem === 'object') {
                    extractedId = firstItem.id || firstItem.Id || firstItem.value || '';
                }
            }
        } else if (value && typeof value === 'object') {
            // Object format: {id: 'xxx', label: 'xxx'}
            extractedId = value.id || value.Id || value.value || '';
        }
        
        this.approver2Id = extractedId;
        console.log('Extracted Approver2 ID:', this.approver2Id);
        this.clearMessages();
    }

    async handleSaveRegionApprover() {
        if (!this.selectedRegion) {
            this.showToast('Validation Error', 'Please select a region', 'error');
            return;
        }

        if (!this.approver1Id || this.approver1Id === '') {
            this.showToast('Validation Error', 'Approver 1 is required', 'error');
            return;
        }

        this.isSaving = true;
        this.clearMessages();

        try {
            // Ensure approver1Id and approver2Id are valid string IDs (not objects or arrays)
            // Convert to string and trim to handle any edge cases
            const approver1IdValue = this.approver1Id ? String(this.approver1Id).trim() : null;
            const approver2IdValue = (this.approver2Id && this.approver2Id !== '') ? String(this.approver2Id).trim() : null;

            if (!approver1IdValue || approver1IdValue === '' || approver1IdValue === 'null' || approver1IdValue === 'undefined') {
                this.showToast('Validation Error', 'Approver 1 is required', 'error');
                this.isSaving = false;
                return;
            }

            console.log('Saving region approvers - Region:', this.selectedRegion, 'Approver1:', approver1IdValue, 'Approver2:', approver2IdValue);

            const recordId = await saveRegionApprover({
                region: this.selectedRegion,
                approver1Id: approver1IdValue,
                approver2Id: approver2IdValue,
                recordId: this.regionApproverRecordId
            });

            this.regionApproverRecordId = recordId;
            this.showToast('Success', 'Region approvers saved successfully', 'success');
            this.successMessage = 'Region approvers saved successfully';
        } catch (error) {
            this.error = 'Error saving region approvers: ' + (error.body ? error.body.message : error.message);
            this.showToast('Error', this.error, 'error');
            console.error('Error saving region approvers:', error);
        } finally {
            this.isSaving = false;
        }
    }

    get regionApproverTabClass() {
        return this.activeTab === 'regionApprovers' ? 'slds-is-active active' : '';
    }

    get scorecardTabClass() {
        return this.activeTab === 'scorecard' ? 'slds-is-active active' : '';
    }
}