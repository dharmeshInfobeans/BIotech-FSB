import { LightningElement, wire, api, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import fetchDropdown from '@salesforce/apex/SampleRequestHeaderController.fetchDropdown';
import fetchProduct from '@salesforce/apex/SampleRequestHeaderController.fetchProduct';
import fetchProductModel from '@salesforce/apex/SampleRequestHeaderController.fetchProductModel';
import insertSampleRequest from '@salesforce/apex/SampleRequestHeaderController.insertSampleRequest';
import getAllRelatedAccount from '@salesforce/apex/SampleRequestHeaderController.getAllRelatedAccount';
import isOverLimit from '@salesforce/apex/SampleRequestHeaderController.isOverlimit';
import isFileMandatory from '@salesforce/apex/SampleRequestHeaderController.isFileMandatory';
import uploadFiles from '@salesforce/apex/SampleRequestHeaderController.uploadFiles';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import getAllProduct from '@salesforce/apex/SampleRequestHeaderController.getAllProduct';
import getVertical from '@salesforce/apex/SampleRequestHeaderController.getVertical';
import getCustomLabels from '@salesforce/apex/SampleRequestHeaderController.getCustomLabels';
import USER_ID from '@salesforce/user/Id';
import COUNTRY_FIELD from '@salesforce/schema/User.Country__c';
import VERTICAL_FIELD from '@salesforce/schema/User.Vertical__c';
import LANGUAGE_FIELD from '@salesforce/schema/User.Language__c';

export default class GenerateSampleRequestHeader extends NavigationMixin(LightningElement) {

    @track showSampleList = [];
    @track sampleRequestProduct = [];
    @track preSelectedDivisions = [];
    @api recordId = null;
    @track productFamily = '';
    @track system_var_1 = { sampleRequestHeaderfields: [], sampleRequestHeaderLinefields: [], vertical: '', opportunityName: '', accountId: '', billToCode: '', header: { 'Bill_To_Code__c': null, 'Ship_To_Code__c': null, 'Remarks__c': null, 'Country__c': null, 'RSM__c': null, 'ZSM__c': null, 'Bill_To_Address__c': null, 'Ship_To_Address__c': null, 'File_Upload_Mandatory__c': false, 'Contact__c': null }, sampleHeaderRecordId: null, documentId: null };
    @track system_var_boolean = {
        showSpinner: true, showPrompt: false, updateChangeVisibility: true
    };
    brandOptions = [];
    shipToAddress;
    listOfAccount;
    fileUploadMandatory = false;
    @track backupLensEnabled = new Map();
    @track isSaving = false;
    @track shipToCodeOptions;
    @track selectShipToAddress;
    @track country;
    @track parentId = null;
    @track isProductPromptOpen = false;
    @track isFileUploadOpen = false;
    @track showLimitWarningModal = false;
    @track stagedFiles = [];
    @track fileValidationError = false;
    MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024;
    @track totalQuantity = 0;
    pendingSaveLabel = null;
    selectedRowKey;
    userCountry;
    userVertical;
    userLanguage;
    @track monthLimit;
    @track labels = {};
    @wire(getCustomLabels)
    getLabels({ data, error }) {
        console.log('OUTPUT : data ',data);
        if (data) { this.labels = data; }
        if (error) console.log('error', error);
    }
    selectedrow = [];
    columns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Brand', fieldName: 'Brand__c' },
        { label: 'Product Model', fieldName: 'Group_Name__c' },
    ];
    quantityOptions = Array.from({ length: 75 }, (_, i) => ({ label: (i + 1), value: (i + 1) }));
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.c__recordId ? currentPageReference.state.c__recordId : null;
        }
    }
    errorCallback(error, stack) {

        // Best Practice: Log details for system debugging
        console.error('Captured Error: ' + error);
        console.error('Stack Trace: ' + stack);
    }
    @wire(getRecord, { recordId: '$recordId', fields: ['Opportunity__c.Name', 'Opportunity__c.Account__c', 'Opportunity__c.Id', 'Opportunity__c.Contact__c', 'Opportunity__c.Product_Group__r.Vertical__c', 'Opportunity__c.Account__r.Name', 'Opportunity__c.Account__r.SAP_Code__c', 'Opportunity__c.Account__r.ParentId', 'Opportunity__c.Account__r.RSM__c', 'Opportunity__c.Account__r.ZSM__c', 'Opportunity__c.Account__r.BillingCountry', 'Opportunity__c.Account__r.BillingCity', 'Opportunity__c.Product_Group__r.Product_Family__c', 'Opportunity__c.Product_Family__c'] })
    quoteRecord({ data, error }) {
        if (data) {
            //this.system_var_1.header.Ship_To_Code__c = (data?.fields?.Account__r?.value?.fields?.SAP_Code__c?.value ? data.fields.Account__r.value.fields.SAP_Code__c.value : '') + (data?.fields?.Account__r?.value?.fields?.SAP_Code__c?.value ? '-' : '') + (data?.fields?.Account__r?.value?.fields?.Name?.value ? data.fields.Account__r.value.fields.Name.value : '') + (data?.fields?.Account__r?.value?.fields?.BillingCity?.value ? '-' + data.fields.Account__r.value.fields.BillingCity.value : '');
            this.system_var_1.header.Bill_To_Code__c = (data?.fields?.Account__r?.value?.fields?.SAP_Code__c?.value ? data.fields.Account__r.value.fields.SAP_Code__c.value : '');
            this.system_var_1.billToCode = (data?.fields?.Account__r?.value?.fields?.SAP_Code__c?.value ? data.fields.Account__r.value.fields.SAP_Code__c.value + '-' : '') + (data?.fields?.Account__r?.value?.fields?.Name?.value ? data.fields.Account__r.value.fields.Name.value : '') + (data?.fields?.Account__r?.value?.fields?.BillingCity?.value ? '-' + data.fields.Account__r.value.fields.BillingCity.value : '');
            this.system_var_1.opportunityName = data?.fields?.Name?.value ? data.fields.Name.value : '';
            //this.system_var_1.vertical = data?.fields?.Product_Group__r?.value?.fields?.Vertical__c?.value ? data.fields.Product_Group__r.value.fields.Vertical__c.value : '';
            //this.system_var_1.vertical = 'ORTHOPAEDICS';
            this.system_var_1.accountId = data?.fields?.Account__c?.value ? data.fields.Account__c.value : '';
            this.system_var_1.header.Contact__c = data?.fields?.Contact__c?.value ? data.fields.Contact__c.value : '';
            this.selectShipToAddress = this.system_var_1.accountId;
            this.system_var_1.header.Country__c = (data?.fields?.Account__r?.value?.fields?.BillingCountry?.value ? data.fields.Account__r.value.fields.BillingCountry.value : null);
            this.country = this.system_var_1.header.Country__c ? this.system_var_1.header.Country__c : '';
            this.system_var_1.header.RSM__c = (data?.fields?.Account__r?.value?.fields?.RSM__c?.value ? data.fields.Account__r.value.fields.RSM__c.value : null);
            this.system_var_1.header.ZSM__c = (data?.fields?.Account__r?.value?.fields?.BillingCountry?.value ? data.fields.Account__r.value.fields.ZSM__c.value : null);
            // this.productFamily = (data?.fields?.Product_Group__r?.value?.fields?.Product_Family__c?.value ? data.fields.Product_Group__r.value.fields.Product_Family__c.value : '');
            this.productFamily = data?.fields?.Product_Family__c?.value ? data.fields.Product_Family__c.value : '';
            if (this.system_var_1.opportunityName) this.system_var_1.header.Opportunity__c = data?.fields?.Id?.value ? data.fields.Id.value : '';
            if (this.system_var_1.accountId) this.system_var_1.header.Customer__c = this.system_var_1.accountId;
            if (data?.fields?.Account__r?.value?.fields?.ParentId?.value) { this.parentId = data?.fields?.Account__r?.value?.fields?.ParentId?.value ? data.fields.Account__r.value.fields.ParentId.value : null; }
            else { this.parentId = data?.fields?.Account__c?.value ? data.fields.Account__c.value : ''; }
        } else if (error) { console.log('error while getting Opportunity Name', error); }
    }

    @wire(getRecord, { recordId: USER_ID, fields: [COUNTRY_FIELD, VERTICAL_FIELD, LANGUAGE_FIELD] })
    userRecord({ data, error }) {
        if (data) {
            this.userCountry = data.fields.Country__c.value;
            this.userVertical = data.fields.Vertical__c.value;
            this.userLanguage = data.fields.Language__c.value;
            console.log('Country:', this.userCountry, 'Vertical:', this.userVertical, 'Language:', this.userLanguage);

            if (!this.userCountry || !this.userVertical || !this.userLanguage) {
                const missingFields = [];
                if (!this.userCountry) missingFields.push('Country');
                if (!this.userVertical) missingFields.push('Vertical');
                if (!this.userLanguage) missingFields.push('Language');
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Missing User Information',
                        message: `Your user record is missing: ${missingFields.join(', ')}. Please contact your administrator to update this before proceeding.`,
                        variant: 'error',
                        mode: 'sticky'
                    })
                );
            }
        } else if (error) {
            console.error('Error fetching user fields', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Unable to fetch user details (Country/Vertical). Please contact your administrator.',
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        }
    }


    @wire(getAllRelatedAccount, { accountId: '$parentId' })
    shipToAddress({ data, error }) {
        if (data) {
            console.log('OUTPUT : ', data);
            this.shipToAddress = data.map(item => ({
                label: (item.SAP_Code__c ? item.SAP_Code__c + '-' : '') + item.Name + (item.BillingAddress ? item.BillingAddress.city ? '-' + item.BillingAddress.city : '' : ''),
                value: item.Id
            }));
            this.listOfAccount = new Map(data.map(item => [item.Id, item]));
        } else if (error) {
            console.error('Error fetching accounts', error);
        }
    }

    @wire(isFileMandatory, { country: '$country' })
    wiredFileMandatory({ data, error }) {
        if (data !== undefined) {
            this.fileUploadMandatory = data;
            this.system_var_1.header.File_Upload_Mandatory__c = this.fileUploadMandatory;
            console.log('File Upload Mandatory:', this.fileUploadMandatory);
        } else if (error) {
            console.error('Error fetching file mandatory config', error);
        }
    }

    @wire(getAllProduct, { productFamily: '$productFamily' })
    brandValue({ data, error }) {
        if (data) {
            this.brandOptions = data.map(val => ({
                label: val,
                value: val
            }));
            this.initializeRows(1);
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getVertical, { productFamily: '$productFamily' })
    setVertical({ data, error }) {
        if (data) {
            this.system_var_1.vertical = data;
            //    console.log('OUTPUT : this.system_var_1.vertical',this.system_var_1.vertical);
        } else if (error) {
            console.error(error);
        }
    }

    initializeRows(count) {
        if (this.showSampleList.length == 0) {
            for (let i = 0; i < count; i++) {
                this.showSampleList.push(this.getEmptyRow(i));
                this.totalQuantity++;

                console.log('OUTPUT this.totalQuantity: ', this.totalQuantity);
            }
            this.showSampleList = [...this.showSampleList];
        }
    }

    getEmptyRow(index) {
        return {
            key: index,
            brand: '',
            productModel: '',
            sphericalPower: '',
            cylinderPower: '',
            axis: '',
            diaptor: '',
            commercialQuantity: 1,
            productList: [],
            productModellist: [],
            sphericalPowerlist: [],
            cylindricalPowerlist: [],
            axisAngleList: [],
            diaptorList: [],
            sampleRequestProductList: this.sampleRequestProduct,
            selectedProductByRow: [],
            disableproductModelShow: true,
            disablesphericalPowerShow: true,
            disablecylindricalPowerShow: true,
            disableaxisAngleShow: true,
            disablediaptorShow: true,
            disablecommercialQuantityshow: true,
            showProduct: false,
            disableBackupCheckBox: true,
            disableBrand: false,
            hasBackUp: false,
            parentRow: -1,
            isBackupRow: false,
            parentRowDisplay: null,
            backupBtnLabel: '+ Add Backup',
            backupBtnClass: 'backup-btn',
            disableBilateral: true,
            isBilateralChecked: false,
        };
    }

    get fileUploadModalClass() {
        const isMobile = window.innerWidth <= 768;
        console.log('OUTPUT isMobile: ', isMobile);
        return isMobile
            ? 'slds-file_upload__container'
            : 'slds-modal__container file-upload-modal-container';
    }

    handleShipChange(event) {
        this.selectShipToAddress = event.detail.value;
    }

    handleMenuSelect(event) {
        const action = event.detail.value;
        this.selectedRowKey = event.target.dataset.id;

        if (action === 'prompt') {
            this.openProductPrompt();
        }

        if (action === 'delete') {
            this.handleDeleteRow(event);
        }
    }
    openProductPrompt() {
        this.isProductPromptOpen = true;
    }

    closeProductPrompt() {
        this.selectedrow = [];
        this.isProductPromptOpen = false;
    }

    handleProductSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (!selectedRows || selectedRows.length === 0) {
            return;
        }
        const selectedProduct = selectedRows[0];
        this.showSampleList[this.selectedRowKey].selectedProductByRow = selectedProduct;
    }

    handleAddRow() {
        this.showSampleList.push(this.getEmptyRow(this.showSampleList.length));
        this.totalQuantity++;
        console.log('OUTPUT this.totalQuantity: ', this.totalQuantity);
    }

    handleDeleteRow(event) {
        const curId = event.currentTarget.dataset.id;

        if (this.showSampleList.length > 1) {
            if (!this.showSampleList[curId].hasBackUp) {
                if (this.showSampleList[curId].parentRow != -1) {
                    this.showSampleList[this.showSampleList[curId].parentRow].disableBrand = false;
                    this.showSampleList[this.showSampleList[curId].parentRow].disableproductModelShow = false;
                    if (this.showSampleList[this.showSampleList[curId].parentRow].cylindricalPowerlist.length > 0) this.showSampleList[this.showSampleList[curId].parentRow].disablecylindricalPowerShow = false;
                    if (this.showSampleList[this.showSampleList[curId].parentRow].axisAngleList.length > 0) this.showSampleList[this.showSampleList[curId].parentRow].disableaxisAngleShow = false;
                    this.showSampleList[this.showSampleList[curId].parentRow].hasBackUp = false;
                    this.showSampleList[this.showSampleList[curId].parentRow].isBilateralChecked = false;
                    this.showSampleList[this.showSampleList[curId].parentRow].backupBtnLabel = '+ Add Backup';
                    this.showSampleList[this.showSampleList[curId].parentRow].backupBtnClass = 'backup-btn';
                }
                this.totalQuantity -= this.showSampleList[curId].commercialQuantity;
                console.log('OUTPUT this.totalQuantity: ', this.totalQuantity);
                this.showSampleList = this.showSampleList.filter(row => row.key != curId);
                this.showSampleList = this.showSampleList.map((row, index) => {
                    return {
                        ...row,
                        key: index
                    };
                });
            }
            else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'This row cannot be deleted because Backup is enabled.',
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
            }
        }
        else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'At least one line item is required. You cannot delete the last row.',
                    variant: 'error',
                    mode: 'dismissable'
                })
            );
        }
        if (!this.showSampleList || this.showSampleList.length === 0) {
            this.handlenextenable = true;
        }
    }
    handleOnLoadForm() { setTimeout(() => { this.system_var_boolean.showSpinner = false; }, 500); }

    handleClose() {
        this.handleRefresh();
        setTimeout(() => { window.location.reload(); }, 500);
        window.history.back();

    }

    handleRefresh() {
        this.system_var_1.header.Remarks__c = null;
        this.system_var_1.header.Ship_To_Code__c = null;
        this.system_var_1.header.Bill_To_Code__c = null;
        this.system_var_1.header.Country__c = null;
        this.system_var_1.header.RSM__c = null;
        this.system_var_1.header.ZSM__c = null;
        this.system_var_1.billToCode = null;
        this.showSampleList = [];
        this.initializeRows(1);
        this.handlenextenable = true;
        this.isFileUploadOpen = false;
        this.stagedFiles = [];
        this.fileValidationError = false;
    }

    handleHeaderFields(event) {
        const fieldName = event.target.fieldName;   // Ship_To_Code__c
        const fieldValue = event.target.value;
        this.system_var_1.header[fieldName] = fieldValue;
    }

    handleOpenFileUpload() {
        this.isFileUploadOpen = true;
    }

    handleCloseFileUpload() {
        this.isFileUploadOpen = false;
    }

    handleFileSelection(event) {
        const files = event.target.files;
        if (!files || files.length === 0) return;
        const acceptedExt = this.acceptedFormats;

        Array.from(files).forEach(file => {
            const ext = '.' + file.name.split('.').pop().toLowerCase();
            if (!acceptedExt.includes(ext)) {
                this.dispatchEvent(
                    new ShowToastEvent({ title: 'Invalid File Type', message: `${file.name} is not a supported file type.`, variant: 'error', mode: 'dismissable' })
                );
                return;
            }
            if (file.size > this.MAX_FILE_SIZE_BYTES) {
                this.dispatchEvent(
                    new ShowToastEvent({ title: 'File Too Large', message: `${file.name} exceeds the 5 MB size limit.`, variant: 'error', mode: 'dismissable' })
                );
                return;
            }
            const reader = new FileReader();
            reader.onload = () => {
                const base64Data = reader.result.split(',')[1];
                this.stagedFiles = [...this.stagedFiles, { fileName: file.name, base64Data }];
                this.fileValidationError = false;
            };
            reader.readAsDataURL(file);
        });
        event.target.value = null;
    }

    handleRemoveStagedFile(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.stagedFiles = this.stagedFiles.filter((_, i) => i !== index);
    }

    get stagedFileCount() {
        return this.stagedFiles.length;
    }

    get isFileUploadMissing() {
        return this.fileUploadMandatory && this.stagedFileCount === 0;
    }

    get uploadFileButtonClass() {
        return this.fileValidationError
            ? 'slds-button slds-button_outline-brand upload-file-btn upload-file-btn--missing'
            : 'slds-button slds-button_outline-brand upload-file-btn';
    }

    get uploadButtonLabel() {
        return this.stagedFileCount > 0 ? `File(s) Selected (${this.stagedFileCount})` : 'Upload File';
    }

    handleNavigate() {
        this.handleRefresh();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.system_var_1.sampleHeaderRecordId,
                objectApiName: 'Sample_Request_Header__c',
                actionName: 'view'
            }
        });
    }

    get acceptedFormats() {
        return ['.pdf', '.png', '.xlsx', '.csv', '.jpg', '.jpeg'];
    }

    get mainModalClass() {
        return this.isProductPromptOpen || this.isFileUploadOpen || this.showLimitWarningModal
            ? 'slds-modal slds-fade-in-open slds-modal_medium blur-modal'
            : 'slds-modal slds-fade-in-open slds-modal_medium ';
    }


    get selectedProductData() {
        if (
            this.selectedRowKey !== undefined &&
            this.showSampleList[this.selectedRowKey] &&
            this.showSampleList[this.selectedRowKey].productList
        ) {
            return this.showSampleList[this.selectedRowKey].productList;
        }
        return [];
    }

    get selectedRows() {
        if (
            this.selectedRowKey !== undefined &&
            this.showSampleList[this.selectedRowKey] &&
            this.showSampleList[this.selectedRowKey].productList &&
            this.showSampleList[this.selectedRowKey].productList.length > 0
        ) {
            if (this.showSampleList[this.selectedRowKey].selectedProductByRow.length === 0) {
                this.showSampleList[this.selectedRowKey].selectedProductByRow = this.showSampleList[this.selectedRowKey].productList[0];
            }
            this.selectedrow = [this.showSampleList[this.selectedRowKey].selectedProductByRow.Id];
            return this.selectedrow;
        }
        return [];
    }

    async handleChange(event) {

        const curId = event.currentTarget.dataset.id;
        const curName = event.currentTarget.dataset.field;
        const value = event.currentTarget.value;
        const label = event.currentTarget.dataset.label;
        let result = [];
        let keys = [];
        if (curName != 'commercialQuantity') this.showSampleList[curId][curName] = event.currentTarget.value;
        if (curName == 'commercialQuantity') {
            const previousValue = this.showSampleList[curId].commercialQuantity;
            if (this.showSampleList[curId].isBilateralChecked && parseInt(event.currentTarget.value) > 1 || !this.showSampleList[curId].isBilateralChecked) {
                console.log('OUTPUT 1: ', event.currentTarget.value);
                console.log('OUTPUT 2: ', this.showSampleList[curId][curName]);
                console.log('OUTPUT 3: ', this.showSampleList[curId][curName] !== parseInt(event.currentTarget.value));
                if (this.showSampleList[curId][curName] !== parseInt(event.currentTarget.value)) {
                    this.showSampleList[curId][curName] = parseInt(event.currentTarget.value);
                }
                else {
                    this.showSampleList[curId].commercialQuantity = null;
                    this.showSampleList = [...this.showSampleList];

                    setTimeout(() => {
                        this.showSampleList[curId].commercialQuantity = previousValue;
                        this.showSampleList = [...this.showSampleList];
                    }, 0);
                }
                if (this.showSampleList[curId].hasBackUp) this.showSampleList[curId].disableBilateral = false;
                if (parseInt(event.currentTarget.value) < 2) this.showSampleList[curId].disableBilateral = true;
                this.totalQuantity = this.totalQuantity + this.showSampleList[curId][curName] - previousValue;
                console.log('OUTPUT this.totalQuantity: ', this.totalQuantity, this.showSampleList[curId][curName], previousValue);
            }
            else {

                //this.showSampleList = [...this.showSampleList];
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Invalid Quantity For Bilateral Lens',
                        message: 'Quantity Must be greater than or equal to 2 when having bilateral backup lens.',
                        variant: 'Warning',
                        mode: 'dismissable'
                    })
                );

                this.showSampleList[curId].commercialQuantity = null;
                this.showSampleList = [...this.showSampleList];

                setTimeout(() => {
                    this.showSampleList[curId].commercialQuantity = previousValue;
                    this.showSampleList = [...this.showSampleList];
                }, 0);

                return;
            }
        }
        if (curName != 'commercialQuantity') {
            if (value) {
                if (curName != 'diaptor') {
                    result = await this.fetchList(label, this.showSampleList[curId].brand, this.showSampleList[curId].productModel, this.showSampleList[curId].sphericalPower, this.showSampleList[curId].cylinderPower, this.showSampleList[curId].axis);
                    keys = Object.keys(result);

                    const map = {
                        productModel: ['productModellist', 'disableproductModelShow', 'Group_Name__c'],
                        cylinderPower: ['cylindricalPowerlist', 'disablecylindricalPowerShow', 'Cylinder_Power_Formula__c'],
                        axis: ['axisAngleList', 'disableaxisAngleShow', 'Axis_Formula__c'],
                        diaptor: ['diaptorList', 'disablediaptorShow', 'Diaptor_Formula__c']
                    };
                    const key = keys[0];
                    if (key != 'NoValue') {
                        this.showSampleList[curId][map[key][0]] = result[key].map(item => ({
                            label: item[map[key][2]],
                            value: key == 'productModel' ? item['Id'] : item[map[key][2]]
                        }));
                        if (key == 'productModel') {
                            result[key].forEach(item => {
                                this.backupLensEnabled.set(item.Id, item.Backup_Lens__c);
                            });
                        }
                        this.showSampleList[curId][map[key][1]] = false;
                    }

                    if (this.showSampleList[curId].brand != '' && this.showSampleList[curId].parentRow == -1 && (this.showSampleList[curId].productModel != '' || this.showSampleList[curId].cylinderPower != '' || this.showSampleList[curId].axis != '' || this.showSampleList[curId].diaptor != '')) this.showSampleList[curId].disablecommercialQuantityshow = false;
                    else {
                        this.showSampleList[curId].disablecommercialQuantityshow = true;
                        this.showSampleList[curId].commercialQuantity = 1
                    }

                }
                if (keys.length === 0 || keys[0] === 'NoValue') {
                    console.log('OUTPUT : ',this.showSampleList[curId].brand, this.showSampleList[curId].productModel, this.showSampleList[curId].sphericalPower, this.showSampleList[curId].cylinderPower, this.showSampleList[curId].axis, this.showSampleList[curId].diaptor);
                    this.showSampleList[curId].productList = JSON.parse(JSON.stringify(await this.fetchProduct(this.showSampleList[curId].brand, this.showSampleList[curId].productModel, this.showSampleList[curId].sphericalPower, this.showSampleList[curId].cylinderPower, this.showSampleList[curId].axis, this.showSampleList[curId].diaptor)));
                    console.log('OUTPUT this.showSampleList[curId].productList: ', JSON.stringify(this.showSampleList[curId].productList));
                    if (this.showSampleList[curId].productList.length > 0) this.showSampleList[curId].showProduct = true;
                    this.showSampleList[curId].selectedProductByRow = this.showSampleList[curId].productList[0];
                    if (this.backupLensEnabled.get(this.showSampleList[curId].productModel) && this.showSampleList[curId].parentRow == -1) this.showSampleList[curId].disableBackupCheckBox = false;
                }
            }
            else {
                const map = {
                    brand: ['productModel', 'disableproductModelShow', 'sphericalPower', 'disablesphericalPowerShow', 'cylinderPower', 'disablecylindricalPowerShow', 'axis', 'disableaxisAngleShow', 'diaptor', 'disablediaptorShow'],
                    productModel: ['cylinderPower', 'disablecylindricalPowerShow', 'axis', 'disableaxisAngleShow', 'diaptor', 'disablediaptorShow'],
                    cylinderPower: ['axis', 'disableaxisAngleShow', 'diaptor', 'disablediaptorShow'],
                    axis: ['diaptor', 'disablediaptorShow'],
                    diaptor: [],
                };
                const removeList = map[curName];
                for (let i = 0; i < removeList.length; i += 2) {
                    this.showSampleList[curId][removeList[i]] = '';
                    this.showSampleList[curId][removeList[i + 1]] = true;
                }
                this.showSampleList[curId].disableBackupCheckBox = true;
                this.showSampleList[curId].selectedProductByRow = null;
                this.showSampleList[curId].showProduct = false;
                this.showSampleList[curId].productList.length = 0;
                if (this.showSampleList[curId].brand != '' && this.showSampleList[curId].parentRow == -1 && (this.showSampleList[curId].productModel != '' || this.showSampleList[curId].sphericalPower != '' || this.showSampleList[curId].cylinderPower != '' || this.showSampleList[curId].axis != '' || this.showSampleList[curId].diaptor != '')) this.showSampleList[curId].disablecommercialQuantityshow = false;
                else {
                    this.showSampleList[curId].disablecommercialQuantityshow = true;
                    this.showSampleList[curId].commercialQuantity = 1
                }
            }
        }
    }

    async fetchList(toFetch, brand, productModel, sphericalPower, cylinderPower, axis) {
        try {
            console.log('OUTPUT :fetchDropdown ', this.userCountry, this.userVertical, this.userLanguage, toFetch, brand, productModel, sphericalPower, cylinderPower, axis);
            if (toFetch != 'productModel') return await fetchDropdown({ toFetch, brand, productModel, sphericalPower, cylinderPower, axis, country: this.userCountry, vertical: this.userVertical, language: this.userLanguage });
            else return await fetchProductModel({ brand })
        } catch (error) {
            console.error("Error fetching list:", error);
            return [];
        }
    }

    async fetchProduct(brand, productModel, sphericalPower, cylinderPower, axis, diaptor) {
        try {
            return await fetchProduct({ brand, productModel, sphericalPower, cylinderPower, axis, diaptor, country: this.userCountry, vertical: this.userVertical, language: this.userLanguage });

        } catch (error) {
            console.error("Error fetching product:", error);
            return [];
        }
    }

    handleBilateralChange(event) {
        const curId = event.target.dataset.id;
        const isChecked = event.target.checked;
        this.showSampleList[curId].isBilateralChecked = isChecked;
        this.showSampleList = this.showSampleList.map(row => {
            if (row.parentRow == curId) {
                return {
                    ...row,
                    commercialQuantity: isChecked ? 2 : 1
                };
            }
            return row;
        });
    }

    handleBackUp(event) {
        const curId = event.currentTarget.dataset.id;
        const row = this.showSampleList[curId];
        const isActivating = !row.hasBackUp; // toggle

        if (isActivating) {
            let tempRow = JSON.parse(JSON.stringify(row));
            tempRow.disableBrand = true;
            tempRow.disableproductModelShow = true;
            tempRow.disablecylindricalPowerShow = true;
            tempRow.disableaxisAngleShow = true;
            this.showSampleList[curId].disableBrand = true;
            this.showSampleList[curId].disableproductModelShow = true;
            this.showSampleList[curId].hasBackUp = true;
            this.showSampleList[curId].disablecylindricalPowerShow = true;
            this.showSampleList[curId].disableaxisAngleShow = true;
            if (this.showSampleList[curId].commercialQuantity > 1) this.showSampleList[curId].disableBilateral = false;
            this.showSampleList[curId].backupBtnLabel = '✕ Remove Backup';
            this.showSampleList[curId].backupBtnClass = 'backup-btn backup-btn--active';
            tempRow.commercialQuantity = 1;
            tempRow.disablecommercialQuantityshow = true;
            tempRow.key = this.showSampleList.length;
            tempRow.parentRow = parseInt(curId);
            tempRow.parentRowDisplay = parseInt(curId) + 1; // 1-based display
            tempRow.isBackupRow = true;
            tempRow.disableBackupCheckBox = true;
            tempRow.backupBtnLabel = '+ Add Backup';
            tempRow.backupBtnClass = 'backup-btn';
            this.showSampleList.push(tempRow);

        } else {
            this.showSampleList[curId].disableBrand = false;
            this.showSampleList[curId].disableproductModelShow = false;
            if (this.showSampleList[curId].cylindricalPowerlist.length > 0) this.showSampleList[curId].disablecylindricalPowerShow = false;
            if (this.showSampleList[curId].axisAngleList.length > 0) this.showSampleList[curId].disableaxisAngleShow = false;
            this.showSampleList[curId].hasBackUp = false;
            this.showSampleList[curId].isBilateralChecked = false;
            this.showSampleList[curId].disableBilateral = true;
            this.showSampleList[curId].backupBtnLabel = '+ Add Backup';
            this.showSampleList[curId].backupBtnClass = 'backup-btn';
            const keyRemapOldToNew = {};
            this.showSampleList = this.showSampleList
                .filter(item => item.parentRow != curId)
                .map((row, index) => {
                    keyRemapOldToNew[row.key] = index;  // store oldKey → newKey before reassigning
                    return { ...row, key: index };
                });
            this.showSampleList = [...this.showSampleList];

            console.log('OUTPUT 1 : ', this.showSampleList);
            console.log('OUTPUT 1 : ', keyRemapOldToNew);
            this.showSampleList = this.showSampleList.map(row => {
                if (!row.parentRow == -1) return row;
                const newParentIndex = keyRemapOldToNew[row.parentRow];
                return {
                    ...row,
                    parentRow: newParentIndex ?? row.parentRow,
                    parentRowDisplay: newParentIndex !== undefined ? newParentIndex + 1 : row.parentRowDisplay
                };
            });
        }
    }


    handleSave(event) {
        this.isSaving = true;
        const label = event.target.dataset.label;
        this.pendingSaveLabel = label; // store for use after confirmation
        if (this.system_var_1.vertical == 'ORTHOPAEDICS') {
            console.log('OUTPUT : in ortho');
            isOverLimit().then(result => {
                this.isSaving = false;
                console.log('OUTPUT : result', result);
                console.log('OUTPUT : result[\'ORTHOPAEDICS\']', result['ORTHOPAEDICS']);
                console.log('OUTPUT : this.totalQuantity', this.totalQuantity);
                this.monthLimit = result['LIMIT'];
                console.log('OUTPUT : in ortho', result['ORTHOPAEDICS'], this.totalQuantity);
                if ((result['ORTHOPAEDICS'] - this.totalQuantity) < 0) {
                    this.showLimitWarningModal = true;
                } else {
                    console.log('OUTPUT : ', result, this.totalQuantity);
                    this._proceedWithSave(label);
                }
            })
                .catch(error => {
                    this.isSaving = false;
                    console.error('Error calling isOverLimit', error);
                });
        }
        else {
            this._proceedWithSave(label);
        }
    }

    handleLimitWarningYes() {
        this.showLimitWarningModal = false;
        this._proceedWithSave(this.pendingSaveLabel);
    }

    handleLimitWarningNo() {
        this.showLimitWarningModal = false;
    }

    _proceedWithSave(label) {
        this.isSaving = true;
        console.log('label : ', label);
        console.log('this.system_var_1.Bill_To_Code__c : ', this.system_var_1.header.Bill_To_Code__c);
        console.log(label === 'saveAndUploadFile');
        const lineItemList = [];

        if (this.isFileUploadMissing) {
            this.isSaving = false;
            this.fileValidationError = true;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please upload at least one file before submitting.',
                    variant: 'error',
                    mode: 'dismissable'
                })
            );
            return;
        }

        if (this.system_var_1.header.Bill_To_Code__c == null) {
            this.isSaving = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'SAP Code is missing on the Account. Please add an SAP Code before creating a Sample Request.',
                    variant: 'error',
                    mode: 'dismissable'
                })

            );
            return;
        }

        if (this.system_var_1.header.Remarks__c == null) {
            this.isSaving = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Remark cannot be empty.',
                    variant: 'error',
                    mode: 'dismissable'
                })
            );
            return;
        }

        const invalidRow = this.showSampleList.find(
            row => !row.selectedProductByRow || row.selectedProductByRow.length === 0
        );

        if (invalidRow) {
            this.isSaving = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please select a valid product in row ' + (invalidRow.key + 1) + '.',
                    variant: 'error',
                    mode: 'dismissable'
                })
            );
            return;
        }
        this.isSaving = true;
        if (this.system_var_1.accountId) {
            this.system_var_1.header.Bill_To_Address__c = [
                this.listOfAccount.get(this.system_var_1.accountId)?.BillingAddress?.street,
                this.listOfAccount.get(this.system_var_1.accountId)?.BillingAddress?.city,
                this.listOfAccount.get(this.system_var_1.accountId)?.BillingAddress?.state,
                this.listOfAccount.get(this.system_var_1.accountId)?.BillingAddress?.postalCode,
                this.listOfAccount.get(this.system_var_1.accountId)?.BillingAddress?.country
            ].filter(v => v).join(', ');
        }
        if (this.selectShipToAddress) {
            this.system_var_1.header.Ship_To_Code__c = this.listOfAccount.get(this.selectShipToAddress)?.SAP_Code__c;
            if (this.system_var_1.header.Ship_To_Code__c === null) {
                this.isSaving = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Validation Error',
                        message: 'SAP Code is missing on the Account. Please add an SAP Code before creating a Sample Request.',
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
                return;
            }
            this.system_var_1.header.Ship_To_Address__c = [
                this.listOfAccount.get(this.selectShipToAddress)?.BillingAddress?.street,
                this.listOfAccount.get(this.selectShipToAddress)?.BillingAddress?.city,
                this.listOfAccount.get(this.selectShipToAddress)?.BillingAddress?.state,
                this.listOfAccount.get(this.selectShipToAddress)?.BillingAddress?.postalCode,
                this.listOfAccount.get(this.selectShipToAddress)?.BillingAddress?.country
            ].filter(v => v).join(', ');
        }
        this.showSampleList.forEach(row => {
            lineItemList.push({
                productId: row.selectedProductByRow.Id,
                productGroup: row.selectedProductByRow.Product_Group__c,
                quantity: row.commercialQuantity,
                dummyProductDescription: row.selectedProductByRow.Dummy_Product_Description__c,
                groupName: row.selectedProductByRow.Group_Name__c,
                sphericalPower: row.selectedProductByRow.Spherical_Power__c,
                cylinderPower: row.selectedProductByRow.CylinderPower__c,
                axis: row.selectedProductByRow.Axis__c,
                diaptor: row.selectedProductByRow.Diaptor__c,
                country: row.selectedProductByRow.Country__c,
                division: row.selectedProductByRow.Division__c,
                productCodeSapCode: row.selectedProductByRow.Product_Code__c,
                dummyProductCode: row.selectedProductByRow.Dummy_Product_Code__c,
                hydrophilicSize: row.selectedProductByRow.Hydrophilic_Size__c,
                businessVertical: row.selectedProductByRow.Vertical__c,
                category: row.selectedProductByRow.Category__c,
                subCategory: row.selectedProductByRow.Sub_Category__c,
                brand: row.selectedProductByRow.Brand__c,
                backUp: row.parentRow != -1,
                account: this.system_var_1.accountId
            });
        });
        console.log('OUTPUT : ', JSON.stringify(lineItemList), ' ', JSON.stringify(this.system_var_1.header));
        insertSampleRequest({ lineItems: JSON.stringify(lineItemList), headerDetails: JSON.stringify(this.system_var_1.header) })
            .then((result) => {

                this.isSaving = false;

                if (result.status == 'warning') {
                    const evt = new ShowToastEvent({ title: 'Configuration Required', message: result.warning, variant: 'warning', mode: 'dismissable' });
                    this.dispatchEvent(evt);
                } else if (result.status == 'Error') {
                    const evt = new ShowToastEvent({ title: 'Error Occured', message: result.error, variant: 'error', mode: 'dismissable' });
                    this.dispatchEvent(evt);
                } else if (result.status == 'Success') {
                    const evt = new ShowToastEvent({ title: 'Success', message: 'Record Saved Successfully', variant: 'success', mode: 'dismissable' });
                    this.dispatchEvent(evt);
                    this.system_var_1.sampleHeaderRecordId = result.recordId;
                    if (this.stagedFiles.length > 0) {
                        uploadFiles({ recordId: result.recordId, filesJson: JSON.stringify(this.stagedFiles) })
                            .then(() => {
                                this.handleNavigate();
                            })
                            .catch(error => {
                                console.error('Error uploading files', error);
                                this.dispatchEvent(
                                    new ShowToastEvent({
                                        title: 'File Upload Error',
                                        message: 'Record was saved, but attaching the file(s) failed. Please attach them from the record page.',
                                        variant: 'warning',
                                        mode: 'sticky'
                                    })
                                );
                                this.handleNavigate();
                            });
                    } else {
                        this.handleNavigate();
                    }
                }
            })
            .catch((error) => {
                this.isSaving = false;
                console.error('error on insertSampleRequest', error.message);
            })
    }
}