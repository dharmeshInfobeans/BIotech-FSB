import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class Test extends LightningElement {
    @api recordId;
    
    splitOrders = []; // @track is no longer needed here
    isLoading = false;
    isQuantityChanged = false;

    connectedCallback() {
        this.loadInitialData();
    }

    get transportOptions() {
        return [
            { label: 'Cargo', value: 'Cargo' },
            { label: 'Courier', value: 'Courier' },
            { label: 'Postal', value: 'Postal' },
        ];
    }

    get isSaveDisabled() {
        return !this.isQuantityChanged;
    }

    get isApproveDisabled() {
        if (this.splitOrders.length === 0) return true;
        return this.splitOrders.some(split => !split.isFreightFetched);
    }

    get totalOrderQuantity() {
        return this.splitOrders.reduce((total, split) =>
            total + split.products.reduce((subTotal, prod) => subTotal + Number(prod.orderQuantity || 0), 0), 0);
    }

    get totalIdealQuantity() {
        return this.splitOrders.reduce((total, split) =>
            total + split.products.reduce((subTotal, prod) => subTotal + Number(prod.idealQuantity || 0), 0), 0);
    }

    get totalNetWeight() {
        return this.splitOrders.reduce((total, split) =>
            total + split.products.reduce((subTotal, prod) => subTotal + Number(prod.netWeight || 0), 0), 0);
    }

    handleQuantityChange(event) {
        const { splitId, productId } = event.target.dataset;
        const newQuantity = event.target.value;

        const split = this.splitOrders.find(s => s.id === splitId);
        if (split) {
            const product = split.products.find(p => p.id === productId);
            if (product) {
                product.orderQuantity = newQuantity;
                this.isQuantityChanged = true;
                this.updateGetFreightButtonState(splitId);
            }
        }
    }

    handleTransportModeChange(event) {
        const { splitId, productId } = event.target.dataset;
        const selectedMode = event.target.value;

        const split = this.splitOrders.find(s => s.id === splitId);
        if (split) {
            const product = split.products.find(p => p.id === productId);
            if (product) {
                product.transportMode = selectedMode;
            }
            this.updateGetFreightButtonState(splitId);
        }
    }

    handleGetFreight(event) {
        const { splitId } = event.target.dataset;
        this.isLoading = true;

        setTimeout(() => {
            try {
                const split = this.splitOrders.find(s => s.id === splitId);
                if (split) {
                    const freightData = this.getMockFreightData(split.id);
                    split.products.forEach((prod, index) => {
                        const data = freightData[index];
                        prod.plantCode = data.plantCode;
                        prod.freightForwarderName = data.freightForwarderName;
                        prod.boxDimensions = data.boxDimensions;
                        prod.netWeight = data.netWeight;
                        prod.approxFreight = data.approxFreight;
                    });
                    split.isFreightFetched = true;
                    this.showToast('Success', `Freight details fetched for ${split.id}`, 'success');
                }
            } catch (error) {
                this.showToast('Error fetching freight', error.message, 'error');
            } finally {
                this.isLoading = false;
            }
        }, 1500);
    }

    handleSaveQuantity() {
        this.isLoading = true;
        setTimeout(() => {
            this.isLoading = false;
            this.isQuantityChanged = false;
            this.showToast('Success', 'Order quantities have been saved.', 'success');
        }, 1000);
    }

    handleApproveFreight() {
        this.isLoading = true;
        setTimeout(() => {
            this.isLoading = false;
            this.showToast('Freight Approved', 'The freight details have been approved successfully.', 'success');
            this.closeModal();
        }, 1500);
    }

    handleCancel() {
        this.closeModal();
    }

    loadInitialData() {
        this.isLoading = true;
        setTimeout(() => {
            const mockData = [
                {
                    id: 'SP-1',
                    products: [
                        { id: 'OP-64879', orderProduct: 'OP-64879', idealQuantity: 45 },
                        { id: 'OP-64880', orderProduct: 'OP-64880', idealQuantity: 37 },
                    ]
                },
                {
                    id: 'SP-2',
                    products: [
                        { id: 'OP-64881', orderProduct: 'OP-64881', idealQuantity: 19 },
                        { id: 'OP-64882', orderProduct: 'OP-64882', idealQuantity: 12 },
                    ]
                }
            ];

            this.splitOrders = mockData.map(split => {
                const products = split.products.map((prod, index) => ({
                    ...prod,
                    orderQuantity: '',
                    transportMode: '',
                    plantCode: '',
                    freightForwarderName: '',
                    boxDimensions: '',
                    netWeight: '',
                    approxFreight: '',
                    isFirstInGroup: index === 0,
                }));
                return { ...split, products, rowCount: products.length, isFreightFetched: false, isGetFreightDisabled: true, };
            });
            this.isLoading = false;
        }, 1000);
    }

    updateGetFreightButtonState(splitId) {
        const split = this.splitOrders.find(s => s.id === splitId);
        if (split) {
            const allDataEntered = split.products.every(p =>
                p.transportMode &&
                p.orderQuantity &&
                Number(p.orderQuantity) > 0
            );
            split.isGetFreightDisabled = !allDataEntered;
        }
    }

    getMockFreightData(splitId) {
        if (splitId === 'SP-1') {
            return [
                { plantCode: '1100', freightForwarderName: 'Epidbiomed LTD', boxDimensions: '61x41x47', netWeight: 7, approxFreight: '2523 INR' },
                { plantCode: '2100', freightForwarderName: 'Epidbiomed LTD', boxDimensions: 'N/A', netWeight: 5, approxFreight: '2523 INR' }
            ];
        }
        if (splitId === 'SP-2') {
            return [
                { plantCode: '5100', freightForwarderName: 'Veil Cosmetics', boxDimensions: '61x33x34', netWeight: 2, approxFreight: '2244 INR' },
                { plantCode: '7100', freightForwarderName: 'Veil Cosmetics', boxDimensions: 'N/A', netWeight: 4, approxFreight: '2244 INR' }
            ];
        }
        return [];
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}