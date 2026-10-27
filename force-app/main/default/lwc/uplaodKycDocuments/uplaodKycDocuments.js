import { LightningElement, wire, api, track } from 'lwc';
import getKycData from '@salesforce/apex/UplaodKycDocumentsController.getRecords';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadFile from '@salesforce/apex/UplaodKycDocumentsController.uploadFile';
import updateLeadData from '@salesforce/apex/UplaodKycDocumentsController.updateLeadData';
import saveLeadAndPdf from '@salesforce/apex/UplaodKycDocumentsController.saveLeadAndPdf';
import getcustomercreationmodule from '@salesforce/apex/CommonutiltiyClass.getCustomLabelscustomercreation';

import FIELD_RSM from '@salesforce/schema/Lead__c.RSM_Comments__c';
import FIELD_ZSM from '@salesforce/schema/Lead__c.ZSM_Comments__c';
import FIELD_GM from '@salesforce/schema/Lead__c.GM_NSM_Comments__c';
import FIELD_Admin from '@salesforce/schema/Lead__c.Admin_Comments__c';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";

const fields = [
    FIELD_RSM,
    FIELD_ZSM,
    FIELD_GM,
    FIELD_Admin
];


export default class UplaodKycDocuments extends LightningElement {
    @api recordId;
    @api fileTableData = [];
    @track leadRecord = [];
    @track reqMap = {};
    fileData = {};
    @track docList = true;
    @track fileMap = {};
    @track uploaddesable = false;
    records;
    error;
    @track tempList = [];
    @track leadDataMap = {};
    @track errorMessages = {};
    @track dataMap = {};

    @track spinner = true;
    @track isButtonVisible = false;
    @track isSalesDistrictDisabled = false;
    @track salesDistrictOptions = [];
    @track salesOfficeOptions = [];
    @track getcustomermodulelabel = {};
    @track salesOffice = '';
    @track salesDistrict = '';
    @track plantList = [];
    @track plant = '';
    @track apprComment = false;
    @track DCRdetail = false;


    @wire(getRecord, { recordId: "$recordId", fields })

    connectedCallback() {
        console.log('this.recordid', this.recordId);
    }
    wiredData({ error, data }) {
        console.log('Data ==============> ', data);
        if (data) {
            this.dataMap['RSM'] = data.fields.RSM_Comments__c.value;
            this.dataMap['ZSM'] = data.fields.ZSM_Comments__c.value;
            this.dataMap['GM'] = data.fields.GM_NSM_Comments__c.value;
            this.dataMap['Admin'] = data.fields.Admin_Comments__c.value;

        } else if (error) {
            console.error('Error:', error);
        }
    }

    @wire(getcustomercreationmodule)
    getloginlogout(result) {
        if (result.data) {
            this.getcustomermodulelabel = result.data;
            console.log('Translation getloginlogoutlabel', this.getcustomermodulelabel);
            if (this.getcustomermodulelabel != undefined) {

            }
        }
        if (result.error) {
            console.log('error', result.error);
        }
    }

    @wire(getKycData, { recordId: '$recordId' })
    wiredRecords({ error, data }) {
        console.log('AbhinavData', data);
        if (data) {
            console.log('data:--->', data);
            if (!data.Initaiate) {
                this.docList = false;
                this.DCRdetail = true;
                this.spinner = false;
                return;
            }
            if (!data.AccountExist) {
                this.salesDistrictOptions = [];
                this.salesOfficeOptions = [];
                this.salesOffice = '';
                this.salesDistrict = '';
                this.plantList = [];
                this.plant = '';
                this.apprComment = false;
                let resultArray = data.KycData;
                console.log('resultArray--->', resultArray);
                if (resultArray == undefined || resultArray == '') {
                    this.docList = false;
                }
                console.log('docList--->', this.docList);
                this.records = resultArray.map((record, index) => {
                    return { ...record, index: index + 1 };
                });
                if (data.SalesOfficerList != undefined) {
                    this.salesOfficeOptions = data.SalesOfficerList;
                    this.salesOffice = data.SalesOfficer;
                }
                if (data.SalesDistrictList != undefined) {
                    this.salesDistrictOptions = data.SalesDistrictList;
                    this.salesDistrict = data.SalesDistrict;
                }
                if (data.PlantCodeList != undefined) {
                    this.plantList = data.PlantCodeList;
                    this.plant = data.plant;
                }
                if (data.ApprovalData) {
                    this.apprComment = true;
                }
                console.log('Data-->', this.records);
                this.error = undefined;
                this.spinner = false;
            } else {
                this.showToast(this.getcustomermodulelabel.Error__c, this.getcustomermodulelabel.In_system_there_is_already_a_account_wit__c, this.getcustomermodulelabel.Error__c);
                this.handleCancel();
            }


        } else if (error) {
            this.error = error;
            this.records = undefined;
            this.spinner = false;
        }

    }

    handleCancel(event) {
        var url = window.location.href;
        var value = url.substr(0, url.lastIndexOf('/') + 1);
        window.history.back();
        return false;
    }

    handleReload() {
        this.showToast(this.getcustomermodulelabel.Please_Wait__c, this.getcustomermodulelabel.Your_files_are_being_uploaded_Do_not_cl__c, this.getcustomermodulelabel.info__c);
        setTimeout(() => {
            location.reload();
        }, 4000);
    }

    showToast(title, msg, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: msg,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    validateFileData() {
        var temp = true;
        var msg = '';
        this.records.forEach(currentItem => {
            if (currentItem.IsRequired == true) {
                if (this.reqMap[currentItem.Id] == undefined) {
                    temp = false;
                    msg += '\n Document ' + currentItem.MasterLabel + this.getcustomermodulelabel.Missing_Kindly_Upload__c;
                }
            }
        });

        if (msg != '') {
            this.showToast('Required', msg, 'warning');
        }

        return temp;
    }

    openfileUpload(event) {
        const file = event.target.files[0];
        const recordId = event.target.dataset.recordId;
        console.log('recordId-->', recordId);

        //const allowedFileTypes = ['image/jpg', 'image/png', 'application/pdf'];

        // Check if the file type is allowed
        /* if (!allowedFileTypes.includes(file.type)) {
             this.showToast('Error', 'Invalid file type. Please upload JPG, PNG, or PDF file.', 'error');
             return;
         }*/
        // Check if the file size exceeds 5 MB (5 * 1024 * 1024 bytes)
        const MAX_FILE_SIZE = 5 * 1024 * 1024;
        if (file.size > MAX_FILE_SIZE) {
            this.showToast(this.getcustomermodulelabel.Error__c, this.getcustomermodulelabel.File_size_exceeds_5_MB_Please_upload_a__c, this.getcustomermodulelabel.Error__c);
            return;
        }
        this.tempList.push(recordId);

        // Use lastIndexOf to split the filename at the last period
        const lastDotIndex = file.name.lastIndexOf('.');
        const baseFileName = file.name.substring(0, lastDotIndex);
        const fileExtension = file.name.substring(lastDotIndex + 1);

        var tempfileName = event.currentTarget.dataset.filename + '.' + fileExtension;
        var reader = new FileReader();
        reader.onload = () => {
            var base64 = reader.result.split(',')[1];
            this.fileData = {
                ...this.fileData,
                [recordId]: {
                    'filename': tempfileName,
                    'base64': base64,
                    'recordId': this.recordId

                }
            };
            this.reqMap[recordId] = tempfileName;
            const recordRow = this.template.querySelector(`tr[data-id="${recordId}"]`);
            if (recordRow) {
                const filenameElement = recordRow.querySelector('.filename');
                if (filenameElement) {
                    filenameElement.textContent = file.name;
                }
            }
        };
        reader.readAsDataURL(file);
    }

    handleClick() {
        console.log('Test data');

        // Find all the input fields in the form
        const allValid = [...this.template.querySelectorAll('lightning-input-field')]
            .reduce((validSoFar, inputField) => {
                return validSoFar && inputField.reportValidity();
            }, true);

        const allValidComboBox = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((validSoFar, inputCmp) => {
                inputCmp.reportValidity();
                return validSoFar && inputCmp.checkValidity();
            }, true);

        if (allValid && allValidComboBox) {
            this.uploaddesable = true;
            var temDataList = [];
            console.log('Tem length', this.tempList.length);
            console.log('heyyyy--256');
            console.log('validation fun:', this.validateFileData());
            console.log('leadDataMap :-258', this.leadDataMap);

            if (this.tempList.length == 0 && this.leadDataMap != null && this.leadDataMap != undefined && this.validateFileData() == true) {
                saveLeadAndPdf({ recordId: this.recordId, lea: this.leadDataMap }).then(result => {
                    console.log('PDF saved successfully--262');
                    this.showToast(this.getcustomermodulelabel.Lead_Information__c, this.getcustomermodulelabel.Lead_Information__c.Saved_successfully_Lead_Information__c, this.getcustomermodulelabel.Success__c);
                    setTimeout(() => {
                        location.reload();
                    }, 2000);
                }).catch(error => {
                    console.log('Error saving PDF--268', error);
                    this.uploaddesable = false;
                    this.showToast(this.getcustomermodulelabel.Error__c, this.getcustomermodulelabel.Lead_Information__c.Please_fill_in_all_required_fields__c, this.getcustomermodulelabel.Error__c);
                });
                console.log('Data received--Line 270');
            }
            if (this.validateFileData()) {
                this.uploaddesable = true;
                console.log('FIle data', this.fileData);
                const uploadPromises = Object.keys(this.fileData).map(recordId => {
                    const { base64, filename } = this.fileData[recordId];

                    return uploadFile({ base64, filename, recordId: this.recordId, fileMap: this.fileMap }).then(result => {
                        let title = `${filename} ` + ' ' + this.getcustomermodulelabel.uploaded_successfully__c;
                        this.showToast(title, this.getcustomermodulelabel.Filebase64_uploaded__c, this.getcustomermodulelabel.Success__c);
                        temDataList.push(filename);
                        console.log('Temdata length--284', temDataList.length);
                       this.handleReload();
                        if (this.tempList.length == temDataList.length) {
                            // Call the saveLeadAndPdf method herez
                            console.log('heyyyy--286');
                            saveLeadAndPdf({ recordId: this.recordId, lea: this.leadDataMap }).then(result => {
                                console.log('PDF saved successfully---290');
                            }).catch(error => {
                                console.log('Error saving PDF', error);
                                this.showToast(this.getcustomermodulelabel.Error_saving_PDF__c, error.body.message, this.getcustomermodulelabel.Error__c);
                            });
                            console.log('Data received--295');
                            updateLeadData({ recordId: this.recordId }).then(result => {
                                console.log('PDF saved successfully--297');
                            }).catch(error => {
                                console.log('Error saving PDF', error);
                                this.showToast(this.getcustomermodulelabel.Error_saving_PDF__c, error.body.message, this.getcustomermodulelabel.Error__c);
                            });
                            console.log('Data received--302');
                        }
                        return result;
                    }).catch(error => {
                        this.uploaddesable = false;
                        this.showToast(this.getcustomermodulelabel.Error_uploading_file__c, error.body.message, this.getcustomermodulelabel.Error__c);
                        throw error;
                    });
                });

                Promise.all(uploadPromises).then(() => {
                    this.fileData = {};
                    this.handleCancel();
                });
                console.log('line number :315 ');
            }
        } else {
            this.uploaddesable = false;
            this.showToast(this.getcustomermodulelabel.Error__c, this.getcustomermodulelabel.Please_fill_in_all_required_fields__c, this.getcustomermodulelabel.Error__c);
        }
    }


    handleChange(event) {
        const name = event.target.name;
        let value = event.target.value;
       
        // Validation for 30 characters limit
        if (value.length > 30) {
            this.errorMessages[name] = "Only 30 characters allowed.";
        } else {
            this.errorMessages[name] = "";
        }

        this.leadDataMap['Id'] = this.recordId;
       

        // Store valid input only
        if (value.length <= 30) {
            this.leadDataMap[name] = value;
        }
        console.log('leadDataMap--->',JSON.stringify(this.leadDataMap));

        // 🔁 Check if all required document numbers are filled
        const anyMissing = this.records.some(record => {
            if (record.IsRequired) {
                const key = record.MasterLabel.replace(/ /g, '_');
                return !this.fileMap[key]; // empty or undefined
            }
            return false;
        });

        this.isButtonVisible = !anyMissing; // Show button only if nothing is missing

        //this.isButtonVisible = false;
    }

    handleDocumentNumberChange(event) {
        let fileName = event.target.dataset.filename;
        const value = event.target.value;

        if (fileName) {
            fileName = fileName.replace(/ /g, '_'); // replace all spaces with underscores
        }

        if (!this.fileMap) {
            this.fileMap = {};
        }

        this.fileMap[fileName] = value ? value.trim() : '';

        console.log('✅ Cleaned fileName:', fileName);
        console.log('📄 Document value:', value);
        console.log('📦 fileMap:', this.fileMap);

        // 🔁 Check if all required document numbers are filled
        const anyMissing = this.records.some(record => {
            if (record.IsRequired) {
                const key = record.MasterLabel.replace(/ /g, '_');
                return !this.fileMap[key]; // empty or undefined
            }
            return false;
        });

        this.isButtonVisible = !anyMissing; // Show button only if nothing is missing

        console.log('👁️ isButtonVisible:', this.isButtonVisible);
    }


}