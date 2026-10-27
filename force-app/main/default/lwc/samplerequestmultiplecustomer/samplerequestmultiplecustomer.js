import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchDropdownOptions from '@salesforce/apex/SampleRequestLWCcontroller.fetchDropdownOptionsformultiplecustomer';
//------------------------------------------------
import getsamplerequestlabel from '@salesforce/apex/SampleRequestLWCcontroller.getCustomLabels';

import getAccountdata from '@salesforce/apex/SampleRequestLWCcontroller.getcustomerdata';
import getcountrieslist from '@salesforce/apex/SampleRequestLWCcontroller.getCountries';
import modal from "@salesforce/resourceUrl/modal";
import { loadStyle } from "lightning/platformResourceLoader";
//------------------------------------------------
import fetchSampleRequestProduct from '@salesforce/apex/SampleRequestLWCcontroller.fetchmultiplecustomerSampleRequestProduct';
import saveSampleRequestData from '@salesforce/apex/SampleRequestLWCcontroller.saveSampleRequestDataformultiplecustomer';


export default class Samplerequestmultiplecustomer extends LightningElement {
    @track showSampleList = [];
    @api recordId;
    @track saveButtonError = true;
    @track sampleRequestProduct = [];
    @track productModelTitle = '';
    @track sphericalPowerTitle = '';
    @track cylindricalPowerTitle = '';
    @track axisAngleTitle = '';
    @track diaptorTitle = '';
    @track selectedData = [];
    @track remark = '';
    //---------------------------------------------//////////////////////////////////
    // @api recordId;
    @track getsplrqstlabel = {};
    @track accountList = [];
    @track leadlistdata = [];
    @track filteredAccountList = [];
    @track searchTerm = '';
    @track searchTermlead = '';
    selectedRecordIds = new Set();
    selectedleadRecordIds = new Set();

    @track nextDisabled = true;
    @track selectedAccId = [];
    @track selectCountry = '';
    @track countries = '';
    @track isAllSelected = false;
    @track isAllSelectedlead = false;
    @track selectedAccountNames;
    @track selectedAccountCount = 0;
    @track selectedleadCount = 0;
    @track showsamplerequesttale = true;
    // paginatedData = [];
    //-------------------
    @track disable = true; // disabling button   
    //@track displayedData = []; // Data to be displayed on the current page
    //@track searchInput = '';
    //@track dataIsAvailable = true;
    @track country = '';
    @track leadandaccountoption = false;
    @track nextenable = true;
    @track showleaddata = false;
    @track showaccountdata = false;
    @track nextDisabledlead = true;


    //------------------------------

    @track selAccountList = [];
    @track selectleadList = [];

    //-----------------------------/
    // Customer screen
    @track currentPage = 1;
    @track pageSize = 7;
    @track rowsPerPage = 100;

    // Lead screen
    @track leadcurrentPage = 1;
    @track leadpageSize = 7;
    @track leadrowsPerPage = 100;

    @track filteredleadList = [];
    //-----------------------------
    //--Scheme Screen
    // Single-row data object
    @track sampleRow = {
        productName: '',
        productModel: '',
        sphericalPower: '',
        cylindricalPower: '',
        axisAngle: '',
        diaptor: '',
        commercialQuantity: 0,
        // Lists for combobox options
        sampleRequestProductList: [],
        productModellist: [],
        sphericalPowerlist: [],
        cylindricalPowerlist: [],
        axisAngleList: [],
        diaptorList: [],
        // Flags to disable dependent comboboxes
        productModelShow: true,
        sphericalPowerShow: true,
        cylindricalPowerShow: true,
        axisAngleShow: true,
        diaptorShow: true,
        commercialQuantityshow: true
    };

    //-----------------------------//////////////////////////////////////////
    connectedCallback() {
        console.log('Record ID:', this.recordId);
        loadStyle(this, modal);
    }

    get formattedPlaceholder() {
        return `${this.getsplrqstlabel.Search_By__c} ${this.getsplrqstlabel.name__c} ${this.getsplrqstlabel.Phone__c} ${this.getsplrqstlabel.sap_or_zip_code__c}`;
    }

    @wire(getsamplerequestlabel)
    getsamplerequest(result) {
        this.spinner = true;
        if (result.data) {
            this.getsplrqstlabel = result.data;
            console.log('Translation getsplrqstlabel', this.getsplrqstlabel);
            if (this.getsplrqstlabel != undefined) {
                this.spinner = false;
            }
        }
        if (result.error) {
            console.log('error', result.error);
        }
    }

    // Wire service to fetch the list of countries from Apex
    @wire(getcountrieslist)
    wiredCountries({ error, data }) {
        if (data) {
            this.countries = data;
            console.log('this.countries', this.countries);
            if (this.countries != null && this.countries != '') {
                // this.initializeRows(2);
                //this.fetchsampleproductdata();
                this.handleFetchInvoiceLineItems();
            }

        } else if (error) {
            console.log('Error fetching countries:', error);
        }
    }

    // Getter to map countries into the format required for lightning-combobox
    get countryName() {
        //this.handleFetchInvoiceLineItems();
        return this.countries;
    }




    @wire(fetchSampleRequestProduct)
    wiredData({ error, data }) {
        if (data) {
           // this.sampleRow.sampleRequestProductList = data.sampleRequestProduct;
             //===================sort assending============================
            this.sampleRow.sampleRequestProductList = data.sampleRequestProduct
                .slice() // Clone first
                .sort((a, b) => {
                    const nameA = a.label?.toUpperCase() || '';
                    const nameB = b.label?.toUpperCase() || '';
                    return nameA.localeCompare(nameB); //  Assending order
                });

            console.log('Sorted Desc sampleRequestProduct data -->', JSON.stringify(this.sampleRow.sampleRequestProductList));
            //===============================================
            console.log('this.sampleRow.sampleRequestProductList', this.sampleRow.sampleRequestProductList);
            this.selectCountry = data.country;
        } else if (error) {
            console.log('Error fetching data:', error);
        }
    }

    // Handle Remark change
    handleRemarkChange(event) {
        this.remark = event.target.value;
        this.checkFields();
        // this.saveButtonError = false;
    }

    checkFields() {
        if (this.sampleRow.commercialQuantity > 0 && this.remark) {
            this.saveButtonError = false; // Enable Save button
        } else {
            this.saveButtonError = true; // Disable Save button
        }
    }

    changeQuantity(event) {
        const action = event.currentTarget.dataset.action;
        let currentQty = parseInt(this.sampleRow.commercialQuantity, 10) || 0;

        if (action === 'decrease') {
            this.sampleRow.commercialQuantity = Math.max(currentQty - 1, 0);
        } else if (action === 'increase') {
            this.sampleRow.commercialQuantity = currentQty + 1;
        } else if (action === 'update') {
            const typedValue = parseInt(event.target.value, 10);
            this.sampleRow.commercialQuantity = isNaN(typedValue) ? 0 : typedValue;
        }

        // If quantity is 0, set commercialQuantityshow to true; otherwise, set it to false.
        //this.sampleRow.commercialQuantityshow = (this.sampleRow.commercialQuantity === 0);
        this.checkFields();

    }

    handlenextscreen() {
        this.showaccountdata = false;
        this.leadandaccountoption = true;
        this.showsamplerequesttale = false;
    }

    handlAccount() {
        console.log('countryName', this.countryName);
        console.log('paginatedaccount', this.paginatedAccounts);
        this.showaccountdata = true;
        this.leadandaccountoption = false;
        this.showsamplerequesttale = false;
    }

    handlelead() {
        this.showleaddata = true;
        this.leadandaccountoption = false;
        this.showaccountdata = false;
    }
    // Handles changes from any combobox
    async handleDataChange(event) {
        const curName = event.currentTarget.name; // e.g., 'productName'
        const newValue = event.target.value;
        console.log('curName--->', curName);
        console.log('newValue--->', newValue);

        // Update the single row directly
        this.sampleRow[curName] = newValue;

        switch (curName) {
            case 'productName': {
                let productData = await this.fetchDataFromApex(
                    this.selectCountry,
                    this.sampleRow.productName,
                    '',
                    '',
                    '',
                    '',
                    ''
                );
                console.log('productData', productData);

                if (
                    productData.dropdownOptions?.productModel.length < 1 &&
                    productData.dropdownOptions?.sphericalPower.length < 1 &&
                    productData.dropdownOptions?.cylindricalPower.length < 1 &&
                    productData.dropdownOptions?.axisAngle.length < 1 &&
                    productData.dropdownOptions?.diaptor.length < 1
                ) {
                    this.productModelTitle = 'No data Available';
                    this.axisAngleTitle = 'No data Available';
                    this.diaptorTitle = 'No data Available';
                    this.cylindricalPowerTitle = 'No data Available';
                    this.sphericalPowerTitle = 'No data Available';
                    this.sampleRow.commercialQuantityshow = false;
                }

                // Populate product model options
                this.sampleRow.productModellist = productData.dropdownOptions?.productModel || [];
                this.sampleRow.productModelShow = this.sampleRow.productModellist.length < 1;

                // Reset dependent fields if productName is cleared
                if (newValue === '') {
                    this.sampleRow.productModel = '';
                    this.sampleRow.productModellist = [];
                    this.sampleRow.productModelShow = true;
                    this.sampleRow.sphericalPowerlist = [];
                    this.sampleRow.sphericalPower = '';
                    this.sampleRow.sphericalPowerShow = true;
                    this.sampleRow.cylindricalPower = '';
                    this.sampleRow.cylindricalPowerlist = [];
                    this.sampleRow.cylindricalPowerShow = true;
                    this.sampleRow.axisAngleList = [];
                    this.sampleRow.axisAngle = '';
                    this.sampleRow.axisAngleShow = true;
                    this.sampleRow.diaptor = '';
                    this.sampleRow.diaptorList = [];
                    this.sampleRow.diaptorShow = true;
                    this.sampleRow.commercialQuantity = 0;
                    this.sampleRow.commercialQuantityshow = true;
                }
                break;
            }
            case 'productModel': {
                const modelExists = Array.isArray(this.sampleRow.productModellist) && this.sampleRow.productModellist.some(model => model.value === newValue);
                if (!modelExists && newValue != '') {
                    this.validateinputvalues(curName, newValue);

                    return; // Stop further execution
                }

                let modelData = await this.fetchDataFromApex(
                    this.selectCountry,
                    this.sampleRow.productName,
                    this.sampleRow.productModel,
                    '',
                    '',
                    '',
                    ''
                );
                console.log('modelData', modelData);
                if (
                    modelData.dropdownOptions?.sphericalPower.length < 1 &&
                    modelData.dropdownOptions?.cylindricalPower.length < 1 &&
                    modelData.dropdownOptions?.axisAngle.length < 1 &&
                    modelData.dropdownOptions?.diaptor.length < 1
                ) {
                    this.axisAngleTitle = 'No data Available';
                    this.diaptorTitle = 'No data Available';
                    this.cylindricalPowerTitle = 'No data Available';
                    this.sphericalPowerTitle = 'No data Available';
                    this.sampleRow.commercialQuantityshow = false;
                }

                this.sampleRow.sphericalPowerlist = modelData.dropdownOptions?.sphericalPower || [];
                if (this.sampleRow.sphericalPowerlist.length > 0) {
                    this.sampleRow.sphericalPowerShow = this.sampleRow.sphericalPowerlist.length < 1;
                    this.sampleRow.cylindricalPowerlist = [];
                    this.sampleRow.axisAngleList = [];
                    this.sampleRow.diaptorList = [];
                } else {
                    this.sphericalPowerTitle = 'No data available';
                    if (modelData.dropdownOptions?.cylindricalPower.length > 0) {
                        this.sampleRow.cylindricalPowerlist = modelData.dropdownOptions?.cylindricalPower;
                        this.sampleRow.cylindricalPowerShow = this.sampleRow.cylindricalPowerlist.length < 1;
                    } else {
                        this.sampleRow.cylindricalPowerShow = true;
                        this.cylindricalPowerTitle = 'No data Available';
                        if (modelData.dropdownOptions?.axisAngle.length > 0) {
                            this.sampleRow.axisAngleList = modelData.dropdownOptions?.axisAngle;
                            this.sampleRow.axisAngleShow = this.sampleRow.axisAngleList.length < 1;
                        } else {
                            this.sampleRow.axisAngleShow = true;
                            this.axisAngleTitle = 'No data Available';
                            if (modelData.dropdownOptions?.diaptor.length > 0) {
                                this.sampleRow.diaptorList = modelData.dropdownOptions?.diaptor;
                                this.sampleRow.diaptorShow = this.sampleRow.diaptorList.length < 1;
                            } else {
                                this.sampleRow.diaptorShow = true;
                                this.diaptorTitle = 'No data Available';
                            }
                        }
                    }
                }
                if (newValue === '') {
                    this.sampleRow.sphericalPowerlist = [];
                    this.sampleRow.sphericalPower = '';
                    this.sampleRow.cylindricalPower = '';
                    this.sampleRow.cylindricalPowerlist = [];
                    this.sampleRow.axisAngleList = [];
                    this.sampleRow.axisAngle = '';
                    this.sampleRow.diaptor = '';
                    this.sampleRow.diaptorList = [];
                    this.sampleRow.sphericalPowerShow = true;
                    this.sampleRow.axisAngleShow = true;
                    this.sampleRow.cylindricalPowerShow = true;
                    this.sampleRow.diaptorShow = true;
                    this.sampleRow.commercialQuantityshow = true;
                    this.sampleRow.commercialQuantity = 0;
                }
                break;
            }
            case 'sphericalPower': {
                const modelExists = Array.isArray(this.sampleRow.sphericalPowerlist) && this.sampleRow.sphericalPowerlist.some(spherical => spherical.value === newValue);
                if (!modelExists && newValue != '') {
                    this.validateinputvalues(curName, newValue);

                    return; // Stop further execution
                }

                let sphericalData = await this.fetchDataFromApex(
                    this.selectCountry,
                    this.sampleRow.productName,
                    this.sampleRow.productModel,
                    this.sampleRow.sphericalPower,
                    '',
                    '',
                    ''
                );
                console.log('sphericalData', sphericalData);
                if (
                    sphericalData.dropdownOptions?.cylindricalPower.length < 1 &&
                    sphericalData.dropdownOptions?.axisAngle.length < 1 &&
                    sphericalData.dropdownOptions?.diaptor.length < 1
                ) {
                    this.axisAngleTitle = 'No data Available';
                    this.diaptorTitle = 'No data Available';
                    this.cylindricalPowerTitle = 'No data Available';
                    this.sampleRow.commercialQuantityshow = false;
                }
                this.sampleRow.cylindricalPowerlist = sphericalData.dropdownOptions?.cylindricalPower || [];
                if (this.sampleRow.cylindricalPowerlist.length > 0) {
                    this.sampleRow.cylindricalPowerShow = this.sampleRow.cylindricalPowerlist.length < 1;
                    this.sampleRow.axisAngleList = [];
                    this.sampleRow.diaptorList = [];
                } else {
                    this.cylindricalPowerTitle = 'No data Available';
                    if (sphericalData.dropdownOptions?.axisAngle.length > 0) {
                        this.sampleRow.axisAngleList = sphericalData.dropdownOptions?.axisAngle;
                        this.sampleRow.axisAngleShow = this.sampleRow.axisAngleList.length < 1;
                    } else {
                        this.sampleRow.axisAngleShow = true;
                        this.axisAngleTitle = 'No data Available';
                        if (sphericalData.dropdownOptions?.diaptor.length > 0) {
                            this.sampleRow.diaptorList = sphericalData.dropdownOptions?.diaptor;
                            this.sampleRow.diaptorShow = this.sampleRow.diaptorList.length < 1;
                        } else {
                            this.sampleRow.diaptorShow = true;
                            this.diaptorTitle = 'No data Available';
                        }
                    }
                }
                if (newValue === '') {
                    this.sampleRow.cylindricalPower = '';
                    this.sampleRow.cylindricalPowerlist = [];
                    this.sampleRow.axisAngleList = [];
                    this.sampleRow.axisAngle = '';
                    this.sampleRow.diaptor = '';
                    this.sampleRow.diaptorList = [];
                    this.sampleRow.axisAngleShow = true;
                    this.sampleRow.cylindricalPowerShow = true;
                    this.sampleRow.diaptorShow = true;
                    this.sampleRow.commercialQuantityshow = true;
                    this.sampleRow.commercialQuantity = 0;
                }
                break;
            }
            case 'cylindricalPower': {
                const modelExists = Array.isArray(this.sampleRow.cylindricalPowerlist) && this.sampleRow.cylindricalPowerlist.some(cylin => cylin.value === newValue);
                if (!modelExists && newValue != '') {
                    this.validateinputvalues(curName, newValue);

                    return; // Stop further execution
                }
                let cylindricalData = await this.fetchDataFromApex(
                    this.selectCountry,
                    this.sampleRow.productName,
                    this.sampleRow.productModel,
                    this.sampleRow.sphericalPower,
                    this.sampleRow.cylindricalPower,
                    '',
                    ''
                );
                console.log('cylindricalData', cylindricalData);
                if (
                    cylindricalData.dropdownOptions?.axisAngle.length < 1 &&
                    cylindricalData.dropdownOptions?.diaptor.length < 1
                ) {
                    this.axisAngleTitle = 'No data Available';
                    this.diaptorTitle = 'No data Available';
                    this.sampleRow.commercialQuantityshow = false;
                }
                this.sampleRow.axisAngleList = cylindricalData.dropdownOptions?.axisAngle || [];
                if (this.sampleRow.axisAngleList.length > 0) {
                    this.sampleRow.axisAngleShow = this.sampleRow.axisAngleList.length < 1;
                    this.sampleRow.diaptorList = [];
                } else {
                    this.sampleRow.axisAngleShow = true;
                    this.axisAngleTitle = 'No data Available';
                    if (cylindricalData.dropdownOptions?.diaptor.length > 0) {
                        this.sampleRow.diaptorList = cylindricalData.dropdownOptions?.diaptor;
                        this.sampleRow.diaptorShow = this.sampleRow.diaptorList.length < 1;
                    } else {
                        this.sampleRow.diaptorShow = true;
                        this.diaptorTitle = 'No data Available';
                    }
                }
                if (newValue === '') {
                    this.sampleRow.axisAngleList = [];
                    this.sampleRow.axisAngle = '';
                    this.sampleRow.diaptor = '';
                    this.sampleRow.diaptorList = [];
                    this.sampleRow.axisAngleShow = true;
                    this.sampleRow.diaptorShow = true;
                    this.sampleRow.commercialQuantityshow = true;
                    this.sampleRow.commercialQuantity = 0;
                }
                break;
            }
            case 'axisAngle': {
                const modelExists = Array.isArray(this.sampleRow.axisAngleList) && this.sampleRow.axisAngleList.some(axis => axis.value === newValue);
                if (!modelExists && newValue != '') {
                    this.validateinputvalues(curName, newValue);

                    return; // Stop further execution
                }
                let axisData = await this.fetchDataFromApex(
                    this.selectCountry,
                    this.sampleRow.productName,
                    this.sampleRow.productModel,
                    this.sampleRow.sphericalPower,
                    this.sampleRow.cylindricalPower,
                    this.sampleRow.axisAngle,
                    ''
                );
                console.log('axisData', axisData);
                if (axisData.dropdownOptions?.diaptor.length < 1) {
                    this.diaptorTitle = 'No data Available';
                    this.sampleRow.commercialQuantityshow = false;
                }
                this.sampleRow.diaptorList = axisData.dropdownOptions?.diaptor || [];
                this.sampleRow.diaptorShow = this.sampleRow.diaptorList.length < 1;
                if (this.sampleRow.diaptorList.length === 0) {
                    this.diaptorTitle = 'No data Available';
                    this.sampleRow.diaptorShow = true;
                    this.sampleRow.commercialQuantityshow = false;
                }
                if (newValue === '') {
                    this.sampleRow.diaptor = '';
                    this.sampleRow.diaptorList = [];
                    this.sampleRow.diaptorShow = true;
                    this.sampleRow.commercialQuantityshow = true;
                    this.sampleRow.commercialQuantity = 0;
                }
                break;
            }
            case 'diaptor': {
                const modelExists = Array.isArray(this.sampleRow.diaptorList) && this.sampleRow.diaptorList.some(diaptor => diaptor.value === newValue);
                if (!modelExists && newValue != '') {
                    this.validateinputvalues(curName, newValue);

                    return; // Stop further execution
                }
                this.sampleRow.commercialQuantityshow = false;
                if (newValue === '') {
                    this.sampleRow.commercialQuantityshow = true;
                    this.sampleRow.commercialQuantity = 0;
                }
                break;
            }
            case 'commercialQuantity': {
                if (this.sampleRow.commercialQuantity != null) {
                    this.saveButtonError = false;
                } else {
                    this.saveButtonError = true;
                }
                break;
            }
        }
    }

    validateinputvalues(label, newvalue) {
        switch (label) {
            case 'productModel': {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: `${this.getsplrqstlabel.Invalid__c} ${this.getsplrqstlabel.Product_Model__c}`,
                        message: `${this.getsplrqstlabel.The_entered__c} ${this.getsplrqstlabel.Product_Model__c} '${newvalue}' ${this.getsplrqstlabel.is_not_valid__c}`,
                        variant: 'warning',
                    })
                );
                break;

            }
            case 'sphericalPower': {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: `${this.getsplrqstlabel.Invalid__c} ${this.getsplrqstlabel.Spherical_Power__c}`,
                        message: `${this.getsplrqstlabel.The_entered__c} ${this.getsplrqstlabel.Spherical_Power__c} '${newvalue}' ${this.getsplrqstlabel.is_not_valid__c}`,
                        variant: 'warning',
                    })
                );
                break;

            }
            case 'cylindricalPower': {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: `${this.getsplrqstlabel.Invalid__c} ${this.getsplrqstlabel.Cylindrical_Power__c}`,
                        message: `${this.getsplrqstlabel.The_entered__c} ${this.getsplrqstlabel.Cylindrical_Power__c} '${newvalue}' ${this.getsplrqstlabel.is_not_valid__c}`,
                        variant: 'warning',
                    })
                );
                break;

            }
            case 'axisAngle': {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: `${this.getsplrqstlabel.Invalid__c} ${this.getsplrqstlabel.Axis_Angle__c}`,
                        message: `${this.getsplrqstlabel.The_entered__c} ${this.getsplrqstlabel.Axis_Angle__c} '${newvalue}' ${this.getsplrqstlabel.is_not_valid__c}`,
                        variant: 'warning',
                    })
                );
                break;
            }
            case 'diaptor': {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: `${this.getsplrqstlabel.Invalid__c} ${this.getsplrqstlabel.Diaptor__c}`,
                        message: `${this.getsplrqstlabel.The_entered__c} ${this.getsplrqstlabel.Diaptor__c} '${newvalue}' ${this.getsplrqstlabel.is_not_valid__c}`,
                        variant: 'warning',
                    })
                );
                break;
            }
        }

        return;
    }


    async fetchDataFromApex(countryValue, productName, productModel, sphericalPower, cylindricalPower, axisAngle, diaptor) {
        try {
            let result = await fetchDropdownOptions({
                countryValue,
                productName,
                productModel,
                sphericalPower,
                cylindricalPower,
                axisAngle,
                diaptor
            });
            console.log('result--->', result);
            return result;
        } catch (error) {
            console.error('Error fetching dropdown options:', error);
            return {};
        }
    }


    handlesave() {
        this.nextDisabled = true;
        this.nextDisabledlead = true;
        // Prepare the final data as per your requirements
        const finalData = [
            {
                productName: this.sampleRow.productName,
                productModel: this.sampleRow.productModel,
                sphericalPower: this.sampleRow.sphericalPower,
                cylindricalPower: this.sampleRow.cylindricalPower,
                axisAngle: this.sampleRow.axisAngle,
                diaptor: this.sampleRow.diaptor,
                commercialQuantity: this.sampleRow.commercialQuantity.toString(),// Ensure quantity is converted to string
                remark: this.remark
            }
        ];
        console.log('finalData', finalData);
        // Call Apex method
        saveSampleRequestData({ finalData: finalData, accIds: this.selAccountList, leadIds: this.selectleadList })
            .then(result => { // Capture the result from Apex
                console.log('Apex method result:', result); // Debugging

                if (result === 'success') { // Use result properly
                    this.saveButtonError = true;
                    setTimeout(() => {
                        this.showToast('Success', 'Sample Request Submitted successfully!', 'success');
                        window.location.reload();
                    }, 1000); // 1000ms = 1 second


                }
            })
            .catch(error => {
                console.error('Error:', error);
                this.showToast('Error', 'Failed to save data.', 'error');
            });
    }



    // Toast message function
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }


    //--------------------------------------------------
    get paginatedAccounts() {
        if (!this.filteredAccountList || this.filteredAccountList.length === 0) {
            return [];
        }

        let start = (this.currentPage - 1) * this.pageSize;
        let end = start + this.pageSize;
        //console.log('Paginated Start:', start, 'End:', end);  // Debugging

        // Return the sliced array based on the page
        return this.filteredAccountList.slice(start, end);
    }

    //--------------------------------------------------
    get paginatedleads() {
        if (!this.filteredleadList || this.filteredleadList.length === 0) {
            return [];
        }

        let start = (this.leadcurrentPage - 1) * this.leadpageSize;
        let end = start + this.leadpageSize;
        //console.log('Paginated Start:', start, 'End:', end);  // Debugging

        // Return the sliced array based on the page
        return this.filteredleadList.slice(start, end);
    }

    handlePreviousPage() {

        if (this.currentPage > 1) {
            this.currentPage--;
            //console.log('Current Page after Previous:', this.currentPage);  // Debugging
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            // console.log('Current Page after Next:', this.currentPage);  // Debugging
        }
    }


    handlePreviousPagelead() {

        if (this.leadcurrentPage > 1) {
            this.leadcurrentPage--;
            //console.log('Current Page after Previous:', this.leadcurrentPage);  // Debugging
        }
    }

    handleNextPagelead() {
        if (this.leadcurrentPage < this.leadtotalPages) {
            this.leadcurrentPage++;
            //console.log('Current Page after Next:', this.leadcurrentPage);  // Debugging
        }
    }


    get leadisFirstPage() {
        return this.leadcurrentPage === 1;
    }

    get leadisLastPage() {
        return this.leadcurrentPage === this.leadtotalPages;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get totalPages() {
        return this.filteredAccountList.length > 0
            ? Math.ceil(this.filteredAccountList.length / this.pageSize)
            : 1; // Total pages should be calculated correctly based on filtered records
    }
    get leadtotalPages() {
        return this.filteredleadList.length > 0
            ? Math.ceil(this.filteredleadList.length / this.leadpageSize)
            : 1; // Total pages should be calculated correctly based on filtered records
    }

    handlePreviousButton() {
        this.leadandaccountoption = true;
        this.showsamplerequesttale = false;
        this.showleaddata = false;
        this.showaccountdata = false;

    }



    handlepreviousfirstscreen() {
        this.leadandaccountoption = false;
        this.showsamplerequesttale = true;
        this.showaccountdata = false;
    }



    showSuccessMessage(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success',
            mode: 'dismissable'
        }));
    }

    showErrorMessage(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error',
            mode: 'dismissable'
        }));
    }




    handleFetchInvoiceLineItems() {
        getAccountdata({ country: this.countryName })
            .then(result => {
                if (result) {
                    // Mapping the account list and adding rowIndex and selection state
                    console.log('Received data', result);
                    this.accountList = result.account.map((record, index) => {
                        return {
                            ...record,
                            rowIndex: index + 1,
                            isSelected: this.selectedRecordIds.has(record.Id)
                        };
                    });
                    this.leadlistdata = result.leadlist.map((record, index) => {
                        return {
                            ...record,
                            rowIndex: index + 1,
                            isSelectedlead: this.selectedleadRecordIds.has(record.Id)
                        };
                    });




                    //this.fetchDataFromApex();
                    console.log('this.accountList', this.accountList);

                    // Setting filtered account list and total data count
                    this.filteredAccountList = this.accountList;
                    this.filteredleadList = this.leadlistdata;
                    this.leattotalData = this.filteredleadList.length;
                    this.totalData = this.filteredAccountList.length;
                }
            })
            .catch(error => {
                // Handling errors
                this.showErrorMessage('Error fetching data');
                console.log(error);
            });
    }


    handleSelectAll(event) {
        const isSelected = event.target.checked;

        // Reset selectedRecordIds when toggling select all
        this.selectedRecordIds = new Set();

        // Get the accounts on the current page (paginated accounts)
        const currentPageAccounts = this.paginatedAccounts;

        // Update the selected state for accounts only on the current page
        currentPageAccounts.forEach(account => {
            account.isSelected = isSelected;

            if (isSelected) {
                this.selectedRecordIds.add(account.Id); // Add selected account to Set
            } else {
                this.selectedRecordIds.delete(account.Id); // Remove from selected set if unselected
                const indexs = this.selAccountList.indexOf(account.Id);

                // Remove the recordId from the list if it's found
                if (indexs > -1) {
                    this.selAccountList.splice(indexs, 1);  // Removes one item at the found index
                }
            }
        });

        // Convert Set to Array and update the count
        this.selAccountList = Array.from(this.selectedRecordIds);
        this.selectedAccountCount = this.selAccountList.length; // Update selected count

        // Disable next button if no accounts are selected
        this.nextDisabled = this.selectedRecordIds.size === 0;

        console.log('Selected acc List', this.selAccountList);
        console.log('this.selectedRecordIds---HandleSelectAll', this.selectedRecordIds);
    }

    handleSelectAlllead(event) {
        const isSelectedlead = event.target.checked;

        // Reset selectedRecordIds when toggling select all
        this.selectedleadRecordIds = new Set();

        // Get the accounts on the current page (paginated accounts)
        const currentPagelead = this.paginatedleads;

        // Update the selected state for accounts only on the current page
        currentPagelead.forEach(leadlist => {
            leadlist.isSelectedlead = isSelectedlead;

            if (isSelectedlead) {
                this.selectedleadRecordIds.add(leadlist.Id); // Add selected account to Set
            } else {
                this.selectedleadRecordIds.delete(leadlist.Id); // Remove from selected set if unselected
                const indexs = this.selectleadList.indexOf(leadlist.Id);

                // Remove the recordId from the list if it's found
                if (indexs > -1) {
                    this.selectleadList.splice(indexs, 1);  // Removes one item at the found index
                }
            }
        });

        // Convert Set to Array and update the count
        this.selectleadList = Array.from(this.selectedleadRecordIds);
        this.selectedleadCount = this.selectleadList.length; // Update selected count

        // Disable next button if no accounts are selected
        this.nextDisabledlead = this.selectedleadRecordIds.size === 0;

        console.log('Selected acc List', this.selectleadList);
        console.log('this.selectedleadRecordIds---HandleSelectAll', this.selectedleadRecordIds);
    }


    handleSearch(event) {

        const fieldName = event.target.name; // Identify which field triggered the event
        const fieldValue = event.target.value.toLowerCase().trim();

        if (fieldName === "searchAccount") {
            this.searchTerm = fieldValue;
        }

        this.filterAccounts(); // Apply filters
    }



    filterAccounts() {
        let filteredList = [...this.accountList]; // Start with the full account list

        // Check if Name, Email, or Phone filter is applied
        const isSearchTermApplied = this.searchTerm && this.searchTerm.length > 0;
        const isCountryFilterApplied = this.countryName && this.countryName.length > 0;

        if (isSearchTermApplied) {
            filteredList = filteredList.filter(account =>
                account.Name.toLowerCase().includes(this.searchTerm) ||
                (account.E_Mail__c && account.E_Mail__c.toLowerCase().includes(this.searchTerm)) ||
                (account.Phone && account.Phone.toLowerCase().includes(this.searchTerm)) ||
                (account.BillingPostalCode && account.BillingPostalCode.toLowerCase().includes(this.searchTerm)) ||
                (account.SAP_Code__c && account.SAP_Code__c.toLowerCase().includes(this.searchTerm))
            );
        }

        if (isCountryFilterApplied) {
            filteredList = filteredList.filter(account =>
                account.BillingCountry && account.BillingCountry.toUpperCase().includes(this.countryName)
            );
        }

        // Assign the final filtered list
        this.filteredAccountList = filteredList;
    }


    handleSearchlead(event) {

        const fieldName = event.target.name; // Identify which field triggered the event
        const fieldValue = event.target.value.toLowerCase().trim();

        if (fieldName === "searchlead") {
            this.searchTermlead = fieldValue;
            console.log('searchlead');
        }

        this.filterleads(); // Apply filters
    }

    filterleads() {
        let filteredleadLists = [...this.leadlistdata]; // Start with the full lead list
        console.log('input value', this.searchTermlead);


        // Check if Name, Email, or Phone filter is applied
        const isSearchTermApplieds = this.searchTermlead && this.searchTermlead.length > 0;
        const isCountryFilterApplieds = this.countryName && this.countryName.length > 0;

        if (isSearchTermApplieds) {
            filteredleadLists = filteredleadLists.filter(leadlist =>
                (leadlist.Name && leadlist.Name.toLowerCase().includes(this.searchTermlead)) ||
                (leadlist.Email__c && leadlist.Email__c.toLowerCase().includes(this.searchTermlead)) ||
                (leadlist.Mobile__c && leadlist.Mobile__c.toLowerCase().includes(this.searchTermlead)) ||
                (leadlist.Billing_code__c && leadlist.Billing_code__c.toLowerCase().includes(this.searchTermlead)) ||
                (leadlist.SAP_Code__c && leadlist.SAP_Code__c.toLowerCase().includes(this.searchTermlead))
            );
        }

        if (isCountryFilterApplieds) {
            filteredleadLists = filteredleadLists.filter(leadlist =>
                leadlist.Country__c && leadlist.Country__c.toUpperCase().includes(this.countryName)
            );
        }


        console.log('filteredleadList:', JSON.stringify(this.filteredleadLists));
        // Assign the final filtered list
        this.filteredleadList = filteredleadLists;

        // Log the correct variable
        console.log('filteredleadList:', JSON.stringify(this.filteredleadList));
    }






    handleClick(event) {
        const checkBox = event.target.checked;
        const recordId = event.target.dataset.id;

        if (checkBox) {
            if (!this.selAccountList.includes(recordId)) {
                this.selAccountList = [...this.selAccountList, recordId];
            }
            this.selectedRecordIds.add(recordId);
        } else {
            this.selAccountList = this.selAccountList.filter(id => id !== recordId);
            this.selectedRecordIds.delete(recordId);
        }

        // Update count
        this.selectedAccountCount = this.selAccountList.length;

        // Update account list to reflect selection state
        this.accountList = this.accountList.map(record => ({
            ...record,
            isSelected: record.Id === recordId ? checkBox : record.isSelected
        }));

        this.filterAccounts();
        this.nextDisabled = this.selectedRecordIds.size === 0;

        console.log('Selected Account List:', this.selAccountList);
        console.log('this.selectedRecordIds---Handleclick:', this.selectedRecordIds);
    }

    handleClicklead(event) {
        const checkBox = event.target.checked;
        const leadId = event.target.dataset.id;

        if (checkBox) {
            if (!this.selectleadList.includes(leadId)) {
                this.selectleadList = [...this.selectleadList, leadId];
            }
            this.selectedleadRecordIds.add(leadId);
        } else {
            this.selectleadList = this.selectleadList.filter(id => id !== leadId);
            this.selectedleadRecordIds.delete(leadId);
        }

        // Update count
        this.selectedleadCount = this.selectleadList.length;

        // Update lead list to reflect selection state
        this.leadlistdata = this.leadlistdata.map(record => ({
            ...record,
            isSelectedlead: record.Id === leadId ? checkBox : record.isSelectedlead
        }));

        this.filterleads();
        this.nextDisabledlead = this.selectedleadRecordIds.size === 0;

        console.log('Selected Lead List:', this.selectleadList);
        console.log('this.selectedleadRecordIds---', this.selectedleadRecordIds);
    }


    handleNext() {
        //this.fetchsampleproductdata();
        this.selectedAccId = Array.from(this.selectedRecordIds);
        this.selectedAccountNames = this.accountList.filter(account => this.selectedRecordIds.has(account.Id));

        if (this.selAccountList.length > 0) {

            this.showsamplerequesttale = true;
        }

        this.showaccountdata = false;
        // Call Apex Method


    }

}