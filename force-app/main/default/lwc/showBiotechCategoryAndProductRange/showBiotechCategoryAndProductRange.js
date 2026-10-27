import { LightningElement, track, wire, api } from 'lwc';
import getDistributorsForCurrentUser from '@salesforce/apex/MarketXraySectionBController.getDistributorsForCurrentUser';
import getDistributorData from '@salesforce/apex/ShowBiotechCategoryProductRangeHandler.getDistributorData';
import DIVISION from '@salesforce/label/c.Division1';
import CATEGORY from '@salesforce/label/c.Category';
import DISTRIBUTOR from '@salesforce/label/c.Distributor';
import BIOTECH_PRODUCT_RANGE from '@salesforce/label/c.Biotech_Product_Range';
import DISTRIBUTOR_AGREEMENT_PRICE_A from '@salesforce/label/c.Distributor_Agreement_Price_A';
import FOC_IF_ANY_B from '@salesforce/label/c.FOC_If_any_B';
import IMPORTATION_OR_CUSTOM_CLEARANCE_CHARGES from '@salesforce/label/c.Importation_Customs_Clearance_Charges_C';
import LANDING_COST_TO_DISTRIBUTOR from '@salesforce/label/c.Landing_Cost_to_Distributor_A_B_C'
import END_USER_PRICE_BY_DISTRIBUTOR_TO_DOCTOR from '@salesforce/label/c.End_User_Price_by_Distributor_to_Doctor';
import { CurrentPageReference } from 'lightning/navigation';

export default class ShowBiotechCategoryAndProductRange extends LightningElement {

    @track brandList = [];
    @track brandDataList = ['Brand Name', 'Price KeyAccounts', 'Price for Retail', 'Total Package'];
    @track flatData = [];
    @track distributerId = [];
    @api userid;

    label={DIVISION, CATEGORY, DISTRIBUTOR, BIOTECH_PRODUCT_RANGE, DISTRIBUTOR_AGREEMENT_PRICE_A, FOC_IF_ANY_B, IMPORTATION_OR_CUSTOM_CLEARANCE_CHARGES, LANDING_COST_TO_DISTRIBUTOR, END_USER_PRICE_BY_DISTRIBUTOR_TO_DOCTOR}
     
    //Added by Shakib Khan start 16-07-2026
    _recordId = null;

    @wire(CurrentPageReference)
    pageRef(ref) {
        if (ref?.attributes?.recordId) {
            this._recordId = ref.attributes.recordId;
            console.log('Biotech component recordId from URL:', this._recordId);
        }
    }

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        // agar parent component ne recordId as property pass kiya hai (Account page ka child hone ki soorat me)
        if (value) {
            this._recordId = value;
        }
    }
    //Added by Shakib Khan end 16-07-2026
   
    @wire(getDistributorsForCurrentUser,{userId:'$userid', recordId:'$_recordId'})
    wiredData({ error, data }) {
        if (data) {
            console.log('data===>>>>', data);
            this.brandList = data.filter(i => i.Name !== 'Biotech').map(i => i.Name.toUpperCase()).sort();
            //this.distributerId = data.filter(i => i.Name !== 'BioTech').map(i => i.Id);
             this.distributerId = data.map(i => i.Id);
             this.processedData();
             console.log('ids of distributor',  this.distributerId );
        } else if (error) {
            console.error('Error:', error);
        }
      
    }

   async processedData() {
        this.flatData = [];
    console.log('OUTPUT : this.userid this.userid ',this.userid);
       await getDistributorData({ distributorIds:this.distributerId , distributorName: this.brandList, userId : this.userid, recordId: this._recordId})
          .then(result => {
            console.log('Result vinay ', result);
             this.flatData = result;
          })
          .catch(error => {
            console.error('Error: vinay', error);
        });
       

        console.log('Processed Data:', JSON.parse(JSON.stringify(this.flatData)));
    }

    @api 
    updateCustomsCharges(fieldName, value) {
            console.log('Updating summary table:', fieldName, value);
             console.log('this.flatData:',this.flatData);

            this.flatData = this.flatData.map(row => {
                

                console.log('row.biotechData.customsCharges',row.biotechData.customsCharges);
                let newCustomsCharges = row.biotechData.customsCharges;
                console.log('newCustomsCharges=====>>>>',newCustomsCharges);

                if (fieldName === 'fromIndiaIOL' && row.category === 'MSL' && row.biotechData.origin === 'India') {
                    newCustomsCharges = value;
                }
                if (fieldName === 'fromIndiaSolution' && row.category === 'Non-MSL' && row.biotechData.origin === 'India') {
                    newCustomsCharges = value;
                }
                if (fieldName === 'fromIrelandIOL' && row.category === 'MSL' && row.biotechData.origin === 'Ireland') {
                    newCustomsCharges = value;
                }
                if (fieldName === 'fromIrelandSolution' && row.category === 'Non-MSL' && row.biotechData.origin === 'Ireland') {
                    newCustomsCharges = value;
                }

                if (newCustomsCharges === row.biotechData.customsCharges) {
                    return row;
                }

                let agreementPrice = parseFloat(row.biotechData.agreementPrice) || 0;

                let focText = row.biotechData.foc || "0";
                let focDeduction = (agreementPrice * focText) / 100;

                let customsChargesValue = parseFloat(newCustomsCharges) || 0;
                let customsChargePercentageValue = (agreementPrice * customsChargesValue) / 100; 

                let landingCost = agreementPrice - focDeduction + customsChargePercentageValue;

                return {
                    ...row,
                    biotechData: {
                        ...row.biotechData,
                        customsCharges: newCustomsCharges,
                        landingCost: landingCost.toFixed(2)
                    }
                };
            });

            console.log('Updated flatData:', JSON.parse(JSON.stringify(this.flatData)));
        }

}