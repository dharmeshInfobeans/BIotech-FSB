import { LightningElement, track, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import saveCustomClearanceCharges from '@salesforce/apex/MarketXraySectionBController.saveCustomClearanceCharges';
import checkUserAccess from '@salesforce/apex/MarketXRayController.checkUserAccess';
import checkExistingMarketXrayFormSectionB from '@salesforce/apex/MarketXraySectionBController.checkExistingMarketXrayFormSectionB';
//import getAllDistributor from '@salesforce/apex/MarketXraySectionBController.getAllDistributor';
import requestChange from '@salesforce/apex/MarketXrayChangeRequestController.requestChange';
import getFormIdForCurrentUser from '@salesforce/apex/MarketXrayChangeRequestController.getFormIdForCurrentUser';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FROM_INDIA_IOLS_LABEL from '@salesforce/label/c.From_India_IOLs';
import FROM_INDIA_SOLUTION_LABEL from '@salesforce/label/c.From_India_Solutions';
import FROM_INDIA_PHARMA_LABEL from '@salesforce/label/c.From_India_Pharma';
import FROM_IRELAND_IOLS_LABEL from '@salesforce/label/c.From_Ireland_IOLs';
import FROM_IRELAND_SOLUTION_LABEL from '@salesforce/label/c.From_Ireland_Solutions';
import FROM_IRELAND_PHARMA_LABEL from '@salesforce/label/c.From_Ireland_Pharma';
import ANY_OTHER_CHARGES_LABEL from '@salesforce/label/c.Any_other_Charges_Cost_if_any';
import SECTION_B_CATEGORY_WISE_COMPETITION_PRICE_LANDSCAPE from '@salesforce/label/c.Section_B_Category_wise_Competition_Price_Landscape';
import { CurrentPageReference } from 'lightning/navigation';

export default class MarketXraySectionB extends LightningElement {
    
    label = {FROM_INDIA_IOLS_LABEL, FROM_INDIA_SOLUTION_LABEL, FROM_INDIA_PHARMA_LABEL, FROM_IRELAND_IOLS_LABEL, 
                FROM_IRELAND_SOLUTION_LABEL, FROM_IRELAND_PHARMA_LABEL, ANY_OTHER_CHARGES_LABEL, SECTION_B_CATEGORY_WISE_COMPETITION_PRICE_LANDSCAPE};

    @track isPlusVisible = false;
    @track isMinusVisible = true;
    @track disableMarketXrayForm = false;
    @track showConfirmModal = false;
    @track showRequestChangeModal = false;
    @track isFormDisabled = false;
    @track distributorData = [];
    @track marketXrayFormId = null;
    @api recordId;
    wiredSectionBResult;
    currentURL;
    @track isDisable = false;
    finalUrl;
    @api userid;
    _recordId = null;
    @track hasEditAccess = false;
    @track hasReadAccess = false;

    @track customClearance = {
        "fromIndiaIOL" : "",
        "fromIndiaSolution" : "",
        "fromIndiaPharma" : "",
        "fromIrelandIOL" : "",
        "fromIrelandSolution" : "",
        "fromIrelandPharma" : "",
        "anyOtherCharges" : "",
        "marketXrayFormEditOrNot" : false,
        "currentFormUrl" : ''
    }

    // @wire(CurrentPageReference)
    // setCurrentPageReference(currentPageReference) {
    //     if (currentPageReference) {
    //        console.log('Page Reference:', currentPageReference);
    //        this.isDisable = currentPageReference?.state?.isDisable;
    //        console.log('this.isDisable===>>>',this.isDisable);  
    //     }
        
    // }

    // @wire(CurrentPageReference)
    // pageRef(ref) {
    //     if (ref?.attributes?.recordId) {
    //         this._recordId = ref.attributes.recordId;
    //         console.log('recordId from URL:', this._recordId); // ✅ will log correctly
    //         //this.loadProducts(this._recordId);
    //     }
    // }

    @wire(CurrentPageReference)
    pageRef(ref) {
        if (ref?.attributes?.recordId) {
            this._recordId = ref.attributes.recordId;
            console.log('recordId from URL:', this._recordId); // ✅ will log correctly
            //this.loadProducts(this._recordId);
            //console.log('OUTPUT checkUserAccess: ===>>>', checkUserAccess({recordId:this._recordId }));
            checkUserAccess({ recordId: this._recordId })
            .then(result => {
                this.hasReadAccess = result.Read;
                this.hasEditAccess = result.Edit;
                console.log('OUTPUT checkUserAccess:', result);
                console.log('Read Access:', this.hasReadAccess);
                console.log('Edit Access:', this.hasEditAccess);
            })
            .catch(error => {
                console.error('Error:', error);
            });
        }
        else{
           checkUserAccess({ recordId: null })
            .then(result => {
                this.hasReadAccess = result.Read;
                this.hasEditAccess = result.Edit;
            })
            .catch(error => {
                console.error('Error:', error);
            });
        }
    }

    get isSaveDisabled() {
        console.log('this.hasReadAccess isSaveDisabled', this.hasReadAccess);
        console.log('this.hasEditAccess====>>> isSaveDisabled', this.hasEditAccess);
        console.log('recordId =>', this._recordId);
        if (this.hasEditAccess && this._recordId) {
            this.isFormDisabled=false;
            return false;
        }
        if (this.hasEditAccess && !this._recordId) {
            return false;
        }
        return true;
    }

    get recordId() {
        return this._recordId;
    }


    connectedCallback() {
        this.loadFormId();
        // this.currentURL = window.location.href;
        // console.log('this.currentURL===== : ', this.currentURL);
        // this.finalURL = this.currentURL + '&formId=' + this.marketXrayFormId;
        // console.log('Final Combined URL:', this.finalURL);
    }
    
    loadFormId() {
        getFormIdForCurrentUser()
            .then(formId => {
                if (formId) {
                    this.marketXrayFormId = formId;
                    console.log('Market X-Ray Form ID:', this.marketXrayFormId);
                     this.currentURL = window.location.href;
                    console.log('this.currentURL===== : ', this.currentURL);
                    this.finalURL = this.currentURL + '&formId=' + this.marketXrayFormId;
                    console.log('Final Combined URL:', this.finalURL);
                    this.customClearance.currentFormUrl = this.finalURL;
                }
                console.log('this.customClearance000000000', this.customClearance); 
            })
            .catch(error => {
                console.error('Error loading form ID:', error);
            });
    }

    @wire(checkExistingMarketXrayFormSectionB,{userId:'$userid',recordId:'$_recordId'})
    wiredSectionBData(result) {
        this.wiredSectionBResult = result;
        
        if (result.data) {
            const { exists, data } = result.data;

            if (exists && data) {
                const mx = data;
                console.log('mx=======>>>>>>',mx);
                const clearanceRec = mx.Customs_Clearance_Charges__r && mx.Customs_Clearance_Charges__r[0];
                console.log('clearanceRec=======>>>>', clearanceRec);
                
                if (!clearanceRec) {
                    console.warn('No Customs_Clearance_Charges__r found on returned data');
                    this.isLoading = false;
                    return;
                }

                this.isFormDisabled = mx.IsMarketXrayFormEditable__c || false;

                this.customClearance = {
                    id: clearanceRec.Id || '',
                    fromIndiaIOL: clearanceRec.From_India_IOLs__c ? clearanceRec.From_India_IOLs__c : 0,
                    fromIndiaSolution: clearanceRec.From_India_Solutions__c ? clearanceRec.From_India_Solutions__c : 0,
                    fromIndiaPharma: clearanceRec.From_India_Pharma__c ? clearanceRec.From_India_Pharma__c : 0,
                    fromIrelandIOL: clearanceRec.From_Ireland_IOLs__c ? clearanceRec.From_Ireland_IOLs__c : 0,
                    fromIrelandSolution: clearanceRec.From_Ireland_Solutions__c ? clearanceRec.From_Ireland_Solutions__c : 0,
                    fromIrelandPharma: clearanceRec.From_Ireland_Pharma__c ? clearanceRec.From_Ireland_Pharma__c : 0,
                    anyOtherCharges: clearanceRec.Other_Charges__c ? clearanceRec.Other_Charges__c : 0,
                    marketXrayFormEditOrNot: mx.IsMarketXrayFormEditable__c || false,
                    currentFormUrl: this.finalURL ? this.finalURL : ''
                };

                this.distributorData = clearanceRec.DistributorLineItems__r || [];

                setTimeout(() => {
                    const summaryCmp = this.template.querySelector('c-show-biotech-category-and-product-range');
                    console.log('summaryCmp', summaryCmp);
                    if (summaryCmp) {
                        if (this.customClearance.fromIndiaIOL) {
                            summaryCmp.updateCustomsCharges('fromIndiaIOL', this.customClearance.fromIndiaIOL);
                        }
                        if (this.customClearance.fromIndiaSolution) {
                            summaryCmp.updateCustomsCharges('fromIndiaSolution', this.customClearance.fromIndiaSolution);
                        }
                        if (this.customClearance.fromIrelandIOL) {
                            summaryCmp.updateCustomsCharges('fromIrelandIOL', this.customClearance.fromIrelandIOL);
                        }
                        if (this.customClearance.fromIrelandSolution) {
                            summaryCmp.updateCustomsCharges('fromIrelandSolution', this.customClearance.fromIrelandSolution);
                        }
                    }
                }, 1000);

                console.log('this.distributorData ------------->>>>>>', this.distributorData);

            } else {
                console.log("No existing form found. Showing blank form.");
                this.distributorData = [];
                this.customClearance = {
                    "fromIndiaIOL" : "",
                    "fromIndiaSolution" : "",
                    "fromIndiaPharma" : "",
                    "fromIrelandIOL" : "",
                    "fromIrelandSolution" : "",
                    "fromIrelandPharma" : "",
                    "anyOtherCharges" : "",
                    "marketXrayFormEditOrNot" : false,
                    "currentFormUrl" : ''
                };
            }

            this.isLoading = false;

        } else if (result.error) {
            console.error('Error loading data wqiudgiuwegfuiwrg:', result.error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error Loading Data qsiudgwiugvfui3g',
                message: result.error.body?.message || result.error.message || 'Unable to load existing data.',
                variant: 'error',
                mode: 'sticky'
            }));
            this.isLoading = false;
        }
    }
    
    handleOnchange(event){
        const fieldName = event.target.name;
        console.log('fieldName : ', fieldName);
        const value = event.detail.value;
        console.log('value : ', value);
        let tempCustomClearance = JSON.parse(JSON.stringify(this.customClearance));
        tempCustomClearance[fieldName] = value;
        this.customClearance = tempCustomClearance;
        console.log('this.customClearance : ', this.customClearance);

        this.template.querySelector('c-show-biotech-category-and-product-range').updateCustomsCharges(fieldName, value);
    }

    handleHypenButtonClick() {
        this.isMinusVisible = true;
        this.isPlusVisible = false;
    }

    handlePlusButtonClick() {
        this.isPlusVisible = true;
        this.isMinusVisible = false;
    }

    get compClass() {
        return this.isPlusVisible ? '' : 'hide-section';
    }

    handleSaveButtonSectionB() {
        console.log('click button handleSaveButtonSectionB');
        const childData = this.template.querySelector('c-market-competitor-price-comparison').handleSave();
        console.log('childData==============>>>>>>>', childData);

        if(childData.length === 0){
            console.log('childData.length----->>>',childData.length);
            return;
        }

        

        const requiredFields = [
            'fromIndiaIOL',
            'fromIndiaSolution', 
            'fromIndiaPharma',
            'fromIrelandIOL',
            'fromIrelandSolution',
            'fromIrelandPharma'
        ];

        const emptyFields = requiredFields.filter(field => {
            const value = this.customClearance[field];
            return value === "" || value === null || value === undefined;
        });

        if (emptyFields.length > 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Required Fields Missing',
                message: 'Importation and clearance cost details are required.',
                variant: 'warning',
                mode: 'dismissable'
            }));
            return Promise.reject('Validation failed'); 
        }

        const isValidPercentage = (value) => {
            const numValue = parseFloat(value);
            return !isNaN(numValue) && numValue >= 0 && numValue <= 100;
        };

        const invalidFields = requiredFields.filter(field => 
            !isValidPercentage(this.customClearance[field])
        );

        if (invalidFields.length > 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Invalid Input',
                message: 'Please enter valid percentages (0-100) for all fields.',
                variant: 'warning',
                mode: 'dismissable'
            }));
            return Promise.reject('Validation failed');
        }

        if (this.disableMarketXrayForm === true) {
            this.customClearance.marketXrayFormEditOrNot = true;
        } else if (this.disableMarketXrayForm === false) {
            this.customClearance.marketXrayFormEditOrNot = false;
        }

        let finalObject = {
            "customClearance": JSON.parse(JSON.stringify(this.customClearance)),
            "distributorLineItem": JSON.parse(JSON.stringify(childData))
        };

        console.log('Custom Clearance final object =======>>>>: ', finalObject);

        return saveCustomClearanceCharges({ customClearance: JSON.stringify(finalObject) ,recordId: this._recordId})
            .then(result => {
                console.log('Save result:', result);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Section B — Category-wise Competition Price Landscape data saved successfully.',
                    variant: 'success',
                    mode: 'dismissable'
                }));
                
                return refreshApex(this.wiredSectionBResult);
            })
            .catch(error => {
                console.error('Error while saving Custom Clearance:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error saving data',
                    message: error.body?.message || 'An error occurred while saving.',
                    variant: 'error',
                    mode: 'sticky'
                }));
                throw error;
            });
    }

    handleShowConfirmModel() {
        this.showConfirmModal = true;
    }

    async handleSumbit(){
        this.disableMarketXrayForm = true;
        this.showConfirmModal = false;
        
        try {
            console.log('========== SUBMIT STARTED ==========');
            
            await this.handleSaveButtonSectionB();
            console.log('Section B saved successfully');
            
            this.dispatchEvent(new CustomEvent('callparent', {
                detail: { sectionBSaved: true }
            }));
            
            console.log('Submit completed successfully');
            
        } catch (error) {
            console.error('Error during submit:', error);
            this.disableMarketXrayForm = false;
        }
    }

    handleCancelSubmit() {
        this.showConfirmModal = false;
    }
   
    handleRequestChange() {
        this.showRequestChangeModal = true;
    }

    handleConfirmRequestChange() {
        console.log('========= CONFIRM REQUEST CHANGE CLICKED =========');
        console.log('Form ID before check:', this.marketXrayFormId);
        
        if (!this.marketXrayFormId) {
            console.error('ERROR: Form ID is null or undefined!');
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Form ID not found. Please refresh the page.',
                variant: 'error',
                mode: 'sticky'
            }));
            return;
        }

        console.log('Calling Apex with Form ID:', this.marketXrayFormId);
        console.log('Apex method: requestChange');

        requestChange({ formId: this.marketXrayFormId })
            .then(result => {
                console.log('SUCCESS - Request change result:', result);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Request Submitted',
                    message: 'Your change request has been sent to the Admin team. You will be notified once approved.',
                    variant: 'success',
                    mode: 'dismissable'
                }));
                this.showRequestChangeModal = false;
            })
            .catch(error => {
                console.log('error on sending notification ', error.message);
                
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to submit change request.',
                    variant: 'error',
                    mode: 'sticky'
                }));
                this.showRequestChangeModal = false;
            });
    }

    handleCancelRequestChange() {
        console.log('========= CANCEL REQUEST CHANGE CLICKED =========');
        this.showRequestChangeModal = false;
    }
}