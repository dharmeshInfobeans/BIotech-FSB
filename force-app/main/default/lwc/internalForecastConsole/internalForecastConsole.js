import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchAccountDetails from '@salesforce/apex/InternalForecastConsoleController.fetchAccountDetails';
import getWeeklyForecastDetails from '@salesforce/apex/InternalForecastConsoleController.getWeeklyForecastDetails';
import savePortalForecastRecords from '@salesforce/apex/InternalForecastConsoleController.savePortalForecastRecords';

export default class InternalForecastConsole extends LightningElement {
    contactId;
    customerName = '';
    selectedCustomerCode = '';
    startYear = new Date().getFullYear() - 2;
    lastYear = new Date().getFullYear() + 2;

    @track fromselectedMonth = '';
    @track fromselectedYear = '';
    @track toselectedMonth = '';
    @track toselectedYear = '';

    @track monthOptions = [];
    @track yearOptions = [];
    @track products = [];
    @track monthHeaders = [];
    @track weekHeaders = [];

    isLoading = false;
    showTable = false;
    errorMessage = '';

    // Wire current page reference to retrieve the parameters from state
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            const stateContactId = currentPageReference.state.c__contactId;
            if (stateContactId && stateContactId !== this.contactId) {
                this.contactId = stateContactId;
                this.loadAccountInfo();
            }
        }
    }

    connectedCallback() {
        this.initializeMonthOptions();
    }

    initializeMonthOptions() {
        this.monthOptions = [
            { label: 'January', value: '1' },
            { label: 'February', value: '2' },
            { label: 'March', value: '3' },
            { label: 'April', value: '4' },
            { label: 'May', value: '5' },
            { label: 'June', value: '6' },
            { label: 'July', value: '7' },
            { label: 'August', value: '8' },
            { label: 'September', value: '9' },
            { label: 'October', value: '10' },
            { label: 'November', value: '11' },
            { label: 'December', value: '12' }
        ];
    }

    loadAccountInfo() {
        if (!this.contactId) {
            return;
        }

        this.isLoading = true;
        fetchAccountDetails({ contactId: this.contactId })
            .then(result => {
                for (const key in result) {
                    if (key === 'agreementEndYear') {
                        this.lastYear = parseInt(result[key], 10) || new Date().getFullYear();
                    } else if (key === 'agreementStartYear') {
                        this.startYear = parseInt(result[key], 10) || (new Date().getFullYear() - 2);
                    } else {
                        this.customerName = result[key];
                        this.selectedCustomerCode = key;
                    }
                }

                this.generateYearOptions();
                this.setDefaultDateFilters();
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to retrieve Account details: ' + (error.body ? error.body.message : error.message), 'error');
            });
    }

    generateYearOptions() {
        const years = [];
        const start = Math.min(this.startYear, new Date().getFullYear() - 5);
        const end = Math.max(this.lastYear, new Date().getFullYear() + 5);

        for (let yr = start; yr <= end; yr++) {
            years.push({ label: String(yr), value: String(yr) });
        }
        this.yearOptions = years;
    }

    setDefaultDateFilters() {
        const today = new Date();
        const currentMonthVal = String(today.getMonth() + 1);
        const currentYearVal = String(today.getFullYear());

        this.fromselectedMonth = currentMonthVal;
        this.fromselectedYear = currentYearVal;
        this.toselectedMonth = currentMonthVal;
        this.toselectedYear = currentYearVal;
    }

    handleFromMonthChange(event) {
        this.fromselectedMonth = event.detail.value;
    }

    handleFromYearChange(event) {
        this.fromselectedYear = event.detail.value;
    }

    handleToMonthChange(event) {
        this.toselectedMonth = event.detail.value;
    }

    handleToYearChange(event) {
        this.toselectedYear = event.detail.value;
    }

    handleGoClick() {
        const fromM = parseInt(this.fromselectedMonth, 10);
        const fromY = parseInt(this.fromselectedYear, 10);
        const toM = parseInt(this.toselectedMonth, 10);
        const toY = parseInt(this.toselectedYear, 10);

        const monthSpan = (toY - fromY) * 12 + (toM - fromM);

        if (monthSpan < 0) {
            this.errorMessage = 'FROM date must be before or equal to TO date.';
            this.showTable = false;
            return;
        }

        if (monthSpan > 5) {
            this.errorMessage = 'Date range must be 6 months or less.';
            this.showTable = false;
            return;
        }

        this.errorMessage = '';
        this.isLoading = true;

        getWeeklyForecastDetails({
            fromselectedYear: fromY,
            selectedCustomerCode: this.selectedCustomerCode,
            fromselectedMonth: fromM,
            page: 1,
            pageSize: 100, // Load all products for the console view
            toselectedYear: toY,
            toselectedMonth: toM
        })
        .then(result => {
            if (result && result.weeklyProductObj && result.weeklyProductObj.length > 0) {
                this.products = result.weeklyProductObj;
                this.buildTableHeaders();
                this.showTable = true;
            } else {
                this.products = [];
                this.showTable = false;
                this.showToast('No Records', 'No agreement products found for the selected range.', 'info');
            }
            this.isLoading = false;
        })
        .catch(error => {
            this.isLoading = false;
            this.showTable = false;
            this.showToast('Error', 'Failed to retrieve forecast details: ' + (error.body ? error.body.message : error.message), 'error');
        });
    }

    buildTableHeaders() {
        if (!this.products || this.products.length === 0) {
            return;
        }

        // Use the first product's month breakdown to construct the headers
        const firstProd = this.products[0];
        const mHeaders = [];
        const wHeaders = [];

        firstProd.lstMonthWiseWeeks.forEach((month, mIndex) => {
            // Number of weeks in this month + 1 for month total column
            const colspan = month.weeklyForecastObj.length + 1;
            mHeaders.push({
                key: month.monthYear,
                monthName: month.monthName,
                year: month.year,
                colspan: colspan
            });

            month.weeklyForecastObj.forEach((week) => {
                wHeaders.push({
                    key: week.uniqueKey,
                    label: `Week-${week.yearWeekCnt}`
                });
            });

            wHeaders.push({
                key: `${month.monthYear}-total`,
                label: `Total ${month.monthShortName}-${month.year}`
            });
        });

        this.monthHeaders = mHeaders;
        this.weekHeaders = wHeaders;
    }

    handleForecastQtyChange(event) {
        const prodIndex = parseInt(event.target.dataset.prodIndex, 10);
        const monthIndex = parseInt(event.target.dataset.monthIndex, 10);
        const weekIndex = parseInt(event.target.dataset.weekIndex, 10);
        const val = event.target.value;

        // Clone tracking properties to trigger reactivity updates
        const updatedProducts = JSON.parse(JSON.stringify(this.products));
        const week = updatedProducts[prodIndex].lstMonthWiseWeeks[monthIndex].weeklyForecastObj[weekIndex];
        
        week.forecastQty = val === '' ? '' : parseInt(val, 10);

        // Recalculate month total forecast quantity
        let total = 0;
        updatedProducts[prodIndex].lstMonthWiseWeeks[monthIndex].weeklyForecastObj.forEach((w) => {
            const qty = w.forecastQty === '' ? 0 : parseInt(w.forecastQty, 10);
            total += qty;
        });
        updatedProducts[prodIndex].lstMonthWiseWeeks[monthIndex].totalForecast = total;

        this.products = updatedProducts;
    }

    handleSaveClick() {
        // Clone products payload and normalize empty inputs to 0
        const payloadProducts = JSON.parse(JSON.stringify(this.products));
        payloadProducts.forEach((prod) => {
            prod.lstMonthWiseWeeks.forEach((month) => {
                month.weeklyForecastObj.forEach((week) => {
                    if (week.forecastQty === '' || week.forecastQty === null || week.forecastQty === undefined) {
                        week.forecastQty = 0;
                    }
                });
            });
        });

        const wrapper = {
            weeklyProductObj: payloadProducts
        };

        this.isLoading = true;
        savePortalForecastRecords({ forecastWeeklyWrapper: JSON.stringify(wrapper) })
            .then(() => {
                this.isLoading = false;
                this.showToast('Success', 'Forecast records saved successfully.', 'success');
                // Refresh data
                this.handleGoClick();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to save forecast records: ' + (error.body ? error.body.message : error.message), 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}