import { LightningElement, track, wire, api } from 'lwc';
import modal from "@salesforce/resourceUrl/modal";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from "lightning/platformResourceLoader";
import { CloseActionScreenEvent } from 'lightning/actions';

import LightningConfirm from 'lightning/confirm';
import getInitialData from "@salesforce/apex/SchemeInformationController.getInitialData";
import createSchemeRequestAndLineItems from "@salesforce/apex/SchemeInformationController.createSchemeRequestAndLineItems";
import getAccountWithChildren from '@salesforce/apex/SchemeInformationController.getAccountWithChildren';
import checkschemedata from '@salesforce/apex/SchemeInformationController.checkschemedata';

export default class SchemeInformationComponent extends NavigationMixin(LightningElement) {

    columns = [
        { label: 'Account Name', fieldName: 'Name', type: 'text' },
        { label: 'Scheme Number', fieldName: 'Scheme_number__c', type: 'text' },
        {
            label: 'Start Date',
            fieldName: 'Start_Date__c',
            type: 'custom',
            cellAttributes: { class: 'slds-p-around_x-small' }
        },
        {
            label: 'End Date',
            fieldName: 'End_Date__c',
            type: 'customDisabled',
            cellAttributes: { class: 'slds-p-around_x-small' }
        },
        {
            type: 'button-icon',
            fixedWidth: 50,
            typeAttributes: {
                iconName: 'utility:delete',
                name: 'delete',
                title: 'Delete',
                variant: 'border-filled',
                alternativeText: 'Delete'
            }
        }
    ];

    @track showConfirm = false;
    @track message = '';

    @track isLoading = false;


    @track backmonthnumber = 0;
    @api recordId;
    @track sapChildList = [];
    @track havechildonSAP = false;
    @track sapresponse = false;
    @track screenTwo = true;
    @track disable = true; // disabling button
    @track havechildaccounts = false;
    @track showdefaultdata = false;
    @track pagefilteredSchemesData = false;
    @track schemeavailable = false;

    @track parentaccountscheme = false;
    @track childaccountscheme = false;
    //@track currentPage = 1;
    //@track rowsPerPage = 5;
    // @track totalPages = 1;

    @track filteredSchemesData = [];
    @track enablesubmit = true;
    @track selAccountList = [];
    @track seletedaccountdata = [];
    @track alreadyschemeavailable;
    @track displayedData = []; // Data to be displayed on the current page

    @track rsm = '';
    @track zsm = '';
    @track admin = '';


    fromDate;
    toDate;
    @track searchInput = '';
    @track validateApprover = '';
    @track schemeData = {};
    @track selectedSchemeId = null;

    @track dataIsAvailable = true;
    @track country = '';
    @track schemeLineItem = []; // showing Line Item Data on UI
    @track newTabledata = []; // showing data on UI
    @track selectedSchemeIds = []; // final Data storing
    @track rawtabledata = [];

    //--Scheme Screen
    @track schemecurrentPage = 1;
    @track schemepageSize = 100;
    @track schemerowsPerPage = 5;

    @track accounts = [];
    @track paginatedAccounts = [];
    @track selectedRecords = new Set();
    isAllSelected = false;
    @track handlethirsscreen = false;
    @track enablesecondnext = true;
    @track schemenumberonly = '';
    @track schemennameonly = '';
    @track currentrecordparent = false;
    @track childRecordList = [];
    @track parentAccountList = [];


    @track childschemelist = [];
    @track parentschemelist = [];
    // columns = COLUMNS;

    get showCreditPercentageColumn() {
        return this.schemeLineItem?.some(
            item =>
                item.Credit_Percentage__c !== null &&
                item.Credit_Percentage__c !== undefined &&
                item.Credit_Percentage__c !== ''
        );
    }


    connectedCallback() {
        console.log('LWC recordId => ', this.recordId);
        this.startLoader();
        loadStyle(this, modal);
        if (this.recordId != undefined) {
            const defaultStartDate = this.getAllowedStartDate();
            this.parentAccountList = this.parentAccountList.map(row => ({
                ...row,
                Start_Date__c: defaultStartDate,
                End_Date__c: this.calculateEndDate(defaultStartDate)
            }));

            //this.enablesubmit = false;

        }




    }

    startLoader() {
        this.isLoading = true;
    }

    stopLoader() {
        this.isLoading = false;
    }

    @wire(getAccountWithChildren, { accountId: '$recordId', selectedSchemeNumber: '$schemenumberonly' })
    wiredAccounts({ data, error }) {
        if (data) {
            // Extract parent and child accounts from the returned map
            console.log('data-->124 : ', JSON.stringify(data));
            console.log('data.BundleCustomer : ', data.BundleCustomer);
            if (Array.isArray(data.BundleCustomer) && data.BundleCustomer[0] === 'X') {

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Warning',
                        message: 'Scheme generation is not allowed for bundle customers.',
                        variant: 'warning',
                        mode: 'dismissible'   // 🔥 only this toast sticky
                    })
                );

                // modal close
                //this.onCancel();

                setTimeout(() => {
                    this.onCancel();
                }, 0.5);

                return;
            } else {

                this.showdefaultdata = true;
            }


            this.childschemelist = data.schemelistforchild || [];
            if (this.childschemelist.length > 0) {
                this.childaccountscheme = true;

            }
            this.parentschemelist = data.schemelistforparent || [];
            if (this.parentschemelist.length > 0) {
                this.parentaccountscheme = true;
            }
            this.parentAccountList = data.parentAccountlist || [];
            this.childRecordList = data.childrecordlist || [];

            console.log('this.childRecordList---->', JSON.stringify(this.childRecordList));


            // Combine both lists
            this.accounts = [...this.parentAccountList, ...this.childRecordList].map((acc, index) => ({
                ...acc,
                rowIndex: index + 1,
                isSelected: false,
            }));

            // Find the account that matches the current recordId
            let currentAccount = this.parentAccountList.find(acc => acc.Id === this.recordId) ||
                this.childRecordList.find(acc => acc.Id === this.recordId);

            // Assign to selected account list
            this.seletedaccountdata = this.childRecordList.find(acc => acc.Id === this.recordId);

            // Check if currentAccount exists and its ParentId is null
            this.currentrecordparent = currentAccount && !currentAccount.ParentId;
            console.log('Current', this.currentrecordparent)


            // this.paginatedAccounts = [...this.childRecordList];
            this.paginatedAccounts = this.childRecordList.map(rec => {
                return {
                    ...rec,
                    parentSapCode: rec.Parent ? rec.Parent.SAP_Code__c : '',
                    parentName: rec.Parent ? rec.Parent.Name : ''
                };
            });


        } else if (error) {
            console.log('Error fetching accounts:', error);
            this.stopLoader();

        }
    }


    @wire(getInitialData, { schemeId: '$recordId' })
    wiredData({ error, data }) {

        if (data) {
            // this.startLoader();
            console.log('Data--->', JSON.stringify(data));
            //console.log('Data.sap', data.sap);
            // this.alreadyschemeavailable = data.sampleRequestList;
            //console.log('this.alreadyschemeavailable',this.alreadyschemeavailable);
            // if(this.alreadyschemeavailable !=undefined){
            //  this.schemeavailable = true;
            //  this.showdefaultdata = false;
            // //this.showToastMessage('Warning', `There is already an ongoing scheme with the Scheme No ${this.alreadyschemeavailable.Scheme_Number__c} from ${this.alreadyschemeavailable.Start_Date__c} to ${this.alreadyschemeavailable.Valid_Upto__c}, so you cannot generate another scheme. Thanks!`, 'warning', 'dismissible', 5000);
            // setTimeout(() => {
            //            // this.closeQuickAction();
            //         }, 5000);
            //         //return;
            // }

            try {
                this.rawtabledata = data;

                // Clone scheme data safely
                this.newTabledata = data?.schemeData
                    ? JSON.parse(JSON.stringify(data.schemeData))
                    : [];

                // SAP Child Customers (Table data)
                this.sapChildList = data?.sapChildCustomers
                    ? JSON.parse(JSON.stringify(data.sapChildCustomers))
                    : [];

                console.log('Freshdata', this.newTabledata);
                console.log('backmonthenumber', this.rawtabledata.backmonthenumber);
                this.backmonthnumber = this.rawtabledata.backmonthenumber;
                console.log('Scheme Data => ', this.newTabledata);
                console.log('SAP Child List => ', this.sapChildList);
                this.havechildonSAP = this.sapChildList.length > 0;


                this.filteredSchemesData = [...this.newTabledata]; // Initialize filteredSchemesData
                //this.schemetotalPages = Math.ceil(this.filteredSchemesData.length / this.schemerowsPerPage);
                this.updateDisplayedData();
                this.country = JSON.parse(JSON.stringify(this.rawtabledata.country));
                console.log('Data this.country', this.country);

                if (this.country == 'Not available') {
                    this.dataIsAvailable = false;
                    this.validateApprover = 'Please fill country value';
                    setTimeout(() => {
                        this.onCancel();
                    }, 4000);
                    return;
                }
                const dataLength = this.newTabledata.length;
                // this.admin = JSON.parse(JSON.stringify(this.rawtabledata.admin));
                // this.rsm = JSON.parse(JSON.stringify(this.rawtabledata.rsm));
                //this.zsm = JSON.parse(JSON.stringify(this.rawtabledata.zsm));

                /*  if (this.admin == 'NA' || this.rsm == 'NA' || this.zsm == 'NA') {
                      this.dataIsAvailable = false;
                      this.validateApprover = 'Please Check RSM, ZSM, Admin Values, make sure it should not be empty.';
                      setTimeout(() => {
                          this.closeQuickAction();
                      }, 4000);
                      return;
                  }*/

                console.log('OUTPUT : dataLength', dataLength);

                if (dataLength == 0) {
                    this.dataIsAvailable = false;
                    this.validateApprover = 'There is no ongoing scheme available on the' + ' ' + this.country;
                    setTimeout(() => {
                        this.onCancel();
                    }, 4000);
                    return;
                } else {
                    this.stopLoader();
                    console.log('OUTPUT : Processed Table Data Size', this.filteredSchemesData.length);
                    this.pagefilteredSchemesData = this.filteredSchemesData.length > 0;
                }



            } catch (err) {
                console.log('Error processing data:', err);
                this.stopLoader();

            }
        } else if (error) {
            console.log('Error:', error);
            this.stopLoader();
        }
    }

    handleClickscheme(event) {
        const selectedId = event.currentTarget.dataset.id;

        this.schemeLineItem = [];
        this.schemenumberonly = '';

        this.newTabledata.forEach(currentItem => {
            if (selectedId == currentItem.Id) {
                this.schemeLineItem = currentItem.Scheme_Line_Items__r;
                this.schemenumberonly = currentItem.Scheme_Number__c;
            }
        });

        console.log('schemeLineItem : ', JSON.stringify(this.schemeLineItem));
        this.screenTwo = false;
        this.screenOne = true;
    }
    onItemSelect(event) {
        const schemeInfoId = event.target.dataset.id;
        const checked = event.target.checked;

        if (!checked) {
            return;
        }

        // 🔁 Scheme change detect
        if (this.selectedSchemeId && this.selectedSchemeId !== schemeInfoId) {
            // ❌ Clear all dates
            this.clearAllDates();

            this.enablesubmit = true;
        }

        // ✅ Set selected scheme
        this.selectedSchemeId = schemeInfoId;

        this.craeteSelectedSchemeRequest(schemeInfoId, true);
        this.updateRadioSelection();
    }

    clearAllDates() {
        this.parentAccountList = this.parentAccountList.map(row => ({
            ...row,
            Start_Date__c: '',
            End_Date__c: ''
        }));
    }



    updateRadioSelection() {
        this.displayedData = this.displayedData.map(item => {
            return {
                ...item,
                isSelected: item.Id === this.selectedSchemeId
            };
        });
    }




    // handleClick(event) {
    //     this.newTabledata.forEach(currentItem => {
    //         if (event.currentTarget.dataset.id == currentItem.Id) {
    //             this.schemeLineItem = currentItem.Scheme_Line_Items__r;
    //         }
    //     });
    //     console.log('OUTPUT : valueId', event.currentTarget.dataset.id);
    //     this.screenOne = true;
    //     this.screenTwo = false;
    // }

    handlePrevClick() {
        this.screenOne = false;
        this.screenTwo = true;
    }

    craeteSelectedSchemeRequest(schemesInfoId, isSelected) {
        this.selectedSchemeIds = [];
        if (isSelected) {
            const account = this.newTabledata.find(acc => acc.Id == schemesInfoId);
            if (account && !this.selectedSchemeIds.includes(account)) {
                this.selectedSchemeIds.push(account);
                this.schemenumberonly = account.Scheme_Number__c;
                this.schemennameonly = account.Scheme_Desc__c;

            }
        } else {
            this.selectedSchemeIds = this.selectedSchemeIds.filter(acc => acc.Id !== schemesInfoId);
        }
        this.disable = this.selectedSchemeIds.length <= 0;
        console.log('OUTPUT : size', this.selectedSchemeIds.length);
        console.log('OUTPUT : selectedSchemes', JSON.stringify(this.selectedSchemeIds));
    }

    /**************************** On Submit Request *******************************************************/

    createCustomRrquestRecords(event) {

        if (this.selectedSchemeIds.length === 0) {
            this.showToastMessage('No items selected', 'Please select at least one scheme.', 'warning');
            return;
        }
        this.enablesubmit = true;


        createSchemeRequestAndLineItems({ jsonObj: JSON.stringify(this.selectedSchemeIds), accountdata: this.parentAccountList, accIds: this.selAccountList })
            .then(result => {
                console.log('Custom records created successfully', result);
                if (result == 'success') {
                    this.showToastMessage('Success..!', 'Your request was submitted successfully.', 'success');
                    setTimeout(() => {
                        location.reload();
                    }, 2000);
                    this.onCancel();
                } else {
                    this.enablesubmit = false;
                    this.showToastMessage('Fail..!', 'Your request was not submitted.', 'error');
                    //this.onCancel();
                }

            })
            .catch(error => {
                this.enablesubmit = false;
                console.error('Error creating custom records', error);
            });
    }

    /**************************** On Submit Request *******************************************************/

    showToastMessage(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissible'
        });
        this.dispatchEvent(event);
    }
    /**************************** On Cancel *******************************************************/
    onCancel() {
        console.log('Cancel clicked');

        // close quick action properly
        this.dispatchEvent(new CloseActionScreenEvent());

        // optional custom event (if aura wrapper also listening)
        this.dispatchEvent(
            new CustomEvent('close', {
                bubbles: true,
                composed: true
            })
        );
    }
    //     closeQuickAction() {
    //     // ✅ Fire custom event to Aura
    //     this.dispatchEvent(new CustomEvent("close"));
    //     console.log('Close : ');
    // }



    /**************************** Common Action  *******************************************************/
    getAllowedStartDate() {
        const today = new Date();

        // backmonthnumber months back
        today.setMonth(today.getMonth() - this.backmonthnumber);

        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');

        return `${year}-${month}-01`; // yyyy-mm-01
    }


    handleDateChange(event) {
        const rowId = event.target.dataset.rowId;
        const fieldName = event.target.dataset.field;
        const value = event.target.value;

        console.log('value----> : ', value);

        if (!value) {
            this.clearDates(rowId);
            this.enablesubmit = true;
            return;
        }

        if (fieldName === 'Start_Date__c' && value) {

            const selectedDate = new Date(value);
            const day = value.split('-')[2];

            // Only 1st day allowed
            if (day !== '01') {
                event.target.setCustomValidity('Only the 1st day of any month is allowed as the Start Date.');
                event.target.reportValidity();
                this.clearDates(rowId);
                this.enablesubmit = true;
                return;
            }

            const minDate = new Date();
            minDate.setMonth(minDate.getMonth() - this.backmonthnumber);
            minDate.setDate(1);

            if (selectedDate < minDate) {
                event.target.setCustomValidity(
                    `Start Date can be selected only within the last ${this.backmonthnumber} months from current month.`
                );
                event.target.reportValidity();
                this.clearDates(rowId);
                this.enablesubmit = true;
                return;
            }

            event.target.setCustomValidity('');
            event.target.reportValidity();
        }

        // Apex validation
        checkschemedata({
            accountdata: [{ Id: rowId, Start_Date__c: value }],
            accIds: this.selAccountList,
            schemenumber: this.schemenumberonly
        })
            .then(result => {

                console.log('OUTPUT : ', JSON.stringify(result));

                if (result.status === 'error') {

                    this.showToastMessage('Warning', result.message, 'warning');
                    this.clearDates(rowId);
                    this.enablesubmit = true;

                }
                else if (result.status === 'warning') {

                    // store temporary values
                    this.pendingRowId = rowId;
                    this.pendingFieldName = fieldName;
                    this.pendingValue = value;

                    // open custom modal
                    this.openConfirm(result.message);

                }
                else {

                    this.parentAccountList = this.parentAccountList.map(row =>
                        row.Id === rowId
                            ? {
                                ...row,
                                [fieldName]: value,
                                End_Date__c: this.calculateEndDate(value)
                            }
                            : row
                    );

                    this.enablesubmit = false;
                }
            })
            .catch(error => {
                console.error(error);
            });
    }

    openConfirm(msg) {
        this.message = msg;
        this.showConfirm = true;
    }

    handleOk() {

        const rowId = this.pendingRowId;
        const fieldName = this.pendingFieldName;
        const value = this.pendingValue;

        this.parentAccountList = this.parentAccountList.map(row =>
            row.Id === rowId
                ? {
                    ...row,
                    [fieldName]: value,
                    End_Date__c: this.calculateEndDate(value)
                }
                : row
        );

        this.enablesubmit = false;
        this.showConfirm = false;
    }

    handleCancel() {

        const rowId = this.pendingRowId;

        // clear data
        this.clearDates(rowId);

        // clear UI input
        const input = this.template.querySelector(`[data-row-id="${rowId}"]`);
        if (input) {
            input.value = '';
        }

        this.enablesubmit = true;
        this.showConfirm = false;
    }


    clearDates(rowId) {
        this.parentAccountList = this.parentAccountList.map(row =>
            row.Id === rowId
                ? { ...row, Start_Date__c: '', End_Date__c: '' }
                : row
        );
    }



    calculateEndDate(startDate) {
        if (!startDate) return ''; // Handle empty input

        try {
            let date = new Date(startDate);
            if (isNaN(date.getTime())) throw new Error("Invalid Date"); // Ensure valid date
            date.setDate(date.getDate() + 364);
            console.log(date);
            return date.toISOString().split('T')[0]; // Format YYYY-MM-DD
        } catch (error) {
            console.error("Error calculating End Date:", error);
            return '';
        }
    }
    // //----------------------------------Check Scheme data--------------------------
    // fetchSchemeData(recordId, startDate) {
    //     checkschemedata({ 
    //         accountdata: [{ Id: recordId, Start_Date__c: startDate }], 
    //         accIds: [recordId] 
    //     })
    //     .then(result => {
    //         if (result.status === 'error') {
    //             this.showToastMessage('error', result.message, 'error');
    //         } else {
    //             console.log('Scheme Data:', result.message);
    //         }
    //     })
    //     .catch(error => {
    //         console.error('Error fetching scheme data:', error);
    //     });
    // }


    /***************************************** Pagination ***************************************/

    updateDisplayedData() {
        const start = (this.schemecurrentPage - 1) * this.schemerowsPerPage;
        const end = start + this.schemerowsPerPage;

        this.displayedData = this.filteredSchemesData.slice(start, end);
        this.updateRadioSelection();
    }


    handlePageChange(event) {
        this.schemecurrentPage = event.detail;
        this.updateDisplayedData();
    }

    /***************************************** Pagination ****************************************/
    schemehandlePreviousPage() {
        if (this.schemecurrentPage > 1) {
            this.schemecurrentPage--;
            this.updateDisplayedData();
        }
    }

    schemehandleNextPage() {
        if (this.schemecurrentPage < this.schemetotalPages) {
            this.schemecurrentPage++;
            this.updateDisplayedData();
        }
    }


    get schemeisFirstPage() {
        return this.schemecurrentPage === 1;
    }

    get schemeisLastPage() {
        return this.schemecurrentPage === this.schemetotalPages;
    }


    get schemetotalPages() {
        return this.filteredSchemesData.length
            ? Math.ceil(this.filteredSchemesData.length / this.schemerowsPerPage)
            : 0;
    }




    /***************************************** Pagination ***************************************/

    handlenextsecondscreen() {
        this.startLoader();
        if (this.currentrecordparent) {
            this.havechildaccounts = true;
            this.showdefaultdata = false;
            this.handlethirsscreen = false;
            if (this.childRecordList.length === 0) {
                if (this.currentrecordparent) {
                    // this.showToastMessage('No Child Customer', 'This Customer has no child Customer.', 'warning');
                    this.showToastMessage('No Child Customer', 'This Customer has no child Customer.', 'warning');
                    setTimeout(() => {
                        this.stopLoader();   // ya next action
                    }, 500);
                    this.havechildaccounts = false;
                    this.handlethirsscreen = true;
                }

            }
        } else {
            this.havechildaccounts = false;
            this.showdefaultdata = false;
            this.handlethirsscreen = true;


        }
        setTimeout(() => {
            this.stopLoader();
        }, 500); // 1000 ms = 1 second



    }
    previousfirstscreen() {
        this.disable = false;
        this.havechildaccounts = false;
        this.showdefaultdata = true;
        this.handlethirsscreen = false;

    }
    nextthirdscreen() {
        this.handlethirsscreen = true;
        this.havechildaccounts = false;
        this.showdefaultdata = false;
    }
    previoussecondscreen() {
        this.disable = false;
        if (this.currentrecordparent) {
            this.handlethirsscreen = false;
            this.havechildaccounts = true;
            if (this.childRecordList.length === 0) {
                this.havechildaccounts = false;
                this.showdefaultdata = true;
            } else {
                this.showdefaultdata = false;
            }
            //this.showdefaultdata = false;
        } else {
            this.handlethirsscreen = false;
            this.havechildaccounts = false;
            this.showdefaultdata = true;

        }

    }


    // Handle row selection
    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedRecords = selectedRows;
        console.log('Selected Records:', JSON.stringify(this.selectedRecords));
    }

    /****************************************** Filters ******************************************/
    handleFromDateChange(event) {
        this.fromDate = event.target.value;
        this.applyFilter();
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
        this.applyFilter();
    }

    handleKeyUp(event) {
        this.searchInput = event.target.value;
        this.applyFilter();
    }

    // applyFilter() {
    //     let filtered = this.newTabledata;

    //     // Apply date range filter
    //     if (this.fromDate && this.toDate) {
    //         const from = new Date(this.fromDate);
    //         const to = new Date(this.toDate);
    //         filtered = filtered.filter(opp => {
    //             const closeDate = new Date(opp.Valid_Upto__c);
    //             return closeDate >= from && closeDate <= to;
    //         });
    //     }

    //     // Apply search filter
    //     if (this.searchInput) {
    //         filtered = filtered.filter(opp => {
    //             return opp.Name.toLowerCase().includes(this.searchInput.toLowerCase());
    //         });
    //     }

    //      if (this.searchInput) {
    //         filtered = filtered.filter(opp => {
    //             return opp.Scheme_Number__c.toLowerCase().includes(this.searchInput.toLowerCase());
    //         });
    //     }

    //     // Apply search filter
    //     if (this.searchInput && this.fromDate && this.toDate) {
    //         filtered = filtered.filter(opp => {
    //             return opp.Name.toLowerCase().includes(this.searchInput.toLowerCase());
    //         });
    //     }

    //     // Update filteredSchemesData and totalPages
    //     this.filteredSchemesData = filtered;
    //     //this.schemetotalPages = Math.ceil(this.filteredSchemesData.length / this.schemerowsPerPage);

    //     // Reset to the first page and update displayedData
    //     this.schemecurrentPage = 1;
    //     this.updateDisplayedData();

    //     console.log('OUTPUT : ', this.filteredSchemesData.length);
    //     console.log('OUTPUT : ', this.displayedData.length);
    //     if (this.displayedData.length > 0) {
    //         this.pagefilteredSchemesData = this.filteredSchemesData.length > 0;
    //     }


    // }

    applyFilter() {
        let filtered = [...this.newTabledata];

        const searchText = this.searchInput ? this.searchInput.toLowerCase() : '';

        filtered = filtered.filter(opp => {

            let matchSearch = true;
            let matchDate = true;

            // 🔍 Search filter (Name OR Scheme Number OR Description)
            if (searchText) {

                const name = opp.Name ? opp.Name.toLowerCase() : '';
                const schemeNo = opp.Scheme_Number__c ? opp.Scheme_Number__c.toLowerCase() : '';
                const desc = opp.Scheme_Desc__c ? opp.Scheme_Desc__c.toLowerCase() : '';

                matchSearch =
                    name.includes(searchText) ||
                    schemeNo.includes(searchText) ||
                    desc.includes(searchText);
            }

            // 📅 Date filter
            if (this.fromDate && this.toDate && opp.Valid_Upto__c) {

                const from = new Date(this.fromDate);
                const to = new Date(this.toDate);
                const validDate = new Date(opp.Valid_Upto__c);

                matchDate = validDate >= from && validDate <= to;
            }

            return matchSearch && matchDate;
        });

        this.filteredSchemesData = filtered;
        this.schemecurrentPage = 1;
        this.updateDisplayedData();

        this.pagefilteredSchemesData = this.filteredSchemesData.length > 0;
    }





    handleSelectAll(event) {
        this.isAllSelected = event.target.checked;

        // Update all accounts to reflect selection state
        this.paginatedAccounts = this.paginatedAccounts.map(acc => ({
            ...acc,
            isSelected: this.isAllSelected
        }));

        if (this.isAllSelected) {
            // Add all account IDs to the selectedRecords set
            this.selectedRecords = new Set(this.paginatedAccounts.map(acc => acc.Id));
            this.enablesecondnext = false;
        } else {
            // Clear the selectedRecords set
            this.selectedRecords.clear();
            this.enablesecondnext = true;
        }

        // Convert the set to an array and assign to selAccountList
        this.selAccountList = Array.from(this.selectedRecords);

        console.log('selectedRecords', this.selectedRecords);
    }


    // Handle single row selection
    handleClick(event) {
        const accountId = event.target.dataset.id;
        const isChecked = event.target.checked;

        this.paginatedAccounts = this.paginatedAccounts.map((acc) =>
            acc.Id === accountId ? { ...acc, isSelected: isChecked } : acc


        );

        if (isChecked) {
            this.selAccountList.push(accountId);
            this.selectedRecords.add(accountId);
            this.enablesecondnext = false;
        } else {
            // Remove from selAccountList
            const index = this.selAccountList.indexOf(accountId);
            if (index > -1) {
                this.selAccountList.splice(index, 1);
            }
            this.selectedRecords.delete(accountId);
            this.enablesecondnext = this.selectedRecords.size == 0;
        }

        // Check if all rows are selected
        this.isAllSelected = this.paginatedAccounts.every(acc => acc.isSelected);
        console.log('paginatedAccounts', this.selectedRecords);
    }

    closeFromAura() {
        this.dispatchEvent(
            new CustomEvent('close', {
                bubbles: true,
                composed: true
            })
        );
    }


    /****************************************** Filters ******************************************/
}