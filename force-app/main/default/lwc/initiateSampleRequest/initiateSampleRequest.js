import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getsamplerequestlabel from '@salesforce/apex/SampleRequestLWCcontroller.getCustomLabels';

import fetchSampleRequestProduct from '@salesforce/apex/SampleRequestLWCcontroller.fetchSampleRequestProduct';
import fetchDropdownOptions from '@salesforce/apex/SampleRequestLWCcontroller.fetchDropdownOptions';
import saveSampleRequestData from '@salesforce/apex/SampleRequestLWCcontroller.saveSampleRequestDataforsinglecustomer';

export default class InitiateSampleRequest extends LightningElement {
    @track showSampleList = [];
    @api recordId;
    @track saveButtonError = true;
    @track rsmzsmnotavailable = false;
    @track sampleRequestProduct = [];
    @track productModelTitle = '';
    @track sphericalPowerTitle = '';
    @track cylindricalPowerTitle = '';

    @track axisAngleTitle = '';
    @track diaptorTitle = '';
    @track selectedData = [];
    @track showsapcoderemark = false;
    @track showdefaultrow = true;
    @track sapCodeOptions = [];
    @track selectedSAPCode = '';
    @track remark = '';
    @track enablesave = true;
    errorMessage = '';
    @track finalDataListToSave = [];
    @track sapcodenotfound = '';
    @track showwarningmessage = false;
    @track handlenextenable = true;
    @track getsplrqstlabel = {};

    connectedCallback() {
        console.log('Record ID:', this.recordId);
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

    @wire(fetchSampleRequestProduct, { recordId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {

            this.sapcodenotfound = data.recordsapcode;
            console.log('rsmavailable-->', data.rsmavailable);
            console.log('zsmavailable-->', data.zsmavailable);
            console.log('this.sapcodenotfound', this.sapcodenotfound);
             if (this.sapcodenotfound == undefined) {
                this.showdefaultrow = false;
                this.showwarningmessage = true;
                setTimeout(() => {
                    this.handleClose();
                }, 5000);
                return;
            }
            if (data.rsmavailable == undefined && data.zsmavailable == undefined) {
                this.showwarningmessage = false;
                this.showdefaultrow = false;
                this.rsmzsmnotavailable = true;
                
                setTimeout(() => {
                    this.handleClose();
                }, 5000);
                return;
            }

             //===================sort assending============================
            this.sampleRequestProduct = data.SampleRequestProduct
                .slice() // Clone first
                .sort((a, b) => {
                    const nameA = a.label?.toUpperCase() || '';
                    const nameB = b.label?.toUpperCase() || '';
                    return nameA.localeCompare(nameB); //  Assending order
                });

            console.log('Sorted Desc sampleRequestProduct data -->', JSON.stringify(this.sampleRequestProduct));
            //===============================================

           // this.sampleRequestProduct = data.SampleRequestProduct;
            console.log('data-->', data);
            if (data.sapCodeList && data.sapCodeList.length > 0) {
                this.sapCodeOptions = data.sapCodeList.map(item => ({
                    label: item.label,
                    value: item.value
                }));
                // If only one option exists, set it as the default selected SAP code
                if (this.sapCodeOptions.length === 1) {
                    this.selectedSAPCode = this.sapCodeOptions[0].value;
                }
            }
            //console.log('data------>',data);
            this.initializeRows(1);
        } else if (error) {
            this.errorMessage = 'Error fetching SAP codes: ' + error.body.message;
            console.error('Error fetching data:', error);
        }
    }

    initializeRows(count) {
        for (let i = 0; i < count; i++) {
            this.showSampleList.push(this.getEmptyRow(i));
        }
    }

    getEmptyRow(index) {
        return {
            key: Date.now() + index,
            productName: '',
            productModel: '',
            sphericalPower: '',
            cylindricalPower: '',
            axisAngle: '',
            diaptor: '',
            productModellist: [],
            sphericalPowerlist: [],
            cylindricalPowerlist: [],
            axisAngleList: [],
            diaptorList: [],
            sampleRequestProductList: this.sampleRequestProduct,
            commercialQuantity: 0,
            productModelShow: true,
            sphericalPowerShow: true,
            cylindricalPowerShow: true,
            axisAngleShow: true,
            diaptorShow: true,
            commercialQuantityshow: true
        };
    }

    handleAddRow() {
        this.showSampleList.push(this.getEmptyRow(this.showSampleList.length));
        console.log('Sample List', JSON.stringify(this.showSampleList));
    }

    handleDeleteRow(event) {
        const curId = event.currentTarget.dataset.id;
        this.showSampleList = this.showSampleList.filter(row => row.key != curId);
        console.log('showSampleList', this.showSampleList.length);

        if (!this.showSampleList || this.showSampleList.length === 0) {
            this.handlenextenable = true;
        }
    }


    handleSAPCodeChange(event) {
        
        this.selectedSAPCode = event.target.value;
        console.log('this.selectedSAPCode',this.selectedSAPCode);
        this.checkFields(); // Check fields on SAP code change
    }

    // Handle Remark change
    handleRemarkChange(event) {
        this.remark = event.target.value;
        this.checkFields(); // Check fields on Remark change
    }

    // Check if both SAP code and Remark are filled to enable/disable Save button
    checkFields() {
        if (this.selectedSAPCode && this.remark) {
            this.enablesave = false; // Enable Save button
        } else {
            this.enablesave = true; // Disable Save button
        }
    }

    handleprevious() {
        this.showdefaultrow = true;
        this.showsapcoderemark = false;

    }



    changeQuantity(event) {
        const curId = event.currentTarget.dataset.id; // Get row key
        const action = event.currentTarget.dataset.action;
        var dataList = JSON.parse(JSON.stringify(this.showSampleList)); // Clone the list to prevent mutation of the original

        dataList.forEach(Element => {
            if (Element.key == curId) {
                // If action is 'decrease'
                if (action === 'decrease') {
                    Element.commercialQuantity = Math.max((parseInt(Element.commercialQuantity, 10) || 0) - 1, 0); // Decrease by 1, not less than 0
                }
                // If action is 'increase'
                else if (action === 'increase') {
                    Element.commercialQuantity = (parseInt(Element.commercialQuantity, 10) || 0) + 1; // Increase by 1
                }
                // If action is 'update'
                else if (action === 'update') {
                    const typedValue = parseInt(event.target.value, 10);
                    Element.commercialQuantity = isNaN(typedValue) ? 0 : typedValue; // Update to the typed value or 0 if invalid
                }
            }
        });
        this.handlenextenable = dataList.every(row => row.commercialQuantity === 0);

        this.showSampleList = dataList; // Update the list to trigger UI reactivity

        console.log('Final sample list:', JSON.stringify(this.showSampleList)); // Log the final state of the list


        /* // Clone array to trigger reactivity
         let updatedList = [...this.showSampleList];
     
         let rowIndex = updatedList.findIndex(row => row.key == curId);
     
         if (rowIndex !== -1) {
             let currentQty = parseInt(updatedList[rowIndex].commercialQuantity, 10) || 0;
     
             // Log current quantity for debugging
             console.log('Current Qty:', currentQty);
     
             if (action === 'decrease') {
                 updatedList[rowIndex].commercialQuantity = Math.max(currentQty - 1, 0);
             } else if (action === 'increase') {
                 updatedList[rowIndex].commercialQuantity = currentQty + 1;
             } else if (action === 'update') {
                 const typedValue = parseInt(event.target.value, 10);
                 updatedList[rowIndex].commercialQuantity = isNaN(typedValue) ? 0 : typedValue;
                 console.log('Updated Qty:', updatedList[rowIndex].commercialQuantity); // Debugging line
             }
     
             // Disable save button dynamically
             updatedList[rowIndex].commercialQuantityshow = updatedList[rowIndex].commercialQuantity === 0;
             this.handlenextenable = updatedList.every(row => row.commercialQuantity === 0);
         }
     
         // Update the list to trigger UI reactivity
         this.showSampleList = [...updatedList]; // Trigger reactivity*/
    }





    // Handles changes from any combobox
    async handleDataChange(event) {
        const curId = event.currentTarget.dataset.id;
        const curName = event.currentTarget.name;
        const newValue = event.target.value;

        console.log('curId--->', curId);
        console.log('curName--->', curName);
        console.log('newValue--->', newValue);
        let row = this.showSampleList.find(row => row.key == curId);
        // Check if the record already exists in selectedData


        if (row) {
            row[curName] = newValue;

            switch (curName) {

                case 'productName': {
                    let productData = await this.fetchDataFromApex(this.recordId, row.productName, '', '', '', '', '');
                    console.log('productData', productData);
                    console.log('check', productData.dropdownOptions?.productModel.length < 1);
                    if (productData.dropdownOptions?.productModel.length < 1 &&
                        productData.dropdownOptions?.sphericalPower.length < 1 &&
                        productData.dropdownOptions?.cylindricalPower.length < 1 &&
                        productData.dropdownOptions?.axisAngle.length < 1 &&
                        productData.dropdownOptions?.diaptor.length < 1) {
                        this.productModelTitle = 'No data Available';
                        this.axisAngleTitle = 'No data Available';
                        this.diaptorTitlen = 'No data Available';
                        this.cylindricalPowerTitle = 'No data Available';
                        this.sphericalPowerTitle = 'No data Available';
                        //row.commercialQuantityshow = false;
                    }


                    // Product Model Enable Only if Data Exists
                    row.productModellist = productData.dropdownOptions?.productModel || [];
                    //row.productNames = newValue;
                    row.productModelShow = row.productModellist.length < 1;
                    // Reset All Other Dropdowns
                    if (row.productModellist.length > 0) {
                        row.sphericalPowerlist = [];
                        row.cylindricalPowerlist = [];
                        row.axisAngleList = [];
                        row.diaptorList = [];

                    } else if (row.productModellist.length < 1) {
                        if (productData.dropdownOptions?.sphericalPower.length > 0) {
                            row.sphericalPowerlist = productData.dropdownOptions?.sphericalPower;
                            row.sphericalPowerShow = row.sphericalPowerlist.length < 1;
                        } else {
                            row.sphericalPowerShow = true;
                            this.sphericalPowerTitle = 'No data Available';
                            if (productData.dropdownOptions?.cylindricalPower.length > 0) {
                                row.cylindricalPowerlist = productData.dropdownOptions?.cylindricalPower;
                                row.cylindricalPowerShow = row.cylindricalPowerlist.length < 1;
                            } else {
                                row.cylindricalPowerShow = true;
                                this.cylindricalPowerTitle = 'No data Available';
                                if (productData.dropdownOptions?.axisAngle.length > 0) {
                                    row.axisAngleList = productData.dropdownOptions?.axisAngle;
                                    row.axisAngleShow = row.axisAngleList.length < 1;

                                } else {
                                    row.axisAngleShow = true;
                                    this.axisAngleTitle = 'No data Available';
                                    if (productData.dropdownOptions?.diaptor.length > 0) {
                                        row.diaptorList = productData.dropdownOptions?.diaptor;
                                        row.diaptorShow = row.diaptorList.length < 1;
                                    } else {
                                        row.diaptorShow = true;
                                        this.diaptorTitle = 'No data Available';


                                    }
                                }

                            }

                        }

                    }

                    if (newValue == '') {
                        row.productModel = '';
                        row.productModellist = [];
                        row.productModelShow = true;
                        row.sphericalPowerlist = [];
                        row.sphericalPower = '';
                        row.sphericalPowerShow = true;
                        row.cylindricalPower = '';
                        row.cylindricalPowerlist = [];
                        row.cylindricalPowerShow = true;
                        row.axisAngleList = [];
                        row.axisAngle = '';
                        row.axisAngleShow = true;
                        row.diaptor = '';
                        row.diaptorList = [];
                        row.diaptorShow = true;
                        row.commercialQuantity = 0;
                        row.commercialQuantityshow = true;
                    }

                    break;
                }

                case 'productModel': {
                    console.log('newValue', newValue);
                    console.log('productModel-->', row.productModellist);
                    const modelExists = Array.isArray(row.productModellist) && row.productModellist.some(model => model.value === newValue);
                    if (!modelExists && newValue != '') {
                        this.validateinputvalues(curName, newValue);

                        return; // Stop further execution
                    }


                    let modelData = await this.fetchDataFromApex(this.recordId, row.productName, row.productModel, '', '', '', '');
                    console.log('modelData', modelData);
                    if (modelData.dropdownOptions?.sphericalPower.length < 1 &&
                        modelData.dropdownOptions?.cylindricalPower.length < 1 &&
                        modelData.dropdownOptions?.axisAngle.length < 1 &&
                        modelData.dropdownOptions?.diaptor.length < 1) {
                        this.axisAngleTitle = 'No data Available';
                        this.diaptorTitlen = 'No data Available';
                        this.cylindricalPowerTitle = 'No data Available';
                        this.sphericalPowerTitle = 'No data Available';
                        row.commercialQuantityshow = false;
                    }

                    // Enable only if Spherical Power data exists
                    row.sphericalPowerlist = modelData.dropdownOptions?.sphericalPower || [];
                    //row.productModels = newValue;
                    //row.axisAngleList = modelData.dropdownOptions?.axisAngle || [];
                    //row.sphericalPowerShow = row.sphericalPowerlist.length < 1;



                    if (row.sphericalPowerlist.length > 0) {
                        row.sphericalPowerShow = row.sphericalPowerlist.length < 1;
                        row.cylindricalPowerlist = [];
                        row.axisAngleList = [];
                        row.diaptorList = [];

                    } else {
                        this.sphericalPowerTitle = 'No data available';
                        if (modelData.dropdownOptions?.cylindricalPower.length > 0) {
                            row.cylindricalPowerlist = modelData.dropdownOptions?.cylindricalPower;
                            row.cylindricalPowerShow = row.cylindricalPowerlist.length < 1;
                        } else {
                            row.cylindricalPowerShow = true;
                            this.cylindricalPowerTitle = 'No data Available';
                            if (modelData.dropdownOptions?.axisAngle.length > 0) {
                                row.axisAngleList = modelData.dropdownOptions?.axisAngle;
                                row.axisAngleShow = row.axisAngleList.length < 1;

                            } else {
                                row.axisAngleShow = true;
                                this.axisAngleTitle = 'No data Available';
                                if (modelData.dropdownOptions?.diaptor.length > 0) {
                                    row.diaptorList = modelData.dropdownOptions?.diaptor;
                                    row.diaptorShow = row.diaptorList.length < 1;
                                } else {
                                    row.diaptorShow = true;
                                    this.diaptorTitle = 'No data Available';

                                }
                            }
                        }
                    }

                    if (newValue == '') {
                        row.sphericalPowerlist = [];
                        row.sphericalPower = '';
                        row.cylindricalPower = '';
                        row.cylindricalPowerlist = [];
                        row.axisAngleList = [];
                        row.axisAngle = '';
                        row.diaptor = '';
                        row.diaptorList = [];
                        row.sphericalPowerShow = true;
                        row.axisAngleShow = true;
                        row.cylindricalPowerShow = true;
                        row.diaptorShow = true;
                        row.commercialQuantityshow = true;
                        row.commercialQuantity = 0;
                    }

                    break;
                }


                case 'sphericalPower': {
                    const modelExists = Array.isArray(row.sphericalPowerlist) && row.sphericalPowerlist.some(sperical => sperical.value === newValue);
                    if (!modelExists && newValue != '') {
                        // Show toast if the model is not found in the dropdown
                        this.validateinputvalues(curName, newValue);

                        return; // Stop further execution
                    }
                    let sphericalData = await this.fetchDataFromApex(this.recordId, row.productName, row.productModel, row.sphericalPower, '', '', '');
                    console.log('sphericalData', sphericalData);
                    if (sphericalData.dropdownOptions?.cylindricalPower.length < 1 &&
                        sphericalData.dropdownOptions?.axisAngle.length < 1 &&
                        sphericalData.dropdownOptions?.diaptor.length < 1) {
                        this.axisAngleTitle = 'No data Available';
                        this.diaptorTitlen = 'No data Available';
                        this.cylindricalPowerTitle = 'No data Available';
                        row.commercialQuantityshow = false;
                    }

                    // Enable only if Cylindrical Power data exists
                    row.cylindricalPowerlist = sphericalData.dropdownOptions?.cylindricalPower || [];
                    //row.sphericalPowers = newValue;
                    //row.cylindricalPowerShow = row.cylindricalPowerlist.length < 1;


                    if (row.cylindricalPowerlist.length > 0) {
                        row.cylindricalPowerShow = row.cylindricalPowerlist.length < 1;
                        row.axisAngleList = [];
                        row.diaptorList = [];

                    } else {
                        this.cylindricalPowerTitle = 'No data Available';
                        if (sphericalData.dropdownOptions?.axisAngle.length > 0) {
                            row.axisAngleList = sphericalData.dropdownOptions?.axisAngle;
                            row.axisAngleShow = row.axisAngleList.length < 1;

                        } else {
                            row.axisAngleShow = true;
                            this.axisAngleTitle = 'No data Available';
                            if (sphericalData.dropdownOptions?.diaptor.length > 0) {
                                row.diaptorList = sphericalData.dropdownOptions?.diaptor;
                                row.diaptorShow = row.diaptorList.length < 1;
                            } else {
                                row.diaptorShow = true;
                                this.diaptorTitle = 'No data Available';

                            }
                        }
                    }

                    if (newValue == '') {
                        row.cylindricalPower = '';
                        row.cylindricalPowerlist = [];
                        row.axisAngleList = [];
                        row.axisAngle = '';
                        row.diaptor = '';
                        row.diaptorList = [];
                        row.axisAngleShow = true;
                        row.cylindricalPowerShow = true;
                        row.diaptorShow = true;
                        row.commercialQuantityshow = true;
                        row.commercialQuantity = 0;
                    }

                    break;
                }

                case 'cylindricalPower': {
                    const modelExists = Array.isArray(row.cylindricalPowerlist) && row.cylindricalPowerlist.some(cylindrical => cylindrical.value === newValue);
                    if (!modelExists && newValue != '') {
                        this.validateinputvalues(curName, newValue);
                        return; // Stop further execution
                    }
                    let cylindricalData = await this.fetchDataFromApex(this.recordId, row.productName, row.productModel, row.sphericalPower, row.cylindricalPower, '', '');
                    console.log('cylindricalData', cylindricalData);
                    if (cylindricalData.dropdownOptions?.axisAngle.length < 1 &&
                        cylindricalData.dropdownOptions?.diaptor.length < 1) {
                        this.axisAngleTitle = 'No data Available';
                        this.diaptorTitlen = 'No data Available';
                        row.commercialQuantityshow = false;
                    }

                    // Enable only if Axis Angle data exists
                    row.axisAngleList = cylindricalData.dropdownOptions?.axisAngle || [];
                    //row.cylindricalPower = newValue;
                    //row.axisAngleShow = row.axisAngleList.length < 1;




                    if (row.axisAngleList.length > 0) {
                        row.axisAngleShow = row.axisAngleList.length < 1;
                        row.diaptorList = [];

                    } else {
                        this.axisAngleTitle = 'No data Available';
                        if (cylindricalData.dropdownOptions?.diaptor.length > 0) {
                            row.diaptorList = cylindricalData.dropdownOptions?.diaptor;
                            row.diaptorShow = row.diaptorList.length < 1;
                        } else {
                            row.diaptorShow = true;
                            this.diaptorTitle = 'No data Available';


                        }
                    }
                    if (newValue == '') {
                        row.axisAngleList = [];
                        row.axisAngle = '';
                        row.diaptor = '';
                        row.diaptorList = [];
                        row.axisAngleShow = true;
                        row.diaptorShow = true;
                        row.commercialQuantityshow = true;
                        row.commercialQuantity = 0;
                    }
                    break;
                }

                case 'axisAngle': {
                    const modelExists = Array.isArray(row.axisAngleList) && row.axisAngleList.some(axis => axis.value === newValue);
                    if (!modelExists && newValue != '') {
                        this.validateinputvalues(curName, newValue);
                        return; // Stop further execution
                    }

                    let axisData = await this.fetchDataFromApex(this.recordId, row.productName, row.productModel, row.sphericalPower, row.cylindricalPower, row.axisAngle, '');
                    console.log('axisData', axisData);
                    if (axisData.dropdownOptions?.diaptor.length < 1) {
                        this.diaptorTitlen = 'No data Available';
                        row.commercialQuantityshow = false;
                    }

                    // Enable only if Diaptor data exists
                    console.log('OUTPUT --diaptor-->:',axisData.dropdownOptions.diaptor);
                    row.diaptorList = axisData.dropdownOptions?.diaptor || [];
                    //row.axisAngle = newValue;
                    row.diaptorShow = row.diaptorList.length < 1;
                    //row.diaptorShow = row.diaptorList.length < 1;   

                    if (row.diaptorList.length > 0) {
                        if (row.diaptorList.length > 0 && row.diaptors != '') {
                            //row.commercialQuantityshow = false;
                        }


                    } else {
                        this.diaptorTitle = 'No data Available';
                        row.diaptorShow = true;
                        row.commercialQuantityshow = false;




                    }

                    if (newValue == '') {
                        row.diaptor = '';
                        row.diaptorList = [];
                        row.diaptorShow = true;
                        row.commercialQuantityshow = true;
                        row.commercialQuantity = 0;
                    }
                    break;

                }
                case 'diaptor': {

                    const modelExists = Array.isArray(row.diaptorList) && row.diaptorList.some(diaptor => diaptor.value === newValue);
                    if (!modelExists && newValue != '') {
                        this.validateinputvalues(curName, newValue);
                        return; // Stop further execution
                    }

                    row.commercialQuantityshow = false;
                    if (newValue == '') {
                        row.commercialQuantityshow = true;
                        row.commercialQuantity = 0;
                    }

                    break;


                }
                // case 'commercialQuantity': {
                //     if (row.commercialQuantity != null) {
                //         this.saveButtonError = false;
                //     } else {
                //         this.saveButtonError = true;
                //     }
                //     break;

                // }
            }

        }
    }


    async fetchDataFromApex(recordId, productName, productModel, sphericalPower, cylindricalPower, axisangles, diaptor) {
        try {
            let result = await fetchDropdownOptions({
                recordId,
                productName,
                productModel,
                sphericalPower,
                cylindricalPower,
                axisangles,
                diaptor
            });
            console.log('result--->', result);
            return result;
        } catch (error) {
            console.error('Error fetching dropdown options:', error);
            return {};
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

    handleClose() {
        // Fire an event to notify Aura component to close the Quick Action
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
    }

    handlenext() {
        this.showsapcoderemark = true;
        this.showdefaultrow = false;

    }


    handleSave() {
        this.enablesave = true;
        // let finaldata = [];
        this.finalDataListToSave = [];
        const rmarkandsapcode = {
            sapCode: this.selectedSAPCode,
            remark: this.remark
        };

        console.log('FinalList', JSON.stringify(this.showSampleList));
        console.log('FinalList', JSON.stringify(this.showSampleList));

        this.finalDataListToSave = this.showSampleList.map(row => ({
            key: row.key,
            productName: row.productName,
            productModel: row.productModel,
            sphericalPower: row.sphericalPower,
            cylindricalPower: row.cylindricalPower,
            axisAngle: row.axisAngle,
            diaptor: row.diaptor,
            commercialQuantity: row.commercialQuantity,
        }));

        console.log('finalDataListToSave Data:', this.finalDataListToSave);
        this.callApexMethod(this.finalDataListToSave, this.recordId, rmarkandsapcode);
    }

    // Call Apex method
    callApexMethod(finaldata, recordId, rmarkandsapcode) {
        saveSampleRequestData({ finalData: finaldata, recordId: recordId, rmarkandsapcode: rmarkandsapcode })
            .then(result => { // Capture the result from Apex
                console.log('Apex method result:', result); // Debugging

                if (result === 'success') { // Use result properly
                    this.saveButtonError = true;
                    setTimeout(() => {
                        this.showToast('Success', 'Sample Request Submitted successfully!', 'success');
                        window.location.reload(); // Reloads the page
                    }, 1000); // 1000ms = 1 second
                }
            })

            .catch(error => {
                console.error('Error:', error);
                this.showToast('Error', 'Failed to save data.', 'error');
            });
        //this.handleCancel();
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




}