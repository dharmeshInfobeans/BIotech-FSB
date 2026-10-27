import { LightningElement, api, wire, track } from 'lwc';
import getCisHeader from '@salesforce/apex/SumbitCeCisController.getCisHeader';
import getCisConfigData from '@salesforce/apex/SumbitCeCisController.getCisConfigData';
import saveData from '@salesforce/apex/SumbitCeCisController.saveData';
import getCisError from '@salesforce/apex/SumbitCeCisController.getCisError';
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
import { CloseActionScreenEvent } from 'lightning/actions';
import LightningModal from 'lightning/modal';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import getReturnCisHeaderAndLineItem from '@salesforce/apex/SumbitCeCisController.returnCisHeaderAndLineItem';
import getActiveCurrencies from '@salesforce/apex/SumbitCeCisController.getActiveCurrencies';
import getAccountSelectedCurrency from '@salesforce/apex/SumbitCeCisController.getAccountSelectedCurrency';
import updateCisHeaderAndLineItem from '@salesforce/apex/SumbitCeCisController.updateCisHeaderAndLineItem';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';
import CURRENCY_ISO from '@salesforce/schema/User.DefaultCurrencyIsoCode';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent} from 'lightning/platformShowToastEvent';
export default class CeCisLwc extends LightningElement {
    @track gridData;
    @track columns = [
        { type: 'text', fieldName: 'Name', label: 'Header No.' },
        { type: 'text', fieldName: 'Product__c', label: 'Product' },
        { type: 'text', fieldName: 'Company__c', label: 'Company' },
        { type: 'number', fieldName: 'No_of_Surguries__c', label: 'No. of Procedure', cellAttributes: { alignment: 'left' } },
        {type: 'number',fieldName:'Local_Avg_Purchase_Price__c', label:'Price/Unit',cellAttributes: { alignment: 'left' }},
        {type: 'number',fieldName:'Local_Value__c', label:'Local Value',cellAttributes: { alignment: 'left' }},
        { type: 'text', fieldName: 'Phakic_Rating__c', label: 'Phakic Rating', cellAttributes: { alignment: 'left' } },
        { type: 'text', fieldName: 'Ce_Cis_Rating__c', label: 'Ce -Cis Rating', cellAttributes: { alignment: 'left' } },
        {type: 'number', fieldName: 'Total__c', label: 'Total Value', cellAttributes: { alignment: 'left' }}


    ];
    data = [];

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
    userCurrency;
    @track currenciesData = [];
    @track headerId = '';
    @track recordIsForUpdate = false;
    @track selectedCurrency = '';
    @track currencyOptions = [];
    @api recordId;
    @api objectName;
    @track ProductList = [];
    @track CompaniesList = [];
    @track cisHeaderList = {};
    @track showData = false;
    @track showDataList = [];
    @track spinner = false;
    @track typeData = '';
    getInformationDataMap = new Map();
    @track getDataList = [];
    @track lvcData = '0';
    @track regularData = 0;
    @track premiumData = 0;
    @track totalData = 0;
    @track myValueTotal = 0;
    @track saveButtonError = false;
    @track regularPercentage = 0;
    @track premiumPercentage = 0;
    @track phakicTotal = 0;
    @track showErrorList = [];
    @track showAtLeastOneRow = [];
    @track isLoading = true;
    @track isDataFound = true;
    wiredCurrencyResult;
    wiredGetReturnCisHeaderAndLineItemResult;
    wiredGetAccountSelectedCurrencyResult;
    wiredErrorResult;
    @track isSave = false;
    @track formattedDate;
    @track isMobile = false;
    @track isDesktop = false;


    connectedCallback() {
        // console.log('conncted call...................');
        // console.log('record Id', this.recordId);
        // console.log('Object name', this.objectName);

        setTimeout(() => {
            this.handleApexrefresh();
        }, 500)

    }
    connectedCallback() {
        this.checkDeviceType();
        window.addEventListener('resize', () => this.checkDeviceType());
    }
    @wire(getActiveCurrencies)
    wiredCurrencies(result) {
        this.wiredCurrencyResult = result; // store for refreshApex

        if (result.data) {
            this.currenciesData = result.data;
            this.currencyOptions = result.data.map(cur => ({
                label: cur.IsoCode,
                value: cur.IsoCode
            }));
        } else if (result.error) {
            console.error('Error while getting currency:', result.error);
        }
    }

    checkDeviceType() {
        if (window.innerWidth <= 768) {
            this.isMobile = true;
            this.isDesktop = false;
        } else {
            this.isMobile = false;
            this.isDesktop = true;
        }
    }


    @wire(getReturnCisHeaderAndLineItem, { recordId: '$recordId' })
    wiredData(result) {
        this.wiredGetReturnCisHeaderAndLineItemResult = result;
        if (result.data) {
            this.showDataList = [];
            if (result.data.length > 0) {

                console.log('result.data for getReturnCisHeaderAndLineItem', result.data);
                let tempHeader = result.data[0];
                this.lvcData = tempHeader.No_of_LVC_Procedures__c || '0';
                this.regularData = tempHeader.Regular_Percentage__c || 0;
                this.premiumData = tempHeader.Premium_Percentage__c || 0;
                this.totalData = tempHeader.Ce_Cis_Rating__c || 0;
                this.myValueTotal = tempHeader.Total__c || 0;
                this.phakicTotal = tempHeader.Phakic_Rating__c || 0;
                this.premiumPercentage = tempHeader.Premium_Percentage__c || 0;
                this.headerId = tempHeader.Id || '';
                let date1 = new Date(tempHeader.LastModifiedDate);
                if (date1) {
                    let d = new Date(date1);
                    this.formattedDate = d.toLocaleString('en-GB', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit', hour12: true }).replace(',', '');
                }

                console.log('tempHeader.Status__c', tempHeader.Status__c);
                setTimeout(() => {
                    if (tempHeader.Status__c != 'Approved' && tempHeader.Status__c != 'Rejected') {
                        this.recordIsForUpdate = true;
                    } else {
                        console.log('huoihoi', tempHeader.Status__c);
                        this.recordIsForUpdate = false;
                    }
                }, 200)

                setTimeout(() => {
                    for (var i = 0; i < tempHeader.CIS_Lines__r.length; i++) {

                        this.showDataList.push({
                            'Id': tempHeader.CIS_Lines__r[i].Id || '',
                            key: i,
                            'Type': tempHeader.CIS_Lines__r[i].local_type__c || '',
                            'Product': tempHeader.CIS_Lines__r[i].Product__c || '',
                            'Company': tempHeader.CIS_Lines__r[i].Company__c || '',
                            'Value': tempHeader.CIS_Lines__r[i].No_of_Surguries__c || 0,
                            'CompanyList': this.loadPredefineCompanyList(tempHeader.CIS_Lines__r[i].Product__c, i),
                            'regular': '',
                            'Premium': '',
                            'Phakic': '',
                            'label': '',
                            'PhakicType': '',
                            'Price': tempHeader.CIS_Lines__r[i].Local_Avg_Purchase_Price__c || 0,
                            'PriceValue': (tempHeader.CIS_Lines__r[i].Local_Avg_Purchase_Price__c * tempHeader.CIS_Lines__r[i].No_of_Surguries__c) || 0,
                            'AveragePrice': '',
                            'UsdPriceTotal': '',
                            'localPrice':tempHeader.CIS_Lines__r[i].Local_Avg_Purchase_Price__c || 0


                        });
                    }

                }, 300);

            } else {
                setTimeout(() => {
                    for (var i = 0; i < 3; i++) {
                        this.showDataList.push({
                            key: i,
                            'Type': '',
                            'Product': '',
                            'Company': '',
                            'Value': '',
                            'CompanyList': [],
                            'regular': '',
                            'Premium': '',
                            'Phakic': '',
                            'label': '',
                            'PhakicType': '',
                            'Price': '',
                            'PriceValue': '',
                            'AveragePrice': '',
                            'UsdPriceTotal': '',
                            'localPrice':''


                        });
                    }
                }, 300);
            }
            console.log('data of tree grid', result.data);
            this.gridData = result.data.map(header => {
                let children = [];
                if (header.CIS_Lines__r) {
                    children = header.CIS_Lines__r.map(line => ({

                        Id: line.Id,
                        Name: line.Name,
                        Product__c: line.Product__c,
                        Company__c: line.Company__c,
                        No_of_Surguries__c: line.No_of_Surguries__c,
                        Phakic_Rating__c: '-',
                        Ce_Cis_Rating__c: '-',
                        Local_Avg_Purchase_Price__c:line.Local_Avg_Purchase_Price__c?line.Local_Avg_Purchase_Price__c:'-',
                        Local_Value__c: line.Local_Value__c?line.Local_Value__c:'-'
                    }));
                }
                return {
                    Id: header.Id,
                    Name: header.Name,
                    Phakic_Rating__c: header.Phakic_Rating__c ? header.Phakic_Rating__c : '-',
                    Ce_Cis_Rating__c: header.Ce_Cis_Rating__c ? header.Ce_Cis_Rating__c : '-',
                    Total__c:header.Total__c ?header.Total__c : '-', 
                    _children: children
                };
            });
        } else if (result.error) {
            console.error('Error loading CIS Data', error);
        }
    }
    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'CIS_Headers__r',
        fields: ['CIS_Header__c.Id', 'CIS_Header__c.Name', 'CIS_Header__c.Regular_Percentage__c', 'CIS_Header__c.Premium_Percentage__c', 'CIS_Header__c.Total__c', 'CIS_Header__c.Phakic__c', 'CIS_Header__c.Premium_Percentage__c']
    })
    listInfo({ error, data }) {
        if (data) {


            if (data.records.length > 0) {
                let tempData = [];
                console.log('data of related wire', data);
                tempData = data.records.map(item => ({
                    Name: item?.fields.Name?.value || '',
                    Id: item.Id,
                    Regular_Percentage__c: item?.fields.Regular_Percentage__c?.value || 0,
                    Premium_Percentage__c: item?.fields.Regular_Percentage__c?.value || 0,
                    Total__c: item?.fields.Regular_Percentage__c?.value || 0,
                    Phakic__c: item?.fields.Regular_Percentage__c?.value || 0,
                    Premium_Percentage__c: item?.fields.Regular_Percentage__c?.value || 0
                }))

                this.data = tempData;
                this.isLoading = false;
                this.isDataFound = true;
                console.log('tempData of data tavel', tempData);
            } else {
                this.isLoading = false;
                this.isDataFound = false;
            }

        } else if (error) {
            console.error('error on loading wire', error);
        }
    }

    @wire(getCisError, {
        recordId: '$recordId'
    })
    getError(result) {
        this.wiredErrorResult = result;
        console.log('result data', result.data);
        if (result.data == 'error') {
            console.log('Test error');
            this.saveButtonError = true;
            const evt = new ShowToastEvent({
                title: 'Approval Required',
                message: 'You can not create records because there is one existing CIS record that is not approved yet. Kindly get it Approved.',
                variant: 'warning',
                mode: 'dismissable'
            });

            this.dispatchEvent(evt);
             this.handleApexrefresh();
            

        }


        if (result.data == 'leadConvertedError') {
            this.saveButtonError = true;
            const evt = new ShowToastEvent({
                title: 'Error',
                message: 'You can not update the records because the Lead  has already converted.',
                variant: 'error',
                mode: 'dismissable'
            });

            this.dispatchEvent(evt);

        }
    }



    @wire(getCisHeader, {
        recordId: '$recordId'
    })
    getCisData(result) {
        console.log('Result', result);
        if (result.data) {
            console.log('result.data.Company', result.data.Company);
            console.log(result.data.Category)
            this.getLabelValue(result.data.Company);
            this.categoryList = result.data.Category;
            // for (var i = 0; i < 3; i++) {
            //     this.showDataList.push({
            //         key: i,
            //         'Type':'',
            //         'Product': '',
            //         'Company': '',
            //         'Value': '',
            //         'CompanyList': [],
            //         'regular': '',
            //         'Premium': '',
            //         'Phakic': '',
            //         'label': '',
            //         'PhakicType':'',
            //         'Price':'',
            //         'PriceValue':''


            //     });
            // }
            console.log('Show List', this.showDataList);

        }

        if (result.error) {
            console.log('error', result.error);
        }
    }
    @wire(getAccountSelectedCurrency, { recordId: '$recordId' })
    wiredCurrency(result) {
        this.wiredGetAccountSelectedCurrencyResult = result;
        if (result.data) {
            this.selectedCurrency = result.data || '';
            console.log('Selected Currency:', result.data);
        } else if (result.error) {
            console.error('Error fetching currency:', error.message);
        }
    }
    @wire(getRecord, { recordId: USER_ID, fields: [CURRENCY_ISO] })
    wiredUser({ error, data }) {
        if (data) {
            // this.userCurrency = data.fields.DefaultCurrencyIsoCode.value;
            if (this.selectedCurrency == '') {
                this.selectedCurrency = data?.fields?.DefaultCurrencyIsoCode?.value || '';
            }
        } else if (error) {
            console.error(error);
        }
    }

    handleAddRow() {
        for (var i = this.showDataList.length; i < this.showDataList.length + 1; i++) {
            this.showDataList.push({
                key: this.showDataList.length + 1,
                'Type': '',
                'Product': '',
                'Company': '',
                'Value': '',
                'CompanyList': [],
                'regular': '',
                'Premium': '',
                'label': '',
                'PhakicType': '',
                'phakic': '',
                'Price': '',
                'PriceValue': '',
                'AveragePrice': '',
                'UsdPriceTotal': '',
                'localPrice':''


            });
            if (this.showDataList.length == this.showDataList.length) {
                break;
            }
        }

    }
        handleDelete(event) {

            if (this.showDataList.length <= 1) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Cannot Delete',
            message: 'At least one row must remain.',
            variant: 'warning'
        }));
        return;
    }
            var curId = event.currentTarget.dataset.val;
            console.log('label', event.currentTarget.dataset.label);
            console.log('current Id', curId);
            var showData = [];
            for (var i = 0; i < this.showDataList.length; i++) {
                if (curId != this.showDataList[i].key) {
                    showData.push(this.showDataList[i]);
                }
            }

            this.showDataList.forEach(Element => {
                if (curId == Element.key) {

                    if (Element.Type == 'Regular') {

                        if (Element.regular != undefined && Element.regular != '') {
                            this.regularData = parseInt(this.regularData) - parseInt(Element.regular);


                            this.totalData = parseInt(this.totalData) - parseInt(Element.regular);
                            console.log('regular total', this.totalData);
                        }

                    }
                    if (Element.Type == 'Premium') {

                        if (Element.Premium != undefined && Element.Premium != '') {
                            this.premiumData = parseInt(this.premiumData) - parseInt(Element.Premium);

                            this.totalData = parseInt(this.totalData) - parseInt(Element.Premium);

                        }

                    }
                    if (Element.Type == 'Phakic') {

                        if (Element.phakic != undefined && Element.phakic != '') {
                            this.phakicTotal = parseInt(this.phakicTotal) - parseInt(Element.phakic);

                        }

                    }


                }
            });
            console.log('regular data', this.regularData);
            console.log('total data', this.totalData);

            this.regularPercentage = Math.floor((this.regularData / this.totalData) * 100.0);

            this.premiumPercentage = Math.round((this.premiumData / this.totalData) * 100.0);
            if (isNaN(this.regularPercentage)) {
                this.regularPercentage = 0;
            }
            if (isNaN(this.premiumPercentage)) {
                this.premiumPercentage = 0;
            }

            console.log('Regular percentage', this.regularPercentage);
            console.log('Premium percetage', this.premiumPercentage);
            this.showDataList = showData;

        }

    handleCancel() {
        console.log('cancel working');
        // try{
        //       this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
        // }
        // catch(error){
        //     console.log('error on closing',error);
        // }


        this.dispatchEvent(new CustomEvent('close'));
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    getLabelValue(companyList) {

        for (var key in companyList) {
            try {
                this.ProductList.push({
                    label: companyList[key],
                    value: companyList[key]
                });
            } catch (error) {
                console.log('error', error);
            }

        }


    }

    handleDataChange(event) {

        var curId = event.currentTarget.dataset.val;
        console.log('Current Id', curId);
        var phakic = event.currentTarget.dataset.value;
        console.log('Phakic', phakic);
        console.log('event.currentTarget.dataset.label', event.currentTarget.dataset.label);

        try {
            this.showDataList = JSON.parse(JSON.stringify(this.showDataList)); //for showing the regular premium
            console.log('showDataList', this.showDataList);
            this.showDataList.forEach(Element => {
                if (Element.key == curId) {
                    Element.label = event.currentTarget.dataset.label;

                    if (event.currentTarget.dataset.label == 'Product') {
                        Element.Product = event.target.value;
                        if (event.target.value == 'Hydrophilics') {
                            Element.Type = 'NON-Regular';

                        }
                        if (event.target.value == 'Phakic' || event.target.value == 'Phakic Family') {
                            // Element.Type = event.target.value;
                            Element.Type = 'Phakic';
                        }
                        if (event.target.value == 'Hydrophobic Monofocal' || event.target.value == 'Popular Hydrophobic Monofocal') {
                            Element.Type = 'Regular';


                        } if (event.target.value == 'Toric' || event.target.value == 'MF Family' || event.target.value == 'Trifocal Family' || event.target.value == 'EDOF Family' || event.target.value == 'Premium EDOF Family') {
                            Element.Type = 'Premium';
                        }
                    }
                    if (event.currentTarget.dataset.label == 'Company') {
                        Element.Company = event.target.value;
                    }
                    if (event.currentTarget.dataset.label == 'Value') {
                        Element.Value = event.target.value;
                        //  let tempPrice = this.convertCurrency(this.selectedCurrency,(Number(event.target.value) * Number(Element.Price || 0)),this.currenciesData,'USD');
                        Element.PriceValue = Number(event.target.value) * Number(Element.Price || 0);
                        console.log('521--->', this.convertCurrency(this.selectedCurrency, (Number(event.target.value) * Number(Element.Price || 0)), this.currenciesData, 'USD'));
                        // console.log('PriceValue364', Element.PriceValue);
                        if (Element.Type == 'Regular') {
                            Element.regular = event.target.value;
                        }
                        if (Element.Type == 'Premium') {
                            Element.Premium = event.target.value;
                        }
                        if (Element.Type == 'Phakic') {
                            console.log('Test phakic');
                            Element.phakic = event.target.value;
                            console.log('Element phakic', Element.phakic);
                        }
                    }
                    if (event.currentTarget.dataset.label == 'price') {
                        Element.Price = event.target.value;
                        Element.AveragePrice = Element.Price;
                        // let tempPrice=this.convertCurrency(this.selectedCurrency,(Number(Element.Value || 0) * Number(event.target.value || 0)),this.currenciesData,'USD');
                        Element.PriceValue = Number(Element.Value || 0) * Number(event.target.value || 0);

                        console.log('Event.Value', Event.Value);
                        console.log('event.target.value', event.target.value);
                        // Element.PriceValue = Number(Element.Value || 0) * Number(event.target.value || 0);
                        console.log('PriceValue364', Element.PriceValue);
                        this.calculateSumOfValue();

                    }

                }

            });

            if (event.currentTarget.dataset.label == 'Value') {
                this.regularData = 0;
                this.totalData = 0;
                this.premiumData = 0;
                this.regularPercentage = 0;
                this.premiumPercentage = 0;
                this.phakicTotal = 0;
                this.showDataList.forEach(Element => {
                    if (Element.Type == 'Regular') {

                        if (Element.regular != undefined && Element.regular != '') {
                            this.regularData = parseInt(this.regularData) + parseInt(Element.regular);

                            this.totalData = parseInt(this.totalData) + parseInt(Element.regular);
                        }



                    }
                    if (Element.Type == 'Premium') {
                        if (Element.Premium != undefined && Element.Premium != '') {
                            this.premiumData = parseInt(this.premiumData) + parseInt(Element.Premium);
                            this.totalData = parseInt(this.totalData) + parseInt(Element.Premium);

                        }
                    }
                    /*    if (Element.value != undefined && Element.value != '') {
                           
                        }*/
                    if (Element.Type == 'Phakic') {

                        if (Element.phakic != undefined && Element.phakic != '') {
                            this.phakicTotal = parseInt(this.phakicTotal) + parseInt(Element.phakic);
                        }

                        console.log('Phakic value', event.target.value);

                    }

                });



                if (this.regularData != undefined && this.regularData != '') {
                    this.regularPercentage = Math.floor((this.regularData / this.totalData) * 100.0);
                }
                if (this.premiumData != undefined && this.premiumData != '') {
                    this.premiumPercentage = Math.round((this.premiumData / this.totalData) * 100.0)
                        ;
                    ;
                }



            }



            console.log('phakic total', this.phakicTotal);
            console.log('Product List', this.showDataList);
            if (event.currentTarget.dataset.label == 'Product') { //Get the Company data according to the Product
                getCisConfigData({
                    recordId: this.recordId,
                    poductName: event.target.value
                }).then(result => {

                    this.showDataList.forEach(Element => {
                        if (Element.key == curId) {
                            Element.CompanyList = result.Company;
                            console.log('Element.CompanyList----: ', result.Company);
                        }

                    });
                }).catch(error => {
                    console.log('error', error);
                })
            }

        } catch (error) {
            console.log('error', error);
        }



    }



    handleSave(event) {
       
        console.log('regular percetae', this.regularPercentage);
        console.log('Premium  percenetage', this.premiumPercentage);
        console.log('sumbit button', event.target.value);
        var submit = event.target.value;
        this.spinner = true;
        this.saveButtonError = true;
        console.log('lenght of LVc', this.lvcData, this.lvcData.toString().length);
        if (this.lvcData.toString().length > 4) {
            this.showErrorList.push(Element);
            const event = new ShowToastEvent({
                title: 'Error',
                message: 'Please Enter the Number of LVC in 4 character',
                variant: 'error',
                mode: 'dismissable'
            });
            this.dispatchEvent(event);
        }
        console.log('123456789')


        this.showErrorList = [];

        console.log('data list', this.showDataList);
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
            if(!Element.Value){

                this.showErrorList.push(Element);
                    const event = new ShowToastEvent({
                        title: 'Error',
                        message: 'Please fill No. of Procedure/Year',
                        variant: 'error',
                        mode: 'dismissable'
                    });
                    this.dispatchEvent(event);
                    return;
            }
            if(!Element.Price){

                this.showErrorList.push(Element);
                    const event = new ShowToastEvent({
                        title: 'Missing Value',
    message: 'Please enter the Price per Unit.',
    variant: 'error',
    mode: 'dismissable'
                    });
                    this.dispatchEvent(event);
                    return;
            }

            Element.AveragePrice = Element.Price;
            Element.localPrice = this.convertCurrency(this.selectedCurrency, Element.Price, this.currenciesData, 'USD');
            // local price value
            Element.PriceValue = `${Element.PriceValue}`;
            Element.UsdPriceTotal = `${(Element.localPrice * Element.Value).toFixed(3)}`;
            // Element.PriceValue=`${this.selectedCurrency}  ${Element.PriceValue}`;
            // Element.UsdPriceTotal=`USD  ${(Element.Price * Element.Value).toFixed(3)}`;

            console.log('Element.Price', Element.Price);
            console.log('Element.Value', Element.PriceValue);
            console.log('Element.UsdPriceTotal', Element.UsdPriceTotal);

        });
        console.log('764--->',this.showDataList);
        if (this.showErrorList.length > 0) {
            this.spinner = false;
            this.saveButtonError = false;
        }
        console.log('show error List', this.showErrorList.length);
        if (this.showErrorList.length == 0 && this.lvcData.toString().length <= 4) {
             this.isSave = true;
            console.log('inside working');
            console.log('recordIsForUpdate', this.recordIsForUpdate);
            if (this.recordIsForUpdate) {
                let tempShowDataList = this.showDataList;
              /*  tempShowDataList.forEach(ele => {
                    delete ele['CompanyList'];
                    delete ele['key'];
                })*/
                this.tempShowDataList = JSON.parse(JSON.stringify(tempShowDataList));
                console.log('before update', this.showDataList);
                updateCisHeaderAndLineItem({
                    CeCisDataList: this.showDataList,
                    lvcData: this.lvcData,
                    selectedCurrency: this.selectedCurrency,
                    headerId: this.headerId
                }).then(result => {

                    this.spinner = false;
                    this.saveButtonError = true;
                    window.location.reload();
                    const event = new ShowToastEvent({
                        title: 'Success',
                        message: 'Succesfully Update records',
                        variant: 'success',
                        mode: 'dismissable'
                    });

                    this.dispatchEvent(event);
                    this.dispatchEvent(new CustomEvent('close'));




                    console.log('successfull');
                }).catch(error => {
                    this.isSave = false;
                    console.log('Error While updatiing', error);
                     const evt = new ShowToastEvent({
                        title: 'Approval Required',
                        message: 'You can not create records because there is one existing CIS record that is not approved yet. Kindly get it Approved.',
                        variant: 'warning',
                        mode: 'dismissable'

                    });
                    this.dispatchEvent(evt);
                    this.handleApexrefresh();
                })
                console.log('on Record Save', this.showDataList, this.headerId);

            } else {
                saveData({
                    CeCisDataList: this.showDataList,
                    recordId: this.recordId,
                    lvcData: this.lvcData,
                    submitData: submit,
                    premium: this.premiumPercentage,
                    regular: this.regularPercentage,
                    selectedCurrency: this.selectedCurrency

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
                        this.dispatchEvent(event);
                        this.dispatchEvent(new CustomEvent('close'));
                        window.open('https://biotechcrm.lightning.force.com/lightning/r/CIS_Header__c/' + result + '/view')
                    }
                }).catch(error => {
                    this.isSave = false;
                    this.spinner = false;
                    this.saveButtonError = false;
                    console.log('error---800', error.body.message);
                    var errordata = [];
                    errordata = error.body.message.split(',');
                    const evt = new ShowToastEvent({
                        title: 'Approval Required',
                        message: error.body?.message,
                        //message: 'You can not create records because there is one existing CIS record that is not approved yet. Kindly get it Approved.',
                        variant: 'warning',
                        mode: 'dismissable'

                    });
                    this.dispatchEvent(evt);
                    this.handleApexrefresh();
                })

            }


        }
    }
    handleLvc(event) {
        this.lvcData = event.target.value;
        console.log('Lvc ', this.lvcData);
    }

    async loadPredefineCompanyList(productName, curId) {
        try {
            const result = await getCisConfigData({
                recordId: this.recordId,
                poductName: productName
            });

            let companyList = JSON.parse(JSON.stringify(result.Company));

            // Update showDataList for the specific element
            this.showDataList = this.showDataList.map(item => {
                if (item.key === curId) {
                    return { ...item, CompanyList: companyList };
                }
                return item;
            });

            return companyList; // optional, if you want to use it elsewhere
        } catch (error) {
            console.error('Error loading company list:', error);
            return [];
        }
    }
    convertCurrency(sourceIso, amount, currenciesData, targetIso) {
        if (!sourceIso || !targetIso || !amount || !currenciesData?.length) {
            return null;
        }

        const sourceCurrency = currenciesData.find(c => c.IsoCode === sourceIso);
        const targetCurrency = currenciesData.find(c => c.IsoCode === targetIso);

        if (!sourceCurrency || !targetCurrency) {
            console.error('Invalid ISO code provided');
            return null;
        }

        // Formula: amount in target = amount * (targetRate / sourceRate)
        const convertedAmount = amount * (targetCurrency.ConversionRate / sourceCurrency.ConversionRate);

        // Round to target currency decimal places
        // return parseFloat(convertedAmount.toFixed(targetCurrency.DecimalPlaces || 2));
        return convertedAmount;
    }


    handleCurrencyChange(event) {
        this.selectedCurrency = event.detail.value;
    }
    handleApexrefresh() {
        refreshApex(this.wiredGetReturnCisHeaderAndLineItemResult);
        refreshApex(this.wiredCurrencyResult);
        refreshApex(this.wiredGetAccountSelectedCurrencyResult);
        refreshApex(this.wiredErrorResult);
    }
    calculateSumOfValue(){
        let tempShowDataList= JSON.parse(JSON.stringify(this.showDataList));
        let tempMyValueTotal=0;
        tempShowDataList.forEach(ele=>{
            if(ele.PriceValue){
                            tempMyValueTotal=tempMyValueTotal + Number(ele.PriceValue);
            }

        })
        this.myValueTotal=tempMyValueTotal;
    }







    //12*12=144=== 1.872USD
    //24*24=576==== 7.5 USD  
    // 36*36=1296==== 16.85 USD
}