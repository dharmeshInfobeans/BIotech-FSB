import { LightningElement, track, api, wire } from 'lwc';
import getProducts from "@salesforce/apex/calendarPlanningMobileController.getProducts";

import getProductsBySubCallType from '@salesforce/apex/calendarPlanningMobileController.getProductsBySubCallType';
import {
    registerListener,
    unregisterAllListeners,
    fireEvent
} from 'c/pubsub';
import {
    CurrentPageReference,
    NavigationMixin
} from 'lightning/navigation';
import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';
export default class MultiSelectPicklistWithSearch extends LightningElement {
    @api options;
    @api selectedValue;
    @api selectedValues = [];
    @api label;
    @api labels = {};
    @api minChar = 2;
    @api disabled = false;
    @api multiSelect = false;
    @track value;
    @track values = [];
    @track optionData;
    @api product;
    @track searchString;
    @track message;
    @track showDropdown = false;
    searchProdKey = null;
    selectedProductValues = new Map();
    @track selectedProductValuesList = [];
    @api showastrick;
    @track productData;
    @api calltype;

    @track productOptions = [];

    @track selectedProduct = '';


    /* renderedCallback() {
         registerListener('ProductshowData', this.ProductshowData, this);
     }
     ProductshowData(Product) {
         console.log('Test product');
         console.log('Finally Product ---',Product);
     }*/

    @api

    set subcalltype(value) {

        this._subcalltype = value;



        if (value) {

            this.fetchProductsBySubCallType(value);

        } else {





            console.log('Subcalltype blank → resetting to default products');



            // All selections reset

            this.values = [];

            this.value = '';

            this.selectedProductValues = new Map();

            this.selectedProductValuesList = '';

            this.searchString = '';

            this.showDropdown = false;



            // ⭐ MOST IMPORTANT:

            // Default products load from original apex getProducts

            this.loadDefaultProducts();



            console.log('Component reset due to empty subcalltype');

        }



    }

    get subcalltype() {

        return this._subcalltype;

    }

    @wire(CurrentPageReference) pageRef;
    @wire(getProducts)
    getProducts({ error, data }) {
        if (error) {
            console.log("Error in getProducts");
        } else if (data) {
            console.log('getProducts data ', data);
            var userData = data;
            this.options = userData.map(val => {
                return { label: val.Name, value: val.Name };
            });

            //   this.productsOptions = userData.map(val =>{
            //    return {label:val.Name,value:val.Id}
            //    });
            this.setProduct();
        }
    }

    connectedCallback() {
        console.log('searchKey: ', this.searchProdKey);
        console.log('showastrick: ', this.showastrick);

        // Handle case where 'product' might be undefined/null
        this.productData = this.product ? this.product.toUpperCase() : '';

        console.log('final product: ', this.productData);

        // Ensure 'showastrick' is correctly converted to boolean
        this.showastrick = this.showastrick === 'true';
    }


    setProduct() {
        try {
            const countData = 1;
            this.showDropdown = false;
            console.log('this.options ', this.options);
            var optionData = this.options ? (JSON.parse(JSON.stringify(this.options))) : null;
            console.log('optionData------ ', optionData);
            var value = this.selectedValue ? (JSON.parse(JSON.stringify(this.selectedValue))) : null;
            console.log('value ', value);
            var values = this.selectedValues ? (JSON.parse(JSON.stringify(this.selectedValues))) : null;
            console.log('values ', values);
            console.log('option datasss---', optionData);
            if (value || values) {
                var searchString;
                var count = 0;
                for (var i = 0; i < optionData.length; i++) {
                    if (this.multiSelect) {
                        if (values.includes(optionData[i].value)) {
                            optionData[i].selected = true;
                            count++;
                        }
                    } else {
                        if (optionData[i].value == value) {
                            searchString = optionData[i].label;
                        }
                    }
                }
                if (this.multiSelect)
                    this.searchString = count + ' ' + this.labels.selected__c;
                else
                    this.searchString = searchString;
            }
            console.log('setProduct');
            /*  this.optionData.forEach(Element=>{
             if(Element.label==this.productData) {
                 Element.selected=true;
             }
              });*/

            for (var i = 0; i < optionData.length; i++) {
                if (optionData[i].label == this.productData) {
                    optionData[i].selected = true;
                    this.searchString = countData + ' ' + 'options(s) selected';
                }
            }
            console.log('FInal option data', optionData);
            this.value = (value != null ? value : this.value);
            this.values = (values != null ? values : this.values);
            this.optionData = optionData;

        } catch (error) {
            console.log('Error in setProduct ', error);
        }
    }

    filterOptions(event) {
        try {
            this.searchString = event.target.value;
            this.searchProdKey = event.target.value;
            if (this.searchString && this.searchString.length > 0) {
                this.message = '';
                if (this.searchString.length >= this.minChar) {
                    var flag = true;
                    if (this.optionData != undefined) {
                        for (var i = 0; i < this.optionData.length; i++) {
                            if (this.optionData[i].label.toLowerCase().trim().includes(this.searchString.toLowerCase().trim())) {
                                this.optionData[i].isVisible = true;
                                flag = false;
                            } else {
                                this.optionData[i].isVisible = false;
                            }
                        }
                    }
                    if (flag) {
                        this.message = "No results found for '" + this.searchString + "'";
                    }
                }
                this.showDropdown = true;
            } else {
                this.showDropdown = false;
            }

        } catch (error) {
            console.log('Error in filterOptions ', error);
        }
    }

    selectItem(event) {
        try {
            var selectedVal = event.currentTarget.dataset.id;
            if (this.selectedProductValues.has(selectedVal)) {
                this.selectedProductValues.delete(selectedVal);
            } else {
                this.selectedProductValues.set(selectedVal, selectedVal);
            }
            this.selectedProductValuesList = Array.from(this.selectedProductValues.values()).join(';');
            console.log('this.users_selected ', this.users_selected);
            console.log('selectedVal ', selectedVal);
            if (selectedVal) {
                var count = 0;
                console.log('this.optionData ', this.optionData);
                var options = JSON.parse(JSON.stringify(this.optionData));
                console.log('option ', options);
                for (var i = 0; i < options.length; i++) {
                    //console.log('options[i].value ',options[i].value);
                    if (options[i].value === selectedVal) {
                        if (this.multiSelect) {
                            console.log('this.values ', this.values);
                            if (this.values != null) {
                                console.log('in if');
                                if (this.values.includes(options[i].value)) {
                                    //this.values.splice(this.values.indexOf(options[i].value), 1);
                                }
                            } else {
                                console.log('selectItem');
                                this.values.push(options[i].value);
                            }
                            options[i].selected = options[i].selected ? false : true;
                        } else {
                            this.value = options[i].value;
                            this.searchString = options[i].label;
                        }
                    }
                    if (options[i].selected) {
                        count++;
                    }
                }
                for (var i = 0; i < options.length; i++) {
                    if (options[i].value == this.productData) {
                        options[i].selected = true;
                    }
                }
                this.optionData = options;
                if (this.multiSelect)
                    this.searchString = count + ' ' + this.labels.selected__c;
                if (this.multiSelect)
                    event.preventDefault();
                else
                    this.showDropdown = false;
            }
            console.log('selectedProductValuesList ', this.selectedProductValuesList);
            const selectedProduct = new CustomEvent(
                "selectproduct",
                { detail: this.selectedProductValuesList }
            );
            this.dispatchEvent(selectedProduct);
        } catch (error) {
            console.log('Error in selectItem ', error);
        }
    }

    showOptions() {
        try {
            if (this.disabled == false && this.options) {
                this.message = '';
                this.searchString = '';
                var options = JSON.parse(JSON.stringify(this.optionData));
                for (var i = 0; i < options.length; i++) {
                    options[i].isVisible = true;
                }
                if (options.length > 0) {
                    this.showDropdown = true;
                }
                this.optionData = options;
            }
        } catch (error) {
            console.log('Error in showOptions ', error);
        }
    }

    removePill(event) {
        try {
            var value = event.currentTarget.name;
            console.log('removePill To be remove value ', value);

            console.log('removePill selectedProductValues ', this.selectedProductValues);
            var count = 0;
            var options = JSON.parse(JSON.stringify(this.optionData));
            console.log('removePill this.values ', this.values);
            var valuesToBeSplit;
            var splitedValue;
            if (this.selectedProductValues.size > 0) {
                valuesToBeSplit = Array.from(this.selectedProductValues.values()).join(';');
                splitedValue = String(valuesToBeSplit).split(';');
            } else {
                valuesToBeSplit = this.values;
                splitedValue = String(valuesToBeSplit).split(';');
            }
            console.log('valuesToBeSplit ', valuesToBeSplit);
            console.log('splitedValu ', splitedValue);
            this.selectedProductValues = new Map();
            for (var temp of splitedValue) {

                if (String(temp) != String(value)) {
                    console.log('In If temp ', temp);
                    this.selectedProductValues.set(temp, temp);
                }


            }
            console.log('removePill selectedProductValues ', this.selectedProductValues);
            this.selectedProductValuesList = Array.from(this.selectedProductValues.values()).join(';');
            this.value = this.selectedProductValuesList;
            console.log('removePill selectedProductValuesList ', this.selectedProductValuesList);
            for (var i = 0; i < options.length; i++) {
                if (options[i].value === this.productData) {
                    options[i].selected = true;
                }
                else {
                    if (options[i].value === value) {
                        options[i].selected = false;
                        //this.values.splice(this.values.indexOf(options[i].value), 1);
                    }
                }

                if (options[i].selected) {
                    count++;
                }
            }
            console.log('Options', options);
            this.optionData = options;
            console.log('Option data', this.optionData);
            if (this.multiSelect)
                this.searchString = count + ' Option(s) Selected';

        } catch (error) {
            console.log('Error in removePill ', error);
        }

        const selectedProduct = new CustomEvent(
            "selectproduct",
            { detail: this.selectedProductValuesList }
        );
        this.dispatchEvent(selectedProduct);
    }

    blurEvent() {
        try {
            var previousLabel;
            var count = 0;

            console.log('optionData-----', this.optionData);
            if (this.optionData != undefined) {
                for (var i = 0; i < this.optionData.length; i++) {
                    if (this.optionData[i].value === this.value) {
                        previousLabel = this.optionData[i].label;
                    }
                    if (this.optionData[i].selected) {
                        count++;
                    }
                }
            }
            if (this.multiSelect)
                this.searchString = count + ' Option(s) Selected';
            else
                this.searchString = previousLabel;

            this.showDropdown = false;

            this.dispatchEvent(new CustomEvent('select', {
                detail: {
                    'payloadType': 'multi-select',
                    'payload': {
                        'value': this.value,
                        'values': this.values
                    }
                }
            }));
        } catch (error) {
            console.log('Error in blurEvent ', error);
        }
    }


    fetchProductsBySubCallType(subCallTypeValue) {



        getProductsBySubCallType({ subCallType: subCallTypeValue })

            .then(result => {

                console.log('Products returned from Apex:', JSON.stringify(result));



                if (result && result.length > 0) {

                    this.optionData = JSON.parse(JSON.stringify(result));

                    this.options = this.optionData;

                    console.log('Converted productOptions:', this.options);



                } else {

                    this.optionData = [];

                    this.options = [];

                    this.dispatchEvent(

                        new ShowToastEvent({

                            title: 'Info',

                            message: 'No products found for selected sub-call type',

                            variant: 'info'

                        })

                    );

                }



                this.selectedProduct = '';

            })

            .catch(error => {

                console.error('Error fetching products by subCallType:', error);

                this.spinner = false;



                this.dispatchEvent(

                    new ShowToastEvent({

                        title: 'Error',

                        message: 'Failed to load products: ' + error.body.message,

                        variant: 'error'

                    })

                );

            });

    }



    loadDefaultProducts() {

        getProducts()
            .then(data => {
                if (data) {

                    this.options = data.map(val => ({

                        label: val.Name.toUpperCase(),

                        value: val.Name.toUpperCase()

                    }));

                    this.optionData = JSON.parse(JSON.stringify(this.options));

                    console.log('Default products loaded:', this.optionData);

                }
            })
            .catch(error => {

                console.error('Error loading default products:', error);

            });
    }
}