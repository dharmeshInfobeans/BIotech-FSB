import { LightningElement, track, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import saveMarketXrayData from '@salesforce/apex/MarketXRayController.saveMarketXrayData';
import checkExistingMarketXrayForm from '@salesforce/apex/MarketXRayController.checkExistingMarketXrayForm';
import checkUserAccess from '@salesforce/apex/MarketXRayController.checkUserAccess';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SECTION_A_MARKET_INSIGHT from '@salesforce/label/c.Section_A_Market_Insight';
import TOTAL_POPULATION_IN_MILLIONS_LABEL from '@salesforce/label/c.Total_Population_in_Millions';
import AVERAGE_AGE_OF_POPULATION_LABEL from '@salesforce/label/c.Average_Age_of_Population';
import CATARACT_IOLS_IMPLANTED_YEAR_LABEL from '@salesforce/label/c.Cataract_IOLs_Implanted_year';
import NUMBER_OF_CATARACT_SURGEONS_LABEL from '@salesforce/label/c.Number_of_Cataract_Surgeons';
import PHAKIC_IOLS_IMPLANTED_YEAR_LABEL from '@salesforce/label/c.Phakic_IOLs_Implanted_year';
import REIMBURSEMENT_SITUATION_VALUE_LABEL from '@salesforce/label/c.Reimbursement_Situation_Value';
import FIRST_3_BRANDS_WITH_HIGHEST_MARKET_SHARE_MONOFOCALS_LABEL from '@salesforce/label/c.First_3_brands_with_highest_market_share_Monofocals';
import FIRST_3_BRANDS_WITH_HIGHEST_MARKET_SHARE_PRESBYOPIA_CORRECTING_IOLS_LABEL from '@salesforce/label/c.First_3_brands_with_highest_market_share_Presbyopia_correcting_IOLs';
import SR_NO_LABEL from '@salesforce/label/c.Sr_No';
import FOR_MONOFOCAL from '@salesforce/label/c.For_Monofocal';
import FOR_PRESBYOPIA from '@salesforce/label/c.For_Presbyopia_Correcting';
import { CurrentPageReference } from 'lightning/navigation';

export default class MarketXraySectionA extends LightningElement {

    label = {FOR_PRESBYOPIA, FOR_MONOFOCAL, SR_NO_LABEL, FIRST_3_BRANDS_WITH_HIGHEST_MARKET_SHARE_MONOFOCALS_LABEL, FIRST_3_BRANDS_WITH_HIGHEST_MARKET_SHARE_PRESBYOPIA_CORRECTING_IOLS_LABEL, SECTION_A_MARKET_INSIGHT, TOTAL_POPULATION_IN_MILLIONS_LABEL, AVERAGE_AGE_OF_POPULATION_LABEL, CATARACT_IOLS_IMPLANTED_YEAR_LABEL, NUMBER_OF_CATARACT_SURGEONS_LABEL, PHAKIC_IOLS_IMPLANTED_YEAR_LABEL, REIMBURSEMENT_SITUATION_VALUE_LABEL};
    
    @track table1Data = [];
    @track table2Data = [];
    @track isLoading = true;
    @track isFormDisabled = false;
    @api isCommingFromParent = false;
    @api userid;

    // Wire result ko store karne ke liye
    wiredMarketXrayResult;

    @track marketXray = {
        "totalPopulation" : "",
        "averageAgePopulation" : "",
        "cataractIOLsImplantedYear" : "",
        "numberOfCataractSurgeons" : "",
        "phakicIOLsImplantedYear" : "",
        "reimbursementSitutionAndValue" : "",
        "checkMarketXrayEditOrNot": false
    }

    @track monofocalsKeyAccounts = [
        { id: 1, MonofocalHospitalCenterName : '', PresbyopiaHospitalCenterName : ''},
        { id: 2, MonofocalHospitalCenterName : '', PresbyopiaHospitalCenterName : ''},
        { id: 3, MonofocalHospitalCenterName : '', PresbyopiaHospitalCenterName : ''},
        { id: 4, MonofocalHospitalCenterName : '', PresbyopiaHospitalCenterName : ''},
        { id: 5, MonofocalHospitalCenterName : '', PresbyopiaHospitalCenterName : ''}
    ];

    _recordId = null;
    @track hasEditAccess = false;
    @track hasReadAccess = false;

    // @wire(CurrentPageReference)
    // pageRef(ref) {
    //     if (ref?.attributes?.recordId) {
    //         this._recordId = ref.attributes.recordId;
    //         console.log('recordId from URL:', this._recordId); // ✅ will log correctly
    //     }
    // }

    // @wire(CurrentPageReference)
    // pageRef(ref) {
    //     if (ref?.attributes?.recordId) {
    //         this._recordId = ref.attributes.recordId;
    //     }

    //     checkUserAccess({ recordId: this._recordId })
    //         .then(result => {
    //             this.hasEditAccess = result.Edit;
    //             this.hasReadAccess = result.Read;
    //         })
    //         .catch(error => console.error('Error in checkUserAccess:', error));
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
    

    @wire(checkExistingMarketXrayForm,{userId:'$userid',recordId:'$_recordId'})
    wiredMarketXray(result) {
        this.wiredMarketXrayResult = result;
        
        if (result.data) {
            console.log('result.data section A → ->>>>', result.data);
            console.log('result.data section A → ', JSON.stringify(result.data));

            if (result.data.exists && result.data.data) {
                const mx = result.data.data;
                console.log('mx section A → ', mx);

                this.isFormDisabled = mx.IsMarketXrayFormEditable__c || false;

                let sectionA = mx.Market_X_Rays__r?.[0];

                if (!sectionA) {
                    console.error('No Market_X_Rays__r found');
                    this.isLoading = false;
                    return;
                }

                this.marketXray = {
                    id: sectionA.Id || '',
                    totalPopulation: sectionA.Total_Population_In_Millions__c || '',
                    averageAgePopulation: sectionA.Avarage_age_of_population__c || '',
                    cataractIOLsImplantedYear: sectionA.Number_of_cataract_IOLs_implanted_per_yr__c || '',
                    numberOfCataractSurgeons: sectionA.Number_of_Cataract_Surgeons__c || '',
                    phakicIOLsImplantedYear: sectionA.Number_of_Phakic_IOLs_Implanted_per_Year__c || '',
                    reimbursementSitutionAndValue: sectionA.Reimbursement_Situation_Value__c || '',
                };

                if (sectionA.Market_Key_Accounts__r && sectionA.Market_Key_Accounts__r.length > 0) {
                    let monofocalAccounts = sectionA.Market_Key_Accounts__r.filter(a => a.Category__c === 'Monofocal');
                    let presbyopiaAccounts = sectionA.Market_Key_Accounts__r.filter(a => a.Category__c === 'Presbyopia');

                    this.monofocalsKeyAccounts = this.monofocalsKeyAccounts.map((row, index) => {
                        return {
                            id: row.id,
                            monofocalId: monofocalAccounts[index]?.Id,
                            MonofocalHospitalCenterName: monofocalAccounts[index]?.Hospital_Center_Name__c || '',
                            presbyopiaId: presbyopiaAccounts[index]?.Id,
                            PresbyopiaHospitalCenterName: presbyopiaAccounts[index]?.Hospital_Center_Name__c || '',
                        };
                    });
                }

                setTimeout(() => {
                    const tables = this.template.querySelectorAll('c-market-xray-brand-table');

                    if (tables.length >= 2 && sectionA.Brand_Market_Shares__r) {
                        let monoData = sectionA.Brand_Market_Shares__r
                            .filter(b => b.Category__c === 'Monofocal')
                            .map(b => ({
                                id: b.Id,
                                brandName: b.Brand_Name__c || '',
                                annualSales: b.Annual_Sales_in_Qty__c ? String(b.Annual_Sales_in_Qty__c) : '',
                                distributor: b.Name_of_Distributor_Selling_This_Brand__c || '',
                                percentageShare: b.Percentage_Share__c || ''
                            }));

                        let presData = sectionA.Brand_Market_Shares__r
                            .filter(b => b.Category__c === 'Presbyopia')
                            .map(b => ({
                                id: b.Id,
                                brandName: b.Brand_Name__c || '',
                                annualSales: b.Annual_Sales_in_Qty__c ? b.Annual_Sales_in_Qty__c : '',
                                distributor: b.Name_of_Distributor_Selling_This_Brand__c || '',
                                percentageShare: b.Percentage_Share__c || ''
                            }));

                        tables[0].setTableData(monoData);
                        tables[1].setTableData(presData);
                    }
                }, 300);

            } else {
                console.log("No existing form found. Showing blank form.");
            }

            this.isLoading = false;
        } else if (result.error) {
            console.error('Error loading data: section A >> ', result.error);
            this.isLoading = false;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Error Loading Data',
                message: result.error.body?.message || 'Unable to load data.',
                variant: 'error',
                mode: 'sticky'
            }));
        }
    }

    handleOnchange(event){
        const fieldName = event.target.name;
        const value = event.detail.value;
        let tempMarketXray = JSON.parse(JSON.stringify(this.marketXray));
        tempMarketXray[fieldName] = value;
        this.marketXray = tempMarketXray;
    } 

    handleOnchangeKeyAccounts(event) {
        const category = event.target.name;
        const id = parseInt(event.target.dataset.id, 10);
        const value = event.target.value;

        this.monofocalsKeyAccounts = this.monofocalsKeyAccounts.map(row =>
            row.id === id ? { ...row, [category]: value } : row
        );
    }

    @api
    handleSaveButton(){
        const tables = this.template.querySelectorAll('c-market-xray-brand-table');
        
        if (tables.length >= 2) {
            this.table1Data = tables[0].getTableData();
            this.table2Data = tables[1].getTableData();

            let tempmonofocalsKeyAccounts = JSON.parse(JSON.stringify(this.monofocalsKeyAccounts));

            let monofocalsObj = [];
            let presbyopiaObj = [];
            
            tempmonofocalsKeyAccounts.forEach(ele => {
                monofocalsObj.push({"MonofocalHospitalCenterName": ele.MonofocalHospitalCenterName, "id": ele.monofocalId, "category": 'Monofocal'});
                presbyopiaObj.push({"PresbyopiaHospitalCenterName": ele.PresbyopiaHospitalCenterName, "id": ele.presbyopiaId, "category": 'Presbyopia'});
            });
            
            let finalObject = {
                "markeyXray": JSON.parse(JSON.stringify(this.marketXray)),
                "monofocals": JSON.parse(JSON.stringify(monofocalsObj)),
                "presbyopia": JSON.parse(JSON.stringify(presbyopiaObj)),
                "brandMonofocals": JSON.parse(JSON.stringify(tables[0].getTableData())),
                "brandPresbyopia": JSON.parse(JSON.stringify(tables[1].getTableData()))
            };

            const hasEmptyInMarketXray = Object.values(this.marketXray).some(value => value === "");
            const hasEmptymonofocalsObj = monofocalsObj.some(obj => Object.values(obj).some(v => v === ""));
            const hasEmptypresbyopiaObj = presbyopiaObj.some(obj => Object.values(obj).some(v => v === ""));
            const hasEmptybrandMonofocals = tables[0].getTableData().some(obj => Object.values(obj).some(v => v === ""));
            const hasEmptybrandPresbyopia = tables[1].getTableData().some(obj => Object.values(obj).some(v => v === ""));

            if(hasEmptyInMarketXray){
                this.dispatchEvent(new ShowToastEvent({title: 'Required Fields Missing', message: 'Market insight data is incomplete. Please complete all required inputs in Section A to proceed.', variant: 'warning', mode: 'dismissable'}));
                return;
            }
            if(hasEmptybrandMonofocals){
                this.dispatchEvent(new ShowToastEvent({title: 'Required Fields Missing', message: 'Monofocal market share insights are incomplete. Please provide the top 3 brands.', variant: 'warning', mode: 'dismissable'}));
                return;
            }
            if(hasEmptybrandPresbyopia){
                this.dispatchEvent(new ShowToastEvent({title: 'Required Fields Missing', message: 'Presbyopia-correcting IOL market share insights are incomplete. Please provide the top 3 brands.', variant: 'warning', mode: 'dismissable'}));
                return;
            }
            if(hasEmptymonofocalsObj){
                this.dispatchEvent(new ShowToastEvent({title: 'Required Fields Missing', message: 'Monofocal Key account coverage data is incomplete. Please list the top 5 key accounts in the country.', variant: 'warning', mode: 'dismissable'}));
                return;
            }
            if(hasEmptypresbyopiaObj){
                this.dispatchEvent(new ShowToastEvent({title: 'Required Fields Missing', message: 'Presbyopia Key account coverage data is incomplete. Please list the top 5 key accounts in the country.', variant: 'warning', mode: 'dismissable'}));
                return;
            }
            console.log('final object =======>>>>: ', finalObject);
            console.log('final object : ', JSON.stringify(finalObject));

            this.isLoading = true;

            return saveMarketXrayData({ marketXrayData: JSON.stringify(finalObject),recordId:this._recordId})
                .then(result => {
                    console.log('Save result:', result);
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Section A — Market Insight data saved successfully.',
                        variant: 'success',
                        mode: 'dismissable'
                    }));

                    return refreshApex(this.wiredMarketXrayResult);
                })
                .catch(error => {
                    this.isLoading = false;
                    console.error('Error while saving:', error);
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error saving data',
                        message: error.body?.message || 'An error occurred.',
                        variant: 'error',
                        mode: 'sticky'
                    }));
                });
        } else {
            console.error('Could not find both brand tables');
        }
    }
    
    @api 
    handleSumbit(){
        console.log('hanlde sumbit called from parent section A', this.isCommingFromParent);
        return this.handleSaveButton();
    }
}