import { LightningElement, track, wire,api } from 'lwc';
import getAgreementProducts from '@salesforce/apex/SecondarySalesDistStockController.getAgreementProducts';
import getInitialStock from '@salesforce/apex/SecondarySalesDistStockController.getInitialStock';
import upsertInitialStock from '@salesforce/apex/SecondarySalesDistStockController.upsertInitialStock';
import checkUserAccess from '@salesforce/apex/SecondarySalesDistStockController.checkUserAccess';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import STOCK_CHANNEL from '@salesforce/messageChannel/stockUpdateChannel__c';
import Initial_Stock_Setup from '@salesforce/label/c.Initial_Stock_Setup';
import Initial_Stock from '@salesforce/label/c.Initial_Stock';
import Product_Name_Secondary_sales from '@salesforce/label/c.Product_Name_Secondary_sales';
import Units from '@salesforce/label/c.Units';
import No_products_available_for_this_distributor from '@salesforce/label/c.No_products_available_for_this_distributor';
import { CurrentPageReference } from 'lightning/navigation';
import Save_Initial_Stock from '@salesforce/label/c.Save_Initial_Stock';

export default class SecondarySalesInitialStock extends LightningElement {

    label = {
        Initial_Stock_Setup,Initial_Stock,Product_Name_Secondary_sales,Units,No_products_available_for_this_distributor,Save_Initial_Stock
    };

    @track products = [];
    @track pagedProducts = [];
    @track errorMessage;
    //@api recordId;
    pageSize = 10;
    currentPage = 1;
    totalRecords = 0;
    isLoading = false;
    isBioTechUser = false;
    connectedCallback() {
        //this.loadProducts();
    }

  _recordId;
  @track hasReadAccess = false;
  @track hasEditAccess = false;

    @wire(CurrentPageReference)
    pageRef(ref) {
        if (ref?.attributes?.recordId) {
            this._recordId = ref.attributes.recordId;
            console.log('recordId from URL:', this._recordId); // ✅ will log correctly
            //this.loadProducts(this._recordId);
            //console.log('OUTPUT checkUserAccess: ===>>>', checkUserAccess({recordId:this._recordId }));
            checkUserAccess({ recordId: this._recordId })
            .then(result => {
                this.hasReadAccess = result.Read;
                this.hasEditAccess = result.Edit;
                this.loadProducts(this._recordId);
                console.log('OUTPUT checkUserAccess:', result);
                console.log('Read Access:', this.hasReadAccess);
                console.log('Edit Access:', this.hasEditAccess);
            })
            .catch(error => {
                console.error('Error:', error);
                this.loadProducts(this._recordId);
            });
        }
        else{
           //this.loadProducts(null);
           checkUserAccess({ recordId: null })
            .then(result => {
                this.hasReadAccess = result.Read;
                this.hasEditAccess = result.Edit;
                this.loadProducts(null);
            })
            .catch(error => {
                console.error('Error:', error);
                this.loadProducts(null);
            });
        }
    }

    get recordId() {
        return this._recordId;
    }

    @wire(MessageContext)
    messageContext;

   

    async loadProducts(recordId) {
        console.log('recordId', recordId);
        this.isLoading = true;
        try {
            const agreementData = await getAgreementProducts({recordId:recordId });
            //const stockData = await getInitialStock();
            const stockData = await getInitialStock({ recordId: recordId });
            console.log('stockData======>>>>>>', stockData);
            this.prepareStockMap(stockData);
            this.prepareProductList(agreementData);
            this.totalRecords = this.products.length;
            this.currentPage = 1;
            this.setPagedProducts();

        }
        catch (error) {
            console.error(error);
        }
        this.isLoading = false;
    }

    prepareStockMap(stockData) {
        this.stockMap = {};
        if (!stockData) {
            return;
        }
        stockData.forEach(s => {

            this.stockMap[s.Product__c] = {

                id: s.Id,
                stock: s.Initial_Stock__c,
                disable: s.Allow_Initial_Stock_Edit__c

            };

        });

    }


    prepareProductList(accountData) {
        this.products = [];

        if (!accountData || accountData.length === 0) return;

        const account = accountData[0];
        if (!account.Master_Agreements__r) return;

        account.Master_Agreements__r.forEach(agreement => {
            if (agreement.Agreement_Products__r) {
                agreement.Agreement_Products__r.forEach(ap => {
                    const existingStock = this.stockMap[ap.Product__c];

                    // CRM/RSM → always enabled
                    // Read only → always disabled  
                    // Dealer → Allow_Initial_Stock_Edit__c ke basis pe
                    let disableInput;
                    if (this.hasEditAccess && !this._recordId) {
                        // Dealer portal user — field ke basis pe
                        disableInput = existingStock ? existingStock.disable : false;
                    } else if (this.hasEditAccess && this._recordId) {
                        // CRM / RSM — always enabled
                        disableInput = false;
                    } else {
                        // Read only — always disabled
                        disableInput = true;
                    }

                    this.products.push({
                        id: existingStock ? existingStock.id : null,
                        customerId: agreement.Account__c,
                        name: ap.Product__r?.Name,
                        productId: ap.Product__c,
                        agreementId: agreement.Id,
                        stock: existingStock ? existingStock.stock : null,
                        disableInput: disableInput
                    });
                });
            }
        });

        this.pagedProducts = [...this.products];
    }


    // prepareProductList(accountData) {

    //     this.products = [];

    //     if (!accountData || accountData.length === 0) {
    //         return;
    //     }

    //     const account = accountData[0];

    //     if (!account.Master_Agreements__r) {
    //         return;
    //     }

    //     account.Master_Agreements__r.forEach(agreement => {

    //         if (agreement.Agreement_Products__r) {

    //             agreement.Agreement_Products__r.forEach(ap => {

    //                 const existingStock = this.stockMap[ap.Product__c];
    //                 console.log('existingStock ======>>>', existingStock);

    //                 this.products.push({

    //                     id: existingStock ? existingStock.id : null,
    //                     customerId: agreement.Account__c,
    //                     name: ap.Product__r?.Name,
    //                     productId: ap.Product__c,
    //                     agreementId: agreement.Id,

    //                     stock: existingStock ? existingStock.stock : null,

    //                     //disableInput: existingStock ? existingStock.disable : false
    //                     disableInput: (existingStock ? existingStock.disable : false) || (this.hasReadAccess && !this.hasEditAccess)

    //                 });

    //             });

    //         }

    //     });

    //     this.pagedProducts = [...this.products];
    //     console.log('this.pagedProducts==========---->>>>>', this.pagedProducts);
    // }

    setPagedProducts() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pagedProducts = this.products.slice(start, end);
    }
    handlePrint(){
        console.log('OUTPUT : ',this.recordId);
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.setPagedProducts();
        }
    }

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.setPagedProducts();
        }
    }

    handleStockChange(event) {

        const productId = event.target.dataset.id;
        const value = event.target.value;

        console.log('productId', productId);
        console.log('value', value);

        this.products = this.products.map(prod => {

            if (prod.productId === productId) {

                return {
                    ...prod,
                    stock: value
                };

            }

            return prod;

        });

        console.log('Updated Products', JSON.stringify(this.products));

        this.setPagedProducts();
    }


    handleSave() {
        console.log('Final Initial Stock Payload:', JSON.stringify(this.products));
        const filteredProducts = this.products.filter(p => p.stock > 0);

        if (filteredProducts.length === 0) {
            this.showToast('Error', 'Please enter stock for at least one product', 'error');
            return;
        }

        const payload = filteredProducts.map(p => {
            return {
                customerId: p.customerId,
                productId: p.productId,
                initialStock: Number(p.stock)
            };
        });

        console.log('Payload to Apex:', JSON.stringify(payload));

        upsertInitialStock({ stockList: payload })
            .then((result) => {
                console.log('result------>>>>', result);
                this.applyReturnedStock(result);
                this.handlePublish();
                this.showToast('Success', 'Initial Stock Saved Successfully', 'success');

            })
            .catch(error => {

                this.showToast('Error', error.body.message, 'error');

            });
    }

    applyReturnedStock(result) {

        const stockMap = {};

        // response ko map me convert
        result.forEach(r => {
            stockMap[r.Product__c] = {
                initialStock: r.Initial_Stock__c,
                disabled: r.Allow_Initial_Stock_Edit__c
            };
        });

        this.products = this.products.map(p => {
            if (stockMap[p.productId]) {
                return {
                    ...p,
                    stock: stockMap[p.productId].initialStock,
                    disableInput: stockMap[p.productId].disabled
                };
            }
            return p;
        });

        this.setPagedProducts();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title: title, message: message, variant: variant })
        );
    }

    handlePublish() {
        console.log('OUTPUT : message pub');
        publish(this.messageContext, STOCK_CHANNEL, {
            type: 'INITIAL_STOCK_UPDATED'
        });
    }



    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize);
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get startRecord() {
        return (this.currentPage - 1) * this.pageSize + 1;
    }

    get endRecord() {
        const end = this.currentPage * this.pageSize;
        return end > this.totalRecords ? this.totalRecords : end;
    }

    get hasError() {
        return this.errorMessage;
    }

}