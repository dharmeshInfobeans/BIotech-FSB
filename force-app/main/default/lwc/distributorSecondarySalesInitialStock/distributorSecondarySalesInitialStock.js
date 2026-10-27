import { LightningElement, track } from 'lwc';
import getAgreementProducts from '@salesforce/apex/SecondarySalesDistStockController.getAgreementProducts';

export default class DistributorSecondarySalesInitialStock extends LightningElement {
    @track products = [];
    @track pagedProducts = [];
    @track errorMessage;

    pageSize = 10;
    currentPage = 1;
    totalRecords = 0;
    isLoading = false;

    connectedCallback() {
        this.loadProducts();
    }

    loadProducts() {
        this.isLoading = true;

        getAgreementProducts()
            .then(result => {
                console.log('result---->>>',result);
                this.prepareProductList(result);
                this.totalRecords = this.products.length;
                this.currentPage = 1;
                this.setPagedProducts();
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.errorMessage = error?.body?.message || 'Failed to load products';
                console.log('show error message : ',this.errorMessage);
                console.error(error);
            });
    }

    prepareProductList(accountData) {
        this.products = [];

        if (!accountData || accountData.length === 0) {
            return;
        }

        const account = accountData[0];

        if (!account.Master_Agreements__r) {
            return;
        }

        account.Master_Agreements__r.forEach(agreement => {
            if (agreement.Agreement_Products__r) {
                agreement.Agreement_Products__r.forEach(ap => {
                    this.products.push({
                        id: ap.Id,
                        name: ap.Product__r?.Name,
                        stock: 0, // initial stock input
                        productId: ap.Product__c,
                        agreementId: agreement.Id
                    });
                });
            }
        });
    }

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

    handleStockChange(event) {
        const productId = event.target.dataset.id;
        const value = event.target.value;

        this.products = this.products.map(p =>
            p.id === productId ? { ...p, stock: value } : p
        );

        this.setPagedProducts();
    }

    handleSave(){
        console.log('Final Initial Stock Payload:', JSON.stringify(this.products));
        // 👉 Next step: Apex save method
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