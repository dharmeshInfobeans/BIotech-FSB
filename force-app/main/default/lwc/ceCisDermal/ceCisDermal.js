import {
    LightningElement,
    api,
    wire,
    track
} from 'lwc';
import saveDermalData from '@salesforce/apex/SumbitCeCisController.saveDermalData';
import getAccountData from '@salesforce/apex/SumbitCeCisController.getAccountData';
import getProductData from '@salesforce/apex/SumbitCeCisController.getProductData';
import newCeCis from '@salesforce/label/c.CeCis';
import LvcProcedure from '@salesforce/label/c.CISProcedure';
import CisCategory from '@salesforce/label/c.CisCategory';
import CisCompany from '@salesforce/label/c.CisCompany';
import CisSurgeries from '@salesforce/label/c.CisSurgeries';
import CisType from '@salesforce/label/c.CisType';
import CisAddRow from '@salesforce/label/c.CisAddRow';
import CisCancel from '@salesforce/label/c.CisCancel';
import CisSave from '@salesforce/label/c.CisSave';
import Cisregular from '@salesforce/label/c.Cisregular';
import CisPremium from '@salesforce/label/c.CisPremium';
import CisTotal from '@salesforce/label/c.CisTotal';
import CisFooter from '@salesforce/label/c.CisFooter';
import CisFooterData from '@salesforce/label/c.CisFooterData';
import CisHeaderError from '@salesforce/label/c.CisHeaderError';
import { NavigationMixin } from 'lightning/navigation';


import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';
export default class CeCisLwc extends NavigationMixin(LightningElement) {

    label = {
        newCeCis,
        LvcProcedure,
        CisCategory,
        CisCompany,
        CisSurgeries,
        CisType,
        CisAddRow,
        CisCancel,
        CisSave,
        Cisregular,
        CisPremium,
        CisTotal,
        CisFooter,
        CisFooterData,
        CisHeaderError
    };
    @api recordId;
    @api objectName;
    @track ProductList = [];
    @track CompaniesList = [];
    @track cisHeaderList = {};
    @track showData = false;
    @track showDataList = [];
    @track spinner = false;
    @track totalData = 0;
    @track saveButtonError = false;

    @track accountMap = {};


    /*For dermal and ortho*/
    @track ortho = false;
    @track dermal = false;
    @track packageOf1MlInjection = [];
    @track currentRating = '';
    @track packageOfInjections = [];
    @track dermalPackage = [];

    connectedCallback() {
        console.log('record Id', this.recordId);
    }

    @wire(getAccountData, { recordId: '$recordId' })
    getData(result) {
        if (result.data) {
            console.log('Account data', result.data);

            if (result.data.CisHeader != undefined && result.data.CisHeader == 'ShowError') {
                const evt = new ShowToastEvent({
                    title: 'Error',
                    message: 'You can not create records because there is one existing CIS record that is not approved yet.',
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt);
                return;
            }
            this.accountMap = {};
            this.accountMap = result.data;
            this.getLabelValue(result.data.Company.Company);

            for (var i = 0; i < 3; i++) {
                this.showDataList.push({
                    key: i,
                    'Product': '',
                    'Company': '',
                    'value': '',
                    'ProductList': [],
                    'label': '',
                });
            }
            if (result.data.RecordType == 'Dermal') {
                this.ortho = false;
                this.dermal = true;
                this.packageOf1MlInjection = result.data.Package;
            }
            else if (result.data.RecordType == 'Ortho') {
                this.dermal = false;
                this.ortho = true;
                this.dermalPackage = result.data.Package;
            }
        }
        if (result.error) {
            console.log('Error', result.error);
        }
    }

    handleAddRow() {
        for (var i = this.showDataList.length; i < this.showDataList.length + 1; i++) {
            this.showDataList.push({
                key: this.showDataList.length + 1,
                'Product': '',
                'Company': '',
                'value': '',
                'ProductList': [],
                'label': '',
            });
            if (this.showDataList.length == this.showDataList.length) {
                break;
            }
        }

    }
    handleDelete(event) {
        var curId = event.currentTarget.dataset.val;
        console.log('label', event.currentTarget.dataset.label);
        console.log('current Id', curId);
        var showData = [];
        for (var i = 0; i < this.showDataList.length; i++) {
            if (curId != this.showDataList[i].key) {
                showData.push(this.showDataList[i]);
            }
        }
        this.showDataList = showData;
        console.log('data list', this.showDataList);
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }


    handleDataChange(event) {
        var curId = event.currentTarget.dataset.val;
        try {
            if (this.dermal && event.target.name == 'PackageOf1MLInjections') {
                this.currentRating = '';
                this.currentRating = event.target.value;
            } else if (this.ortho && event.target.name == 'DermalPackage') {
                this.currentRating = '';
                this.currentRating = event.target.value;
            }
            console.log('currnet name',event.target.name);
            console.log('current rating',this.currentRating);
            this.showDataList = JSON.parse(JSON.stringify(this.showDataList)); //for showing the regular premium
            this.showDataList.forEach(Element => {
                if (Element.key == curId) {
                    Element.label = event.currentTarget.dataset.label;

                    if (event.currentTarget.dataset.label == 'Product') {
                        Element.Product = event.target.value;
                    }
                    if (event.currentTarget.dataset.label == 'Company') {
                        Element.Company = event.target.value;
                    }
                    if (event.currentTarget.dataset.label == 'Value') {
                        Element.value = event.target.value;
                    }

                }
            });
            if (event.currentTarget.dataset.label == 'Company') { //Get the Company data according to the Product

                getProductData({
                    recordType: this.accountMap.RecordType,
                    country: this.accountMap.Country,
                    company: event.target.value
                }).then(result => {
                    console.log('result', result);
                    this.showDataList.forEach(Element => {
                        if (Element.key == curId) {
                            Element.ProductList = result.Product;
                        }
                    });
                }).catch(error => {
                    console.log('error', error);
                })
            }
            if (event.currentTarget.dataset.label == 'value') {
                this.totalData = 0;
                this.showDataList.forEach(Element => {
                    if (Element.value != undefined && Element.value != '') {
                        if (isNaN(this.totalData)) {
                            this.totalData = 0;
                        }
                        console.log('Current Value', Element.value);
                        console.log('total data', this.totalData);
                        this.totalData = parseInt(this.totalData) + parseInt(Element.value);
                    }

                });
            }


        } catch (error) {
            console.log('error', error);
        }
    }

    handleSave(event) {
        console.log('this.showDataList : ',JSON.stringify(this.showDataList));
        var submit = event.target.value;
        this.spinner = true;
        this.saveButtonError = true;
        this.showErrorList = [];
        this.showDataList.forEach(Element => {

            if (Element.Product != '') {
                if (Element.Company == '') {
                    this.showErrorList.push(Element);
                    const event = new ShowToastEvent({
                        title: 'Error',
                        message: 'Please fill the Company Name',
                        variant: 'error',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(event);

                }
            }
        });
        if (this.showErrorList.length > 0) {
            this.spinner = false;
            this.saveButtonError = false;
        }
        console.log('show error List', this.showErrorList.length);
        if (this.showErrorList.length == 0) {
            saveDermalData({
                cisDataList: this.showDataList,
                country: this.accountMap.Country,
                userId: this.accountMap.User,
                recordId: this.recordId,
                submitData: submit,
                currentRating: this.currentRating,
                totalValue: this.totalData,
                dermal: this.dermal,
                recordType: this.accountMap.RecordType
            }).then(result => {
                if (result == 'success') {
                    this.spinner = false;
                    this.saveButtonError = true;
                    window.location.reload();
                    const event = new ShowToastEvent({
                        title: 'Success',
                        message: 'Succesfully created records',
                        variant: 'success',
                        mode: 'dismissable'
                    });

                    this.dispatchEvent(event);
                    this.dispatchEvent(new CustomEvent('close'));


                } else {
                    this.spinner = false;
                    this.saveButtonError = true;
                    /* const event = new ShowToastEvent({
                         title: 'Success',
                         message: 'Succesfully created records',
                         variant: 'success',
                         mode: 'dismissable'
                     });*/
                    this.dispatchEvent(event);
                    this.dispatchEvent(new CustomEvent('close'));
                    window.open('https://biotechcrm--full.sandbox.lightning.force.com/lightning/r/CIS_Header__c/' + result + '/view')

                }

            }).catch(error => {
                this.spinner = false;
                this.saveButtonError = false;
                console.log('error', error);
                const evt = new ShowToastEvent({
                    title: 'Error',
                    message: 'Error in creating the records(Invalid data)',
                    variant: 'Error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt);
            })
        }
    }

    getLabelValue(companyList) {
        for (var key in companyList) {
            try {
                this.CompaniesList.push({
                    label: companyList[key],
                    value: companyList[key]
                });
            } catch (error) {
                console.log('error', error);
            }
        }
    }
}