import { LightningElement, track, wire } from 'lwc';

// importing Apex Class
import getAccounts from '@salesforce/apex/CustomerLedgerViewController.getAccounts';
// import getSearchAccounts from '@salesforce/apex/CustomerLedgerViewController.getSearchAccounts';
import getSearchAccountsWithText from '@salesforce/apex/CustomerLedgerViewController.getSearchAccountsWithText';
import getBase64String from '@salesforce/apex/CustomerLedgerViewController.getBase64String';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class CustomerLedgerView extends NavigationMixin(LightningElement) {

    @track data = [];
    @track error;
    @track bShowModal = false;
    @track selectedCons;
    @track toDate;
    @track fromDate;
    @track searchInput = '';
    // @track categoryOptionVal = 'None';
    @track categoryOption;
    @track showLoader = false;
    @track offset = 0;
    @track pageSize = 50;
    totalRecords = 0;
    //@track loadAgain = true;
    currentPage = 0;
    // opening the modal
    openModal() { this.bShowModal = true; }
    // closeing the modal
    closeModal() { this.bShowModal = false; }

    // Getting Contacts using Wire Service
    // @wire(retriveCons)
    // contacts(result) {
    //     if (result.data) {
    //         this.data = result.data;
    //         this.error = undefined;

    //     } else if (result.error) {
    //         this.error = result.error;
    //         this.data = undefined;
    //     }
    // }
    connectedCallback() {
        this.categoryOption = [{ label: 'None', value: 'None' },
        { label: 'Normal', value: 'Normal' },
        { label: 'Equipment', value: 'Equipment' }];
        this.getAccountData();
    }

    handleScroll(event) {

        console.log('BG >>> 1');

        const container = event.target;
        console.log('BG >>> container.scrollTop : ', container.scrollTop);
        console.log('BG >>> container.clientHeight : ', container.clientHeight);
        console.log('BG >>> container.scrollHeight : ', container.scrollHeight);
        const buffer = Math.max(50, Math.min(200, container.scrollHeight * 0.1));
        //if (container.scrollHeight - container.scrollTop <= container.clientHeight) {
        if (container.scrollTop >= (container.scrollHeight - container.clientHeight) * 0.9 && (this.offset < this.totalRecords)) {
            this.getAccountData();
        }
    }
    getAccountData() {

        this.currentPage++;
        getAccounts({ pageSize: this.pageSize, offset: this.offset, page: this.currentPage, searchTerm: this.searchInput })
            .then((result) => {
                if (result && result.accountList.length > 0) {
                    let resultArray = result.accountList;
                    this.totalRecords = result.totalRecords;
                    // const indexData = resultArray.map((record, index) => {
                    //   return {...record,index: index+1};
                    // });
                    // console.log('--indexData--'+JSON.stringify(indexData));
                    this.data = [...this.data, ...resultArray];
                    this.data = this.data.map((record, index) => {
                        return { ...record, index: index + 1 };
                    });
                    console.log('--this.data--' + JSON.stringify(this.data));
                    this.offset = this.offset + this.pageSize;
                    console.log('this.offset : ', this.offset);

                }

                this.showLoader = false;
            })
            .catch((error) => {
                this.error = error;
                this.showLoader = false;
            });
    }
    // Select the all rows
    allSelected(event) {
        let selectedRows = this.template.querySelectorAll('lightning-input');

        for (let i = 0; i < selectedRows.length; i++) {
            if (selectedRows[i].type === 'checkbox') {
                selectedRows[i].checked = event.target.checked;
            }
        }
    }



    showCustomer() {
        // Reset selected customers
        this.selectedCons = [];

        // Get all checkbox lightning-input elements
        const selectedRows = this.template.querySelectorAll('lightning-input');

        // Loop through checkboxes and build selectedCons
        for (let i = 0; i < selectedRows.length; i++) {
            const checkbox = selectedRows[i];
            if (checkbox.checked && checkbox.type === 'checkbox') {
                this.selectedCons.push({
                    Name: checkbox.value,
                    Id: checkbox.dataset.id,
                    Category: checkbox.dataset.pickval || (checkbox.dataset.pickval !== this.categoryOption[0].value ? checkbox.dataset.pickval : ''),
                    fromDate: this.fromDate,
                    toDate: this.toDate,
                    sapcode: checkbox.dataset.sapcode,
                    companycode: checkbox.dataset.companycode,
                });
            }
        }

        // Validate data selection
        if (this.selectedCons.length === 0) {
            this.showToast('Info', 'Please select at least one customer', 'error');
            return;
        }

        if (this.toDate == null || this.fromDate == null) {
            this.bShowModal = false;
            this.showToast('Error', 'Please select From date and To date.', 'error');
            return;
        }

        if (this.toDate < this.fromDate) {
            this.bShowModal = false;
            this.showToast('Error', 'To date should be greater than From date.', 'error');
            return;
        }

        // Validate date range
        const toDate = new Date(this.toDate);
        const fromDate = new Date(this.fromDate);
        if (this.isDateRangeMoreThanOneYear(fromDate, toDate) && this.selectedCons.length > 1) {
            this.bShowModal = false;
            this.showToast('Error', 'Selected Date range more than a year. Please select only one account.', 'error');
            console.log('Selected Date range more than a year. Please select only one account.');
            return;
        }

        // Proceed with PDF generation if dates are valid
        this.bShowModal = true;
        console.log('Date range does not span more than one year');
        console.log('Selected customers:', JSON.stringify(this.selectedCons));

        getBase64String({ selectedData: this.selectedCons })
            .then(customerDataList => {
                customerDataList.forEach(customerData => {
                    if (customerData.Status === 1) {
                        console.log('Got response:', customerData.PDFData);
                        try {
                            this.convertBase64ToPDF(customerData.PDFData);
                            // const closeAuraEvent = new CustomEvent('closemodal');
                            // this.dispatchEvent(closeAuraEvent);
                        } catch (error) {
                            console.error(error);
                        }
                    } else {
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Error!',
                            message: customerData.message,
                            variant: 'error',
                        }));
                    }
                });
            })
            .catch(error => {
                console.error('Error in callout:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error!',
                    message: 'An error occurred while generating the PDF.',
                    variant: 'error',
                }));
            });
    }



    convertBase64ToPDF(base64String) {
        try {
            const binaryString = atob(base64String);
            const uint8Array = new Uint8Array(binaryString.length);
            for (let i = 0; i < binaryString.length; i++) {
                uint8Array[i] = binaryString.charCodeAt(i);
            }
            const blob = new Blob([uint8Array], { type: "application/pdf" });
            const urlPDF = URL.createObjectURL(blob);
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: urlPDF
                }
            })


            // // Generate URL for a Lightning page to display the PDF
            // this[NavigationMixin.GenerateUrl]({
            //     type: 'standard__namedPage',
            //     attributes: {
            //         pageName: 'filePreview'
            //     },
            //     state: {
            //         contentId: 'file-sfdc',
            //         recordIds: this.recordId,
            //         version: '1.0',
            //         title: 'Invoice PDF'
            //     }
            // }).then(url => {
            //     // Redirect to the Lightning page to display the PDF
            //     window.location.href = `${url}?isdtp=p1&sfdcIFrameHost=web`;
            // });
        } catch (error) {
            console.error(error);
            // this.isLoading = false;
            throw new Error('Error converting base64 to PDF');
        }
    }
    handleChange(event) {
        let custId = event.target.dataset.key;
        console.log('--custId--' + custId);
        let selectedOption = event.detail.value;
        this.data = this.data.map(account => {
            if (account.Id === custId) {
                return { ...account, categoryOptionVal: selectedOption };
            }
            return account;
        });
    }
    handleClick() {

    }
    serachToDateFunc(event) {
        this.toDate = event.target.value;
        console.log('-todate--' + this.toDate);
    }
    serachFromDateFunc(event) {
        this.fromDate = event.target.value;
        console.log('-fromDate--' + this.fromDate);
    }
    // handleClick(){
    //     if(this.fromDate != null  && this.toDate != null){
    //         getSearchAccounts({ fromDate: this.fromDate, toDate: this.toDate })
    //         .then(result => {
    //             let resultArray=result;
    //             this.data = resultArray.map((record, index) => {
    //                 return {...record,index: index+1};
    //             });
    //         })
    //         .catch(error => {
    //            console.log('==error--',error);
    //         });
    //     }else{
    //         this.getAccountData();
    //     }

    // }

    isDateRangeMoreThanOneYear(startDate, endDate) {
        // const startYear = startDate.getFullYear();
        // const endYear = endDate.getFullYear();

        // return endYear - startYear > 0;
        const daysDifference = (endDate - startDate) / (1000 * 60 * 60 * 24);
        return daysDifference > 365;
        // return (endYear - startYear > 0) || (daysDifference > 365);
    }
    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }
    handleSearch() {
        console.log('function');
        if (this.searchInput != '') {
            console.log('test' + this.searchInput);
            getSearchAccountsWithText({ searchTerm: this.searchInput })
                .then(result => {
                    console.log(result);
                    if (result && result.length > 0) {
                        let resultArray = result;
                        // const indexData = resultArray.map((record, index) => {
                        //   return {...record,index: index+1};
                        // });
                        // console.log('--indexData--'+JSON.stringify(indexData));
                        this.data = [];
                        this.data = [...this.data, ...resultArray];
                        this.data = this.data.map((record, index) => {
                            return { ...record, index: index + 1 };
                        });
                        console.log('--this.data--' + JSON.stringify(this.data));
                    } else {
                        console.log(result);
                    }
                    this.showLoader = false;
                })
                .catch(error => {
                    console.log('==error--', error);
                });
        } else {
            console.log('--dd--' + this.data);
            this.data = [];
            this.offset = 0;
            this.pageSize = 10;
            this.currentPage = 0;
            this.getAccountData();
            console.log('--dd1--' + this.data);
        }

    }
    searchText(event) {
        this.searchInput = '';
        this.searchInput = event.target.value;
        console.log('==thissearch==', this.searchInput);

    }

    handleKeyPress(event) {
        if (event.keyCode === 13) {
            this.handleSearch();
        }
    }

}