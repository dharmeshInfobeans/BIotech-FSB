import { LightningElement, track, wire, api } from 'lwc';
import getDistributorsForCurrentUser from '@salesforce/apex/MarketXraySectionBController.getDistributorsForCurrentUser';
import fetchMaterAgreementAllRelatedProducts from '@salesforce/apex/MarketXraySectionBController.fetchMaterAgreementAllRelatedProducts';
import fetchAllProducts from '@salesforce/apex/MarketXraySectionBController.fetchAllProducts';
import { CurrentPageReference } from 'lightning/navigation';
import DIVISION from '@salesforce/label/c.Division1';
import CATEGORY from '@salesforce/label/c.Category';
//import DISTRIBUTOR from '@salesforce/label/c.Distributor';
import BIOTECH_PRODUCT_RANGE from '@salesforce/label/c.Biotech_Product_Range';
import BRAND_NAME from '@salesforce/label/c.Brand_Name';
import PRICE_KEY_ACCOUNT from '@salesforce/label/c.Price_KeyAccounts';
import PRICE_FOR_RETAIL from '@salesforce/label/c.Price_for_Retail';
import TOTAL_PACKAGE from '@salesforce/label/c.Total_Package';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class MarketCompetitorPriceComparison extends LightningElement {

    label = { DIVISION, CATEGORY, BIOTECH_PRODUCT_RANGE, BRAND_NAME, PRICE_KEY_ACCOUNT, PRICE_FOR_RETAIL, TOTAL_PACKAGE }

    @track distributors = [];
    @track masterAgreements = [];
    @track allProducts = [];
    @track baseProducts = [];
    @track currentProducts = [];
    @track selectedDistributorId = null;
    @track selectedDistributorName = '';
    @track dataToSave = [];
    @api getDistributorDataToParent = [];
    @track distributorData = {};
    @track biotechButton = '';
    @api userid;
    _recordId = null;

    @wire(CurrentPageReference)
    pageRef(ref) {
        if (ref?.attributes?.recordId) {
            this._recordId = ref.attributes.recordId;
            console.log('MarketCompetitorPriceComparison recordId from URL:', this._recordId);
        }
    }

    connectedCallback() {
        this.getDistributorFromParent();
    }

    get distributorButtons() {
        const biotech = this.distributors.filter(d => d.Name === 'Biotech');
        const others  = this.distributors.filter(d => d.Name !== 'Biotech');

        const finalOrder = [...others, ...biotech];

        return finalOrder.map(dist => ({
            ...dist,
            Name: dist.Name ? dist.Name.toUpperCase() : dist.Name,
            variant: dist.Id === this.selectedDistributorId ? 'brand' : 'neutral'
        }));
    }

    get showEndUserColumn() {
        return this.selectedDistributorName === 'Biotech';
    }


    getDistributorFromParent() {
        setTimeout(() => {
            console.log('getDistributorDataToParent in set timeout  ', this.getDistributorDataToParent);
            this.loadExistingData();
        }, 2000);
        console.log('getDistributorDataToParent', this.getDistributorDataToParent);
    }

    loadExistingData() {
        const rows = this.getDistributorDataToParent;

        if (!rows || rows.length === 0) {
            console.log("No existing data from parent - fresh start");
            return;
        }

        console.log("Loading existing data from parent:", rows);

        let finalData = {};

        rows.forEach(row => {
            const distId = row.Distributor__c;
            const productId = row.Product__c;

            if (!distId || !productId) return;

            if (!finalData[distId]) {
                finalData[distId] = {};
            }

            finalData[distId][productId] = {
                distributorId: distId,
                productId: productId,
                lineItemId: row.Id,
                agreementProductId: row.Agreement_Product__c || null,
                brandName: row.Brand_Name__c || '',
                priceKeyAccounts: row.Price_Key_Account__c || '',
                priceRetail: row.Price_For_Retail__c || '',
                totalPackage: row.Total_Package__c || '',
                division: row.Division__c || '',
                category: row.Category__c || '',
                endUser: row.End_User_Price_by_Distributor_to_Doctor__c || ''
            };
        });

        this.distributorData = finalData;

        console.log("FINAL distributorData (same as old method):", JSON.stringify(this.distributorData, null, 2));

        this.isDataLoaded = true;

        if (this.selectedDistributorId) {
            this.loadDistributorProducts();
        }
    }


    @wire(fetchMaterAgreementAllRelatedProducts,{userId : '$userid', recordId: '$_recordId'})
    wiredMasterAgreementData({ error, data }) {
        if (data) {
            console.log('Fetched Master Agreement Data:', data);
            let maList = [];
            data.forEach(account => {
                if (account.Master_Agreements__r) {
                    account.Master_Agreements__r.forEach(ma => {
                        if (ma.Is_Active__c) {
                            let agreement = {
                                agreementId: ma.Id,
                                accountId: account.Id,
                                products: []
                            };
                            if (ma.Agreement_Products__r) {
                                ma.Agreement_Products__r.forEach(ap => {
                                    let prod = {
                                        agreementProductId: ap.Id,
                                        masterAgreementId: ma.Id,
                                        productId: ap.Product__r ? ap.Product__r.Id : '',
                                        productName: ap.Product__r ? ap.Product__r.Name : '',
                                        division: ap.Product__r ? ap.Product__r.Division__c : '',
                                        category: ap.Product__r ? ap.Product__r.Category__c : '',
                                        isAgreementProduct: true,
                                        isSeparator: false
                                    };
                                    agreement.products.push(prod);
                                });
                            }
                            maList.push(agreement);
                        }
                    });
                }
            });

            this.masterAgreements = maList.length > 0 ? maList[0] : { products: [] };
            console.log('Transformed Master Agreements:', this.masterAgreements);

            this.buildBaseProducts();
        } else if (error) {
            console.error('Error fetching agreements:', error);
        }
    }

    @wire(fetchAllProducts, { userId: '$userid', recordId: '$_recordId' })
    wiredAllProducts({ error, data }) {
        console.log('All products data:', data);
        if (data) {
            this.allProducts = data.map(p => ({
                productId: p.Id,
                productName: p.Name,
                division: p.Division__c,
                category: p.Category__c,
                isAgreementProduct: false,
                isSeparator: false
            }));
            console.log('All Products:', this.allProducts);

            this.buildBaseProducts();
        } else if (error) {
            console.error('Error fetching all products:', error);
        }
    }

    @wire(getDistributorsForCurrentUser, {userId :'$userid', recordId: '$_recordId' })
    wiredData({ error, data }) {
        console.log('Distributors data:', data);
        if (data) {
            this.distributors = data.map(i => ({
                Id: i.Id,
                Name: i.Name
            }));
            console.log('Distributors:', this.distributors);
            console.log('this.selectedDistributorId:', this.selectedDistributorId);
            if (this.distributors.length > 0 && !this.selectedDistributorId) {
                this.selectedDistributorId = this.distributors[0].Id;
                this.selectedDistributorName = this.distributors[0].Name;
                this.loadDistributorProducts();
            }
        } else if (error) {
            console.error('Error:', error);
        }
    }

    buildBaseProducts() {
        let agreementProductIds = new Set();
        if (this.masterAgreements && this.masterAgreements.products) {
            let uniqueProducts = Array.from(new Map(this.masterAgreements.products.map(obj => [obj.productId, obj])).values());
            this.masterAgreements.products = uniqueProducts;
            console.log('OUTPUT :this.masterAgreements.products  ', this.masterAgreements.products);
            this.masterAgreements.products.forEach(p => {
                if (p.productId) {
                    agreementProductIds.add(p.productId);
                }
            });
        }

        let combined = this.masterAgreements && this.masterAgreements.products ? JSON.parse(JSON.stringify(this.masterAgreements.products)) : [];

        let otherProducts = [];
        if (this.allProducts && this.allProducts.length > 0) {
            this.allProducts.forEach(product => {
                if (!agreementProductIds.has(product.productId)) {
                    otherProducts.push(JSON.parse(JSON.stringify(product)));
                }
            });
        }

        if (combined.length > 0 && otherProducts.length > 0) {
            combined.push({
                separatorKey: 'separator-row',
                isSeparator: true,
                productId: 'separator-' + Date.now()
            });
        }

        combined = combined.concat(otherProducts);
        this.baseProducts = combined;
        console.log('this.baseProducts :==========>>> ', this.baseProducts);

        console.log('Base Products with Separator:', this.baseProducts);

        if (this.selectedDistributorId) {
            this.loadDistributorProducts();
        }
    }

    loadDistributorProducts() {
        if (!this.baseProducts || this.baseProducts.length === 0) {
            this.currentProducts = [];
            return;
        }

        this.currentProducts = this.baseProducts.map(prod => {
            if (prod.isSeparator) {
                return { ...prod };
            }

            const savedData = this.distributorData[this.selectedDistributorId]?.[prod.productId];
            console.log('savedData=============>>>', savedData);

            return {
                ...prod,
                brandName: savedData?.brandName || '',
                //agreementProductId: savedData?.agreementProductId || '',
                priceKeyAccounts: savedData?.priceKeyAccounts || '',
                priceRetail: savedData?.priceRetail || '',
                totalPackage: savedData?.totalPackage || '',
                endUser: savedData?.endUser || ''
            };
        });

        console.log('Loaded products for distributor:', this.selectedDistributorName);
        console.log('Current Products:', this.currentProducts);
    }

    get combinedProducts() {
        //console.log('=========>>>>>this.currentProducts', this.currentProducts);
        return this.currentProducts;
    }

    handleBrandClick(event) {
        const newDistributorId = event.currentTarget.dataset.id;
        console.log('Clicked Distributor ID:', newDistributorId);

        if (newDistributorId === this.selectedDistributorId) {
            console.log('Same distributor - no action needed');
            return;
        }

        const distributor = this.distributors.find(d => d.Id === newDistributorId);

        this.selectedDistributorId = newDistributorId;
        this.selectedDistributorName = distributor ? distributor.Name : '';

        console.log('Switched to Distributor:', this.selectedDistributorName);

        this.loadDistributorProducts();

        console.log('All Distributor Data:', JSON.stringify(this.distributorData, null, 2));
    }

    handleChange(event) {
        const productId = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = event.target.value;
        const index = event.target.dataset.index;

        if (!this.distributorData[this.selectedDistributorId]) {
            this.distributorData[this.selectedDistributorId] = {};
        }

        const currentProduct = this.currentProducts[parseInt(index)];

        if (!this.distributorData[this.selectedDistributorId][productId]) {
            this.distributorData[this.selectedDistributorId][productId] = {
                distributorId: this.selectedDistributorId,
                productId: productId,
                agreementProductId: currentProduct?.agreementProductId || null,
                brandName: '',
                priceKeyAccounts: '',
                priceRetail: '',
                totalPackage: '',
                endUser: ''
            };
        }

        this.distributorData[this.selectedDistributorId][productId][field] = value;
        console.log('?????this.distributorData========>>>', this.distributorData);
        this.distributorData[this.selectedDistributorId][productId].agreementProductId = currentProduct?.agreementProductId || null;
        console.log('?????this.distributorDatuyeyuewyueyuewnmdsnnmda========>>>', this.distributorData);


        this.currentProducts = this.currentProducts.map(prod => {
            if (prod.productId === productId && !prod.isSeparator) {
                return {
                    ...prod,
                    [field]: value
                    //agreementProductId: currentProduct?.agreementProductId
                };
            }
            return prod;
        });
        console.log('this.currentProducts======>>>uprrrr', this.currentProducts);
        console.log('Updated distributorData:', JSON.stringify(this.distributorData, null, 2));
    }

    isActiveDistributor(distributorId) {
        return this.selectedDistributorId === distributorId;
    }


    @api
    handleSave() {
        console.log("=== SAVING ALL DISTRIBUTOR DATA ===");
        console.log("Complete Data Structure:", JSON.stringify(this.distributorData));

        const savedDistIds = Object.keys(this.distributorData);
        console.log("savedDistIds======>>>", savedDistIds);

        const validDistIds = this.distributors.map(d => d.Id);
        console.log("validDistIds : ", validDistIds);

        const missingDistIds = validDistIds.filter(id => !savedDistIds.includes(id));
        console.log("missingDistIds (distributors with NO line items) >>>??? ====>>>", missingDistIds);

        // 1️⃣ Check that every distributor has at least one product
        if (missingDistIds.length > 0) {
            const missingDistNames = missingDistIds.map(id => {
                const dist = this.distributors.find(d => d.Id === id);
                return dist ? dist.Name : id;
            });
            const missingListString = missingDistNames.join(", ");

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Save Failed",
                    message: `Please add at least one product for each competitor. You have not added any product for: ${missingListString}`,
                    variant: "warning",
                    mode: "dismissable"
                })
            );

            return [];
        }

        // 2️⃣ Validate required fields for each row with Biotech exception
        let incompleteRows = [];

        savedDistIds.forEach(distId => {
            const distributor = this.distributors.find(d => d.Id === distId);
            const distName = distributor ? distributor.Name : distId;

            Object.keys(this.distributorData[distId]).forEach(prodId => {
                const row = this.distributorData[distId][prodId];

                if (distName === "Biotech") {
                    // For Biotech → only endUser is required
                    if (!row.endUser && row.endUser !== 0) {
                        incompleteRows.push({
                            distributor: distName,
                            productId: row.productId,
                            missingField: "End User"
                        });
                    }
                } else {
                    // For other distributors → the 4 fields are required
                    const isBasicFieldsEmpty =
                        !row.brandName ||
                        row.priceKeyAccounts === "" ||
                        row.priceRetail === "" ||
                        row.totalPackage === "";

                    if (isBasicFieldsEmpty) {
                        incompleteRows.push({
                            distributor: distName,
                            productId: row.productId,
                            missingField: "Brand Name / Price / Total Package"
                        });
                    }
                }
            });
        });

        if (incompleteRows.length > 0) {
            // Build error message listing unique distributor names
            const uniqueDistMessages = [
                ...new Set(incompleteRows.map(r => r.distributor))
            ];

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Required Fields Missing",
                    message: `Please complete required fields for: ${uniqueDistMessages.join(", ")}`,
                    variant: "warning",
                    mode: "dismissable"
                })
            );

            return [];
        }

        // 3️⃣ All validations passed — prepare for save
        let dataToSave = [];
        savedDistIds.forEach(distId => {
            Object.keys(this.distributorData[distId]).forEach(prodId => {
                dataToSave.push(this.distributorData[distId][prodId]);
            });
        });

        console.log("Data to Save (Array):", dataToSave);
        this.dataToSave = dataToSave;

        return this.dataToSave;
    }




    // @api
    // handleSave() {
    //     console.log('=== SAVING ALL DISTRIBUTOR DATA ===');
    //     console.log('Complete Data Structure:', JSON.stringify(this.distributorData));

    //     const savedDistIds = Object.keys(this.distributorData);
    //     console.log('savedDistIds======>>>',savedDistIds);
    //     const validDistIds = this.distributors.map(d => d.Id);
    //     console.log('validDistIds : ',validDistIds);

    //     const missingDistIds = validDistIds.filter(id => !savedDistIds.includes(id));
       
    //     console.log('missingDistIds (distributors with NO line items) >>>??? ====>>>', missingDistIds);

    //     if (missingDistIds.length > 0) {
    //         //const missingListString = missingDistIds.join(', ');
    //           const missingDistNames = missingDistIds.map(id => {
    //             const dist = this.distributors.find(d => d.Id === id);
    //                             return dist ? dist.Name : id;
    //                         });

    //             const missingListString = missingDistNames.join(', ');

    //         this.dispatchEvent(new ShowToastEvent({
    //             title: 'Save Failed',
    //             message: `Please add at least one product for each competitor. You have not added any product for: ${missingListString}`,
    //             variant: 'warning',
    //             mode: 'dismissable'
    //         }));

    //         console.warn('Missing Distributor IDs:', missingDistIds);
    //         return [];
    //     }

    //     let dataToSave = [];
    //     savedDistIds.forEach(distId => {
    //         const distributor = this.distributors.find(d => d.Id === distId);
    //         Object.keys(this.distributorData[distId]).forEach(prodId => {
    //             dataToSave.push(this.distributorData[distId][prodId]);
    //         });
    //         console.log(`Distributor: ${distributor?.Name || distId} - Items: ${Object.keys(this.distributorData[distId]).length}`);
    //     });

    //     console.log('Data to Save (Array):', dataToSave);
    //     this.dataToSave = dataToSave;

    //     return this.dataToSave;
    // }


    // @api
    // handleSave() {
    //     console.log('=== SAVING ALL DISTRIBUTOR DATA ===');
    //     console.log('Complete Data Structure:', JSON.stringify(this.distributorData));

    //     let dataToSave = [];
    //     Object.keys(this.distributorData).forEach(distId => {
    //         const distributor = this.distributors.find(d => d.Id === distId);
    //         Object.keys(this.distributorData[distId]).forEach(prodId => {
    //             dataToSave.push(this.distributorData[distId][prodId]);
    //         });
    //         console.log(`Distributor: ${distributor?.Name || distId} - Items: ${Object.keys(this.distributorData[distId]).length}`);
    //     });

    //     console.log('Data to Save (Array):', dataToSave);

    //     this.dataToSave = dataToSave;

    //     return this.dataToSave;

    // }

    handleSubmit() {
        console.log('=== SUBMITTING ALL DISTRIBUTOR DATA ===');
        console.log('Complete Data Structure:', JSON.stringify(this.distributorData, null, 2));

        if (Object.keys(this.distributorData).length === 0) {
            console.warn('No data to submit');
            return;
        }

    }
}