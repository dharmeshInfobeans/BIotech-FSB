import { LightningElement, track } from 'lwc';
import uploadRecords from '@salesforce/apex/GenericUploadController.uploadRecords';
import generateSampleCSV from '@salesforce/apex/GenericUploadController.generateSampleCSV';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class GenericUploadUtility extends LightningElement {

    @track selectedObject;
    @track selectedTemplate;
    csvBody;

    // objectOptions = [
    //     { label: 'Campaign Members', value: 'Campaign_Member__c' },
    //     { label: 'Campaign', value: 'Campaign__c' },
    //     { label: 'Lead', value: 'Lead__c' },
    //     { label: 'Target In-Clinic Template', value: 'Target__c' },
    //     { label: 'Target Marketing Template', value: 'Target__c' },
    //      { label: 'Sales Target Header', value: 'Sales_Target_Header__c' },
    //      { label: 'Sales Target Line', value: 'Sales_Target_Line__c' },
    //      { label: 'Role Assignment', value: 'Role_Assignment__c' }

    // ];

    objectOptions = [
        { label: 'Campaign Members', value: 'Campaign_Member__c|DEFAULT' },
        { label: 'Campaign', value: 'Campaign__c|DEFAULT' },
        { label: 'Lead', value: 'Lead__c|DEFAULT' },

        { label: 'Target In-Clinic Template', value: 'Target__c|INCLINIC' },

        { label: 'Target Marketing Template', value: 'Target__c|MARKETING' },

        { label: 'Sales Target Header', value: 'Sales_Target_Header__c|DEFAULT' },

        { label: 'Sales Target Line', value: 'Sales_Target_Line__c|DEFAULT' },

        { label: 'Role Assignment', value: 'Role_Assignment__c|DEFAULT' }
    ];

    get disableUpload() {
        return !this.selectedObject;
    }

    // handleObjectChange(event) {
    //     this.selectedObject = event.detail.value;
    // }

    handleObjectChange(event) {

        this.selectedValue = event.detail.value;

        const values = this.selectedValue.split('|');

        this.selectedObject = values[0];
        this.selectedTemplate = values[1];
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = () => {
            this.csvBody = reader.result;
        };
        reader.readAsText(file);
    }

    // handleUpload() {
    //     uploadRecords({
    //         objectApiName: this.selectedObject,
    //         csvBody: this.csvBody
    //     }).then(result => {
    //         this.downloadFile(result, 'Upload_Result.csv');
    //     });
    // }
    handleUpload() {
    uploadRecords({
        objectApiName: this.selectedObject,
        csvBody: this.csvBody
    }).then(result => {
        this.downloadFile(result, 'Upload_Result.csv');

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'File imported successfully',
                variant: 'success'
            })
        );
    }).catch(error => {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'An error occurred while importing the file',
                variant: 'error'
            })
        );
    });
}

    // downloadSample() {
    //     generateSampleCSV({ objectApiName: this.selectedObject })
    //         .then(csv => {
    //             this.downloadFile(csv, 'Sample_' + this.selectedObject + '.csv');
    //         });
    // }

    downloadSample() {
        generateSampleCSV({
            objectApiName: this.selectedObject,
            templateType: this.selectedTemplate
        })
            .then(csv => {
                this.downloadFile(csv, 'Sample_' + this.selectedObject + '.csv');
            });
    }

    downloadFile(content, filename) {
        const a = document.createElement('a');
        a.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(content);
        a.download = filename;
        document.body.appendChild(a);
        a.click();
    }
}