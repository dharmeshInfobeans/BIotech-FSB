import { LightningElement, track, api, wire } from 'lwc';
import getProductGroups from '@salesforce/apex/OpportunityAddProductController.getProductGroups';
import createOppLine from '@salesforce/apex/OpportunityAddProductController.createOppLine';
import getProductGroupsByFamily from '@salesforce/apex/OpportunityAddProductController.getProductGroupsByFamily';
import getOpportunityRecordTypeName from '@salesforce/apex/OpportunityAddProductController.getOpportunityRecordTypeName';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class OpportunityAddProduct extends LightningElement {

    @api recordId;

    @track showModal1 = true;
    @track showModal2 = false;
    @track loading    = false;

    @track productFamilyOptions    = [];
    @track groupNameOptions        = [];
    @track selectedProductFamilies = [];
    @track selectedGroupNames      = [];

    @track selectedProductFamily;
    @track selectedProductDescription;
    @track selectedGroupName;

    @track selectedRows       = [];
    @track selectedRowIds     = [];
    @track selectedProductIds = [];
    @track productData        = [];
    @track allProducts        = [];
    @track filteredProducts   = [];

    recordTypeName;
    searchKey  = '';
    pageSize   = 10;
    pageNumber = 1;
    totalPages = 1;

    @track groupSelected = false;

    allProductGroups = [];

    columns = [
        { label: 'Product Description', fieldName: 'Brand__c' }
    ];

    // ─────────────────────────────────────────────
    // WIRE
    // ─────────────────────────────────────────────

    @wire(getOpportunityRecordTypeName, { oppId: '$recordId' })
    wiredRecordType({ error, data }) {
        if (data) {
            this.recordTypeName = data;
        } else if (error) {
            console.error('Error fetching record type', error);
        }
    }

    // ─────────────────────────────────────────────
    // LIFECYCLE
    // ─────────────────────────────────────────────

    connectedCallback() {
        setTimeout(() => {
            this.loadProductGroups();
        }, 1200);
    }

    // ─────────────────────────────────────────────
    // DATA LOADING
    // ─────────────────────────────────────────────

    loadProductGroups() {
        this.loading = true;

        getProductGroups({ recordId: this.recordId })
            .then(result => {
                this.allProductGroups = result;

                if (result.length > 0) {
                    var group = result[0];

                    this.selectedGroupName          = group.Name;
                    this.selectedProductFamily      = group.Product_Family__c;
                    this.selectedProductDescription = group.Brand__c;
                    this.selectedGroupNames         = [group.Group_Name__c];
                    this.selectedProductFamilies    = [group.Product_Family__c];

                    this.loadProductGroupsByFamily();
                }
            })
            .catch(error => {
                console.error(error);
            })
            .finally(() => {
                this.loading = false;
            });
    }

    loadProductGroupsByFamily() {
        if (!this.selectedProductFamily) {
            this.productData = [];
            return;
        }

        this.loading = true;

        getProductGroupsByFamily({ productFamily: this.selectedProductFamily })
            .then(result => {
                this.allProducts      = result ? result.slice() : [];
                this.filteredProducts = this.allProducts.slice();
                this.totalPages       = Math.ceil(this.allProducts.length / this.pageSize);
                this.pageNumber       = 1;
                this.updatePagination();
                this._resetSelection();
            })
            .catch(error => {
                console.error('Error loading products:', error);
                this.showToast('Error', 'Failed to load products.', 'error');
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // ─────────────────────────────────────────────
    // PAGINATION
    // ─────────────────────────────────────────────

    updatePagination() {
        var start        = (this.pageNumber - 1) * this.pageSize;
        var end          = start + this.pageSize;
        this.productData = this.filteredProducts.slice(start, end);
    }

    handleNextPage() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.updatePagination();
        }
    }

    handlePreviousPage() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.updatePagination();
        }
    }

    // ─────────────────────────────────────────────
    // ROW SELECTION
    // ─────────────────────────────────────────────

    handleRowSelection(event) {
        var selected = event.detail.selectedRows;

        this.selectedProductIds = selected.map(function(row) { return row.Id; });

        this.selectedRows = selected.map(function(row) {
            return {
                Id:                row.Id,
                Product_Group__c:  row.Product_Group__c,
                Name:              row.Name,
                Brand__c:          row.Brand__c,
                Product_Family__c: row.Product_Family__c,
                PF_ASP__c:         row.PF_ASP__c,
                Product_MSP__c:    row.Product_MSP__c,
                Quantity__c:       row.Quantity__c || null
            };
        });

        this.selectedRowIds = this.selectedProductIds.slice();
    }

    handleInputChange(event) {
        var productId = event.target.dataset.id;
        var field     = event.target.dataset.field;
        var value     = parseFloat(event.target.value) || null;

        this.selectedRows = this.selectedRows.map(function(row) {
            if (row.Id === productId) {
                var updated = Object.assign({}, row);
                updated[field] = value;
                return updated;
            }
            return row;
        });
    }

    // ─────────────────────────────────────────────
    // NAVIGATION
    // ─────────────────────────────────────────────

    handleNext() {
        if (!this.selectedProductIds.length) {
            this.showToast('Warning', 'Please select at least one product.', 'warning');
            return;
        }
        this.showModal1 = false;
        this.showModal2 = true;
    }

    handleBack() {
        this.showModal2 = false;
        this.showModal1 = true;
    }

    handleClose() {
        window.history.back();
        setTimeout(() => {
            window.location.reload();
        }, 500);
    }

    // ─────────────────────────────────────────────
    // SAVE
    // ─────────────────────────────────────────────

    handleSave() {
        if (!this.selectedRows.length) {
            this.showToast('Error', 'No products selected.', 'error');
            return;
        }

        var missingQty = this.selectedRows.some(function(row) {
            return !row.Quantity__c || row.Quantity__c <= 0;
        });

        if (missingQty) {
            this.showToast(
                'Error',
                'Please enter a valid Quantity (greater than 0) for all products.',
                'error'
            );
            return;
        }

        this.loading = true;

        var productData = this.selectedRows.map(function(row) {
            return {
                productId:      row.Id,
                productGroupId: row.Product_Group__c,
                productFamily:  row.Product_Family__c,
                quantity:       row.Quantity__c,
                asp:            row.PF_ASP__c,
                msp:            row.Product_MSP__c
            };
        });

        createOppLine({
            oppId:       this.recordId,
            productData: JSON.stringify(productData)
        })
            .then(() => {
                this.showToast('Success', 'Products added successfully.', 'success');
                this.handleClose();
            })
            .catch(error => {
                console.error('Error saving:', error);
                var message = 'An unexpected error occurred.';
                if (error && error.body) {
                    if (error.body.message) {
                        message = error.body.message;
                    } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                        message = error.body.pageErrors[0].message;
                    } else if (error.body.fieldErrors) {
                        var keys = Object.keys(error.body.fieldErrors);
                        if (keys.length > 0) {
                            var errs = error.body.fieldErrors[keys[0]];
                            if (errs && errs.length > 0) {
                                message = errs[0].message;
                            }
                        }
                    }
                }
                this.showToast('Error', message, 'error');
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // ─────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────

    _resetSelection() {
        this.selectedProductIds = [];
        this.selectedRowIds     = [];
        this.selectedRows       = [];
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ─────────────────────────────────────────────
    // UI GETTERS
    // ─────────────────────────────────────────────

    get isProduct()   { return this.recordTypeName === 'Product'; }
    get isEquipment() { return this.recordTypeName === 'Equipment'; }

    get isNextDisabled() {
        return this.selectedProductIds.length === 0;
    }

    get hasProducts() {
        return this.productData && this.productData.length > 0;
    }

    get showEmptyState() {
        return (
            this.groupSelected &&
            !this.loading &&
            (!this.productData || this.productData.length === 0)
        );
    }

    get hasSelectedRows() {
        return this.selectedRows && this.selectedRows.length > 0;
    }

    get isPreviousDisabled() {
        return this.pageNumber === 1;
    }

    get isNextPageDisabled() {
        return this.pageNumber === this.totalPages;
    }

    get progressStyle() {
        var p = this.selectedProductIds.length > 0 ? 100 : 50;
        return 'width: ' + p + '%';
    }

    get step3DotClass() {
        return this.hasProducts ? 'step-dot step-dot-active' : 'step-dot step-dot-inactive';
    }

    get step3LabelClass() {
        return this.hasProducts ? 'step-label step-label-active' : 'step-label step-label-inactive';
    }

    get hasProductSelected()   { return this.selectedProductIds.length > 0; }
    get selectedProductCount() { return this.selectedProductIds.length; }
    get productCountSuffix()   { return this.selectedProductIds.length === 1 ? '' : 's'; }

    get summaryFamilyText() { return this.selectedProductFamily      || 'None'; }
    get summaryDescText()   { return this.selectedProductDescription  || 'None'; }

    get summaryProductText() {
        return this.selectedProductIds.length > 0
            ? '' + this.selectedProductIds.length
            : 'None';
    }

    get summaryProdClass() {
        return this.selectedProductIds.length > 0 ? 'summary-value-active' : 'summary-value';
    }

    get nextBtnClass() {
        return this.selectedProductIds.length > 0
            ? 'pill-btn pill-btn-next'
            : 'pill-btn pill-btn-next';
    }
}