import { LightningElement, wire, track } from 'lwc';
import getSecondarySales from '@salesforce/apex/SecondarySaleslineController.getSecondarySales';
import approveSales from '@salesforce/apex/SecondarySaleslineController.approveSales';
import checkUserAccess from '@salesforce/apex/SecondarySalesDistStockController.checkUserAccess';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { CurrentPageReference } from 'lightning/navigation';
import Product_Name_Secondary_sales from '@salesforce/label/c.Product_Name_Secondary_sales';
import Units from '@salesforce/label/c.Units';
import Approve_To_Inward_Stock from '@salesforce/label/c.Approve_To_Inward_Stock';
import StatusSS from '@salesforce/label/c.StatusSS';
import Order_No from '@salesforce/label/c.Order_No';
import In_Transit_Stocks_SS from '@salesforce/label/c.In_Transit_Stocks_SS';

export default class SecondarySaleReview extends LightningElement {

    label = {
        Product_Name_Secondary_sales,Units,Approve_To_Inward_Stock,StatusSS,Date,Order_No,In_Transit_Stocks_SS
    };
     
    selectedRows = [];
    wiredResult;
   // selectedMonth;
    pageSize = 10;
    pageNumber = 1;
    totalRecords = 0;
    allRecords = [];
     records = [];
   // monthOptions = [];

    _recordId;
    @track hasReadAccess = false;
    @track hasEditAccess = false;
     
        columns = [
        { label: this.label.Product_Name_Secondary_sales, fieldName: 'product' },
        { label: this.label.Units, fieldName: 'units', type: 'number', cellAttributes: { alignment: 'center' }  },
        { label: this.label.StatusSS, fieldName: 'status', cellAttributes: { alignment: 'center', class: { fieldName: 'statusClass' } } },
        { label: 'Date', fieldName: 'date', type: 'date', cellAttributes: { alignment: 'center' }  }, // Datatable automatically handles locale formatting for type: 'date'
        { label: this.label.Order_No, fieldName: 'orderNo', cellAttributes: { alignment: 'center' } }
    ];

    @wire(CurrentPageReference)
    pageRef(ref) {
        if (ref?.attributes?.recordId) {
            this._recordId = ref.attributes.recordId;
            console.log('recordId from URL:', this._recordId);

            checkUserAccess({ recordId: this._recordId })
                .then(result => {
                    this.hasReadAccess = result.Read;
                    this.hasEditAccess = result.Edit;
                    console.log('Read Access:', this.hasReadAccess, 'Edit Access:', this.hasEditAccess);
                })
                .catch(error => {
                    console.error('Error:', error);
                });
        } else {
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

    get recordId() {
        return this._recordId;
    }


   @wire(getSecondarySales)
wiredSales(result){

    this.wiredResult = result;

    if(result.data){
        this.allRecords = result.data.map(row => ({
            id: row.Id,
            product: row.Product__r?.Name,
            units: row.Quantity__c,
            status: row.Type__c,
            date: row.Date__c,
            orderNo: row.Order_Number__c,
            approvedCreated: row.Approved_Record_Created__c,
            statusClass: row.Type__c === 'In Transit' ? 'status-blue' : ''
        }));

        this.totalRecords = this.allRecords.length;

        this.updateRecords();

    }
}
    handleRowSelection(event){

        const selected = event.detail.selectedRows;

        this.selectedRows = selected.map(row => row.id);
    }

    get disablePrevious() {
        return this.totalRecords === 0 || this.pageNumber === 1;
    }

    get disableNext() {
        return (
            this.totalRecords === 0 ||
            this.pageNumber >= this.totalPages
        );
    }

    handleApproveSales(){
        approveSales({ recordIds: this.selectedRows })
        .then(()=>{
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Records approved successfully.',
                    variant: 'success'
                })
            );
            this.selectedRows = [];
            this.pageNumber = 1;
            return refreshApex(this.wiredResult);
        })
        .catch(error=>{
            console.error(error);
        });
    }

    get isApproveDisabled() {
        return this.selectedRows.length === 0;
    }
   /* handleMonthChange(event){
        this.selectedMonth = event.detail.value;
    }*/
    updateRecords(){
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.records = this.allRecords.slice(start, end);
    }

    handleNext(){
        if(this.pageNumber * this.pageSize < this.totalRecords){
            this.pageNumber++;
            this.updateRecords();
        }
    }

handlePrevious(){
    if(this.pageNumber > 1){
        this.pageNumber--;
        this.updateRecords();
    }
}

get totalPages(){
    return Math.ceil(this.totalRecords / this.pageSize);
}

    get hideCheckboxColumn() {
        return !this.hasEditAccess;
    }

}