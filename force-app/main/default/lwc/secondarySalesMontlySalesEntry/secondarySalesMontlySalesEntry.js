import { LightningElement, track, wire } from 'lwc';
import getAgreementProducts from '@salesforce/apex/SecondarySalesDistStockController.getAgreementProducts';
import getInitialStock from '@salesforce/apex/SecondarySalesDistStockController.getInitialStock';
import saveMonthlySales from '@salesforce/apex/SecondarySalesLineItemController.saveMonthlySales';
import getMonthlySalesEntry from '@salesforce/apex/SecondarySalesLineItemController.getMonthlySalesEntry';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, MessageContext } from 'lightning/messageService';
import { CurrentPageReference } from 'lightning/navigation';
import STOCK_CHANNEL from '@salesforce/messageChannel/stockUpdateChannel__c';
import Monthly_Sales_Entry from '@salesforce/label/c.Monthly_Sales_Entry';
import Month_1 from '@salesforce/label/c.Month_1';
import Product_Name_Secondary_sales from '@salesforce/label/c.Product_Name_Secondary_sales';
import Units from '@salesforce/label/c.Units';
import No_products_available_for_this_distributor from '@salesforce/label/c.No_products_available_for_this_distributor';
import Unit_Sold_This_Month from '@salesforce/label/c.Unit_Sold_This_Month';
import Save_Monthly_Sales from '@salesforce/label/c.Save_Monthly_Sales';
import checkUserAccess from '@salesforce/apex/SecondarySalesDistStockController.checkUserAccess';

export default class SecondarySalesMonthlySalesEntry extends LightningElement {

     label = {
        Monthly_Sales_Entry,Month_1,Product_Name_Secondary_sales,Units,No_products_available_for_this_distributor,Unit_Sold_This_Month,Save_Monthly_Sales
    };
    subscription = null;

    @wire(MessageContext)
    messageContext;

    @track products = [];
    stockMap = {};
    monthlySalesMap = {};
    @track pagedProducts = [];
    @track errorMessage;
    @track monthOptions = [];
    @track selectedMonth;

    // cache of all monthly sales entries from server
    monthlySalesAll = [];

    pageSize = 10;
    currentPage = 1;
    totalRecords = 0;
    isLoading = false;

    _recordId;
    @track hasReadAccess = false;
    @track hasEditAccess = false;


    @wire(CurrentPageReference)
    pageRef(ref) {
        if (ref?.attributes?.recordId) {
            this._recordId = ref.attributes.recordId;
            checkUserAccess({ recordId: this._recordId })
                .then(result => {
                    this.hasReadAccess = result.Read;
                    this.hasEditAccess = result.Edit;
                    this.loadProducts(this._recordId);
                })
                .catch(error => {
                    console.error('Error:', error);
                    this.loadProducts(this._recordId);
                });
        } else {
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

    // @wire(CurrentPageReference)
    // pageRef(ref) {
    //     if (ref?.attributes?.recordId) {
    //         this._recordId = ref.attributes.recordId;
    //         console.log('recordId from URL:', this._recordId); // ✅ will log correctly
    //         this.loadProducts(this._recordId);
    //     }
    //     else{
    //        this.loadProducts(null); 
    //     }
    // }

    get recordId() {
        return this._recordId;
    }

    connectedCallback() {
        console.log('OUTPUT : called >> ');
        this.generateMonthOptions();
       // this.loadProducts();
        this.subscribeToMessage();
    }

    subscribeToMessage() {
        if (this.subscription) return;

        this.subscription = subscribe(
            this.messageContext,
            STOCK_CHANNEL,
            (message) => this.handleMessage(message)
        );
    }

    handleMessage(message) {
        console.log('OUTPUT : sub called');
        if (message.type === 'INITIAL_STOCK_UPDATED') {
            console.log('Refreshing Monthly Sales Data');
            this.loadProducts(); 

        }
    }

    generateMonthOptions() {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const today = new Date();
        const currentMonth = today.getMonth(); // 0-11
        const currentYear = today.getFullYear();

        let options = [];
        for (let i = 0; i <= currentMonth; i++) {
            options.push({
                label: `${months[i]} ${currentYear}`,
                value: `${currentYear}-${i + 1}`
            });
        }
        this.monthOptions = options;
        // default selected month -> current month
        this.selectedMonth = options[options.length - 1]?.value;
    }

    async loadProducts(recordId) {
        this.isLoading = true;
        this.errorMessage = null;
        try {
            const agreementData = await getAgreementProducts({recordId:recordId});
            //const stockData = await getInitialStock();
            const stockData = await getInitialStock({ recordId: recordId });
            const monthlySalesData = await getMonthlySalesEntry(); // all months

            this.monthlySalesAll = monthlySalesData || [];

            this.prepareStockMap(stockData);
            // Build monthly map for default selected month
            const lastDate = this.getSelectedMonthLastDate();
            this.prepareMonthlyMapForMonth(lastDate);

            // Build products list using the monthly map currently prepared
            this.prepareProductList(agreementData);
            this.totalRecords = this.products.length;
            this.currentPage = 1;
            this.setPagedProducts();
        }
        catch (error) {
            console.error(error);
            this.errorMessage = error?.body?.message || 'Failed to load data';
        }
        this.isLoading = false;
    }

    prepareStockMap(stockData) {
        this.stockMap = {};
        if (!stockData) return;
        stockData.forEach(s => {
            this.stockMap[s.Product__c] = {
                id: s.Id,
                stock: s.Initial_Stock__c,
                disable: s.Allow_Initial_Stock_Edit__c
            };
        });
    }

    // Build monthlySalesMap for a given month (last date string yyyy-mm-dd)
    prepareMonthlyMapForMonth(monthIsoLastDate) {
        this.monthlySalesMap = {};
        if (!this.monthlySalesAll || this.monthlySalesAll.length === 0 || !monthIsoLastDate) {
            return;
        }

        const target = new Date(monthIsoLastDate);

        this.monthlySalesAll.forEach(s => {
            let salesDateStr = s.Date__c;

            if (!salesDateStr) return;

            const salesDate = new Date(salesDateStr);

            if (salesDate.getFullYear() === target.getFullYear() &&
                salesDate.getMonth() === target.getMonth()) {

                const prodId = s.Product__c;
                if (prodId) {
                    this.monthlySalesMap[prodId] = {
                        id: s.Id,
                        monthlySalesQuantity: s.Quantity__c,
                        disable: !!s.Allow_Monthly_Sales_Edit__c
                    };
                }
            }
        });
    }

    applyMonthlyForSelectedMonth() {
        const lastDate = this.getSelectedMonthLastDate();
        this.prepareMonthlyMapForMonth(lastDate);

        // If products already loaded, update their stock and disable flags
        this.products = this.products.map(p => {
            const existingStock = this.stockMap[p.productId];
            const existingMonthlyStock = this.monthlySalesMap[p.productId];

            let stockValue = '';
            let disableInput = true;

            if (existingMonthlyStock) {
                stockValue = existingMonthlyStock.monthlySalesQuantity;
                disableInput = true;
            } else if (existingStock && existingStock.stock) {
                stockValue = '';
                disableInput = false;
            } else {
                stockValue = '';
                disableInput = true;
            }

            return {
                ...p,
                stock: stockValue,
                monthlySales: existingMonthlyStock ? existingMonthlyStock.monthlySalesQuantity : '',
                disableInput: disableInput
            };
        });

        this.totalRecords = this.products.length;
        this.currentPage = 1;
        this.setPagedProducts();
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
                        const existingMonthlyStock = this.monthlySalesMap[ap.Product__c];

                        let stockValue = '';
                        let disableInput = true;

                        if (existingMonthlyStock) {
                            // Monthly entry already hai — always disabled
                            stockValue = existingMonthlyStock.monthlySalesQuantity;
                            disableInput = true;
                        } else if (this.hasEditAccess && this._recordId) {
                            // CRM / RSM — always enabled (agar monthly entry nahi hai)
                            stockValue = '';
                            disableInput = false;
                        } else if (this.hasEditAccess && !this._recordId) {
                            // Dealer portal — initial stock ke basis pe
                            stockValue = '';
                            disableInput = !(existingStock && existingStock.stock);
                        } else {
                            // Read only
                            stockValue = '';
                            disableInput = true;
                        }

                        this.products.push({
                            id: existingStock ? existingStock.id : null,
                            customerId: agreement.Account__c || account.Id,
                            name: ap.Product__r?.Name || ap.Product__c,
                            productId: ap.Product__c,
                            agreementId: agreement.Id,
                            stock: stockValue,
                            monthlySales: existingMonthlyStock ? existingMonthlyStock.monthlySalesQuantity : '',
                            disableInput: disableInput
                        });
                    });
                }
            });
        }

    // prepareProductList(accountData) {
    //     this.products = [];
    //     if (!accountData || accountData.length === 0) return;
    //     const account = accountData[0];
    //     if (!account.Master_Agreements__r) return;

    //     account.Master_Agreements__r.forEach(agreement => {
    //         if (agreement.Agreement_Products__r) {
    //             agreement.Agreement_Products__r.forEach(ap => {
    //                 const existingStock = this.stockMap[ap.Product__c];
    //                 const existingMonthlyStock = this.monthlySalesMap[ap.Product__c];

    //                 let stockValue = '';
    //                 let disableInput = true;

    //                 if (existingMonthlyStock) {
    //                     stockValue = existingMonthlyStock.monthlySalesQuantity;
    //                     disableInput = true;
    //                 } else if (existingStock && existingStock.stock) {
    //                     stockValue = '';
    //                     disableInput = false;
    //                 } else {
    //                     stockValue = '';
    //                     disableInput = true;
    //                 }

    //                 this.products.push({
    //                    id: existingStock ? existingStock.id : null,
    //                    // id: existingStock ? existingStock.id : ap.Product__c,  // ✅ fallback to productId
    //                     customerId: agreement.Account__c || account.Id,
    //                     name: ap.Product__r?.Name || ap.Product__c,
    //                     productId: ap.Product__c,
    //                     agreementId: agreement.Id,
    //                     stock: stockValue,
    //                     monthlySales: existingMonthlyStock ? existingMonthlyStock.monthlySalesQuantity : '',
    //                     disableInput: disableInput
    //                 });
    //             });
    //         }
    //     });
    // }

    setPagedProducts() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pagedProducts = this.products.slice(start, end);
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

    handleMonthChange(event) {
        this.selectedMonth = event.detail.value;
        this.applyMonthlyForSelectedMonth();
    }

    handleStockChange(event) {
        const productId = event.target.dataset.id;
        const value = event.target.value;

        this.products = this.products.map(prod => {
            if (prod.productId === productId) {
                return {
                    ...prod,
                    stock: value,
                    monthlySales: value
                };
            }
            return prod;
        });

        this.setPagedProducts();
    }

    // handleStockChange(event) {
    //     const productId = event.target.dataset.id;
    //     const value = event.target.value;

    //     this.products = this.products.map(p =>
    //        p.id === productId ? { ...p, stock: value } : p
    //        // p.productId === productId  // 
    //     );
    //     this.setPagedProducts();
    // }

    getSelectedMonthLastDate() {
        if (!this.selectedMonth) return null;
        const parts = this.selectedMonth.split('-');
        const year = parseInt(parts[0], 10);
        const month = parseInt(parts[1], 10);
        const lastDate = new Date(year, month, 0);
        const yyyy = lastDate.getFullYear();
        const mm = String(lastDate.getMonth() + 1).padStart(2, '0');
        const dd = String(lastDate.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    handleSave() {
        const filteredProducts = this.products.filter(p => Number(p.stock) > 0);

        if (filteredProducts.length === 0) {
            this.showToast('Error', 'Please enter stock for at least one product', 'error');
            return;
        }

        const lastDate = this.getSelectedMonthLastDate();

        const payload = filteredProducts.map(p => ({
            customerId: p.customerId,
            secondarySalesHeaderId: p.id,
            productId: p.productId,
            montlySales: Number(p.stock),
            salesMonthDate: lastDate
        }));

        this.isLoading = true;
        console.log('payload======>>>> ', payload);
        saveMonthlySales({ salesList: payload })
            .then(result => {
                this.showToast('Success', 'Monthly Sales Saved', 'success');

                // ✅ STEP 1: Create fast lookup map (O(1))
                const payloadMap = {};
                payload.forEach(p => {
                    payloadMap[p.productId] = p;
                });

                // ✅ STEP 2: Update monthlySalesMap (source of truth)
                payload.forEach(p => {
                    this.monthlySalesMap[p.productId] = {
                        id: p.secondarySalesHeaderId,
                        monthlySalesQuantity: p.montlySales,
                        disable: true
                    };
                });

                // ✅ STEP 3: Mutate ONLY changed rows (no full re-render)
                this.products.forEach(prod => {
                    const updated = payloadMap[prod.productId];

                    if (updated) {
                        prod.stock = updated.montlySales;
                        prod.monthlySales = updated.montlySales;
                        prod.disableInput = true;
                    }
                });

                // ✅ STEP 4: Trigger reactivity safely
                this.products = [...this.products];

                // ✅ STEP 5: Refresh only visible page (no pagination reset)
                this.setPagedProducts();
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', 'Failed to save monthly sales', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title: title, message: message, variant: variant }));
    }

    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize) || 1;
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