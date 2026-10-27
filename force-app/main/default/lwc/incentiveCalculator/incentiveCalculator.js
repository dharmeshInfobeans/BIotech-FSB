import { LightningElement, track, wire } from 'lwc';
import getIncentiveData from '@salesforce/apex/IncentiveCalculatorController.getIncentiveData';

const MONTHS = [
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

export default class IncentiveCalculator extends LightningElement {

    /* ---------------- FILTERS ---------------- */
    @track selectedMonth;
    @track selectedYear;

    /* ---------------- DATA ---------------- */
    @track tableData = [];
    @track error;

    /* ---------------- COLUMNS (ALL) ---------------- */
    columns = [
        { label: 'Employee Name', fieldName: 'employeeName' },

        { label: 'Sales Target', fieldName: 'salesTarget', type: 'number' },
        { label: 'Sales Achievement', fieldName: 'salesAchievement', type: 'number' },
        { label: 'Sales Achievement %', fieldName: 'salesPct', type: 'number' },
        { label: 'Sales Incentive %', fieldName: 'salesEligibility', type: 'number' },

        { label: 'Marketing Target', fieldName: 'marketingTarget', type: 'number' },
        { label: 'Marketing Achievement', fieldName: 'marketingAchievement', type: 'number' },
        { label: 'Marketing Achievement %', fieldName: 'marketingPct', type: 'number' },
        { label: 'Marketing Incentive %', fieldName: 'marketingEligibility', type: 'number' },

        { label: 'CTP Target', fieldName: 'ctpTarget', type: 'number' },
        { label: 'CTP Achievement', fieldName: 'ctpAchievement', type: 'number' },
        { label: 'CTP Achievement %', fieldName: 'ctpPct', type: 'number' },
        { label: 'CTP Incentive %', fieldName: 'ctpEligibility', type: 'number' },

        { label: 'Total Eligibility %', fieldName: 'totalEligibility', type: 'number' },
        { label: 'Monthly Salary', fieldName: 'monthlySalary', type: 'currency' },
        { label: 'Monthly Incentive Amount', fieldName: 'monthlyIncentiveAmount', type: 'currency' }
    ];

        handleRefresh() {
    window.location.reload();
        }
    /* ---------------- DEFAULTS ---------------- */
    connectedCallback() {
        const today = new Date();
        this.selectedMonth = (today.getMonth() + 1).toString();
        this.selectedYear = today.getFullYear().toString();
    }

    /* ---------------- YEAR OPTIONS ---------------- */
    get yearOptions() {
        const currentYear = new Date().getFullYear();
        const years = [];
        for (let y = currentYear - 1; y <= currentYear + 3; y++) {
            years.push({ label: y.toString(), value: y.toString() });
        }
        return years;
    }

    /* ---------------- MONTH OPTIONS (AUTO-DISABLE) ---------------- */
    get monthOptions() {
        const today = new Date();
        const currentYear = today.getFullYear();
        const currentMonth = today.getMonth() + 1;
        const selYear = parseInt(this.selectedYear, 10);

        return MONTHS.map(m => {
            let disabled = false;

            if (selYear > currentYear) {
                disabled = true; // future year
            } else if (selYear === currentYear && parseInt(m.value, 10) > currentMonth) {
                disabled = true; // future month in current year
            }

            return { ...m, disabled };
        });
    }

    /* ---------------- MONTH PICKLIST DISABLE FLAG ---------------- */
    get isMonthDisabled() {
        return this.monthOptions.length > 0 &&
               this.monthOptions.every(opt => opt.disabled);
    }

    /* ---------------- FILTER HANDLERS ---------------- */
    handleMonthChange(event) {
        this.selectedMonth = event.detail.value;
    }

    handleYearChange(event) {
        this.selectedYear = event.detail.value;

        const today = new Date();
        const currentYear = today.getFullYear();
        const currentMonth = today.getMonth() + 1;

        if (parseInt(this.selectedYear, 10) > currentYear) {
            this.selectedMonth = null;
        } else if (
            parseInt(this.selectedYear, 10) === currentYear &&
            parseInt(this.selectedMonth, 10) > currentMonth
        ) {
            this.selectedMonth = currentMonth.toString();
        }
    }

    /* ---------------- VALID FILTER CHECK ---------------- */
    get isFilterValid() {
        return this.selectedMonth && this.selectedYear;
    }

    /* ---------------- APEX WIRE ---------------- */
    @wire(getIncentiveData, {
        month: '$selectedMonth',
        year: '$selectedYear'
    })
    wiredIncentive({ data, error }) {
        if (data) {
            this.tableData = data;
            this.error = undefined;
            console.log()
        } else if (error) {
            this.error = error;
              console.log('error on getIncentiveData ',error?.message,'error',error)
            this.tableData = [];
        }
    }

    exportToExcel() {
    if (!this.tableData || this.tableData.length === 0) {
        return;
    }

    const headers = [
        'Employee Name',

        'Sales Target',
        'Sales Achievement',
        'Sales Achievement %',
        'Sales Incentive %',

        'Marketing Target',
        'Marketing Achievement',
        'Marketing Achievement %',
        'Marketing Incentive %',

        'CTP Target',
        'CTP Achievement',
        'CTP Achievement %',
        'CTP Incentive %',

        'Total Eligibility %',
        'Monthly Salary',
        'Monthly Incentive Amount'
    ];

    const rows = this.tableData.map(row => [
        row.employeeName,

        row.salesTarget,
        row.salesAchievement,
        row.salesPct,
        row.salesEligibility,

        row.marketingTarget,
        row.marketingAchievement,
        row.marketingPct,
        row.marketingEligibility,

        row.ctpTarget,
        row.ctpAchievement,
        row.ctpPct,
        row.ctpEligibility,

        row.totalEligibility,
        row.monthlySalary,
        row.monthlyIncentiveAmount
    ]);

    let csvContent = '';
    csvContent += headers.join(',') + '\n';

    rows.forEach(r => {
        csvContent += r.map(val => `"${val ?? 0}"`).join(',') + '\n';
    });

    const fileName = `Incentive_Report_${this.selectedMonth}_${this.selectedYear}.xls`;

    this.downloadFile(csvContent, fileName);
}

downloadFile(content, fileName) {
    const element = document.createElement('a');
    element.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(content);
    element.target = '_self';
    element.download = fileName;
    document.body.appendChild(element);
    element.click();
    document.body.removeChild(element);
}
}