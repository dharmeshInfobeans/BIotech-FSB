import { LightningElement , api, track } from 'lwc';
import SR_NO_LABEL from '@salesforce/label/c.Sr_No';
import BRAND_NAME_LABEL from '@salesforce/label/c.Brand_Name';
import ANNUAL_SALES_QTY_LABEL from '@salesforce/label/c.Annual_Sales_Qty';
import SHARE_LABEL from '@salesforce/label/c.Share';
import DISTRIBUTOR_LABEL from '@salesforce/label/c.Distributor';


export default class MarketXrayBrandTable extends LightningElement {

    label={SR_NO_LABEL,BRAND_NAME_LABEL, ANNUAL_SALES_QTY_LABEL, SHARE_LABEL, DISTRIBUTOR_LABEL}

    @api title;
    @api disabled = false;
    @track rows = [
        { id: 1 },
        { id: 2 },
        { id: 3 }
    ];
    
    @track brandMarketShareObj = [{
        "serialNo": 1,
        "recordId": null,
        "brandName" : "",
        "annualSales" : "",
        "percentageShare" : "",
        "distributor": ""
    },
    {
        "serialNo": 2,
        "recordId": null,
        "brandName" : "",
        "annualSales" : "",
        "percentageShare" : "",
        "distributor": ""
    },
    {
        "serialNo": 3,
        "recordId": null,
        "brandName" : "",
        "annualSales" : "",
        "percentageShare" : "",
        "distributor": ""
    }]
    

    handleOnchange(event) {
        const field = event.target.name;
        console.log('field ======>>>>: ', field);
        const serialNo = parseInt(event.target.dataset.id, 10);
        console.log('serialNo ======>>>>: ', serialNo);
        const value = event.target.value;
        console.log('value ======>>>>: ', value);

        this.brandMarketShareObj = this.brandMarketShareObj.map(row =>
            row.serialNo === serialNo ? { ...row, [field]: value } : row
        );

        console.log('this.brandMarketShareObj ======>>>>: ', this.brandMarketShareObj);
    }

    // @api
    // getTableData() {
    //     return this.brandMarketShareObj;
    // }

    @api
    getTableData() {
        // Return data with recordId for backend processing
        return this.brandMarketShareObj.map(row => ({
            id: row.recordId, // Salesforce ID (if exists)
            brandName: row.brandName,
            annualSales: row.annualSales,
            percentageShare: row.percentageShare,
            distributor: row.distributor
        }));
    }


    @api
    setTableData(data) {
        console.log('Data received in child: ', data);

        // Map incoming data (max 3 rows) to our structure
        this.brandMarketShareObj = this.brandMarketShareObj.map((row, index) => {
            if(data[index]) {
                return {
                    serialNo: index + 1,
                    recordId: data[index].id || null, // Store Salesforce ID
                    brandName: data[index].brandName || "",
                    annualSales: data[index].annualSales || "",
                    percentageShare: data[index].percentageShare || "",
                    distributor: data[index].distributor || ""
                };
            }
            return row; // Keep empty row if no data
        });

        console.log('Updated child brandMarketShareObj: ', this.brandMarketShareObj);
    }

    // @api
    // setTableData(data) {
    //     console.log('Data received in child: ', data);

    //     // Build new array with ids (1,2,3...)
    //     this.brandMarketShareObj = data.map((row, index) => ({
    //         id: row.id,
    //         brandName: row.brandName || "",
    //         annualSales: row.annualSales || "",
    //         percentageShare: row.percentageShare || "",
    //         distributor: row.distributor || ""
    //     }));

    //     console.log('Updated child brandMarketShareObj: ', this.brandMarketShareObj);
    // }

    @api resetList(){
       console.log('reset method of child called start');
       this.brandMarketShareObj=[{
        "id": 1,
        "brandName" : "",
        "annualSales" : "",
        "percentageShare" : "",
        "distributor": ""
    },
    {
        "id": 2,
        "brandName" : "",
        "annualSales" : "",
        "percentageShare" : "",
        "distributor": ""
    },
    {
        "id": 3,
        "brandName" : "",
        "annualSales" : "",
        "percentageShare" : "",
        "distributor": ""
    }];
    console.log('reset method of child called end');
    }

    get rows() {
        return this.brandMarketShareObj;
    }

}