import { LightningElement, api } from 'lwc';
import modal from "@salesforce/resourceUrl/custommodalcss";
import { loadStyle } from "lightning/platformResourceLoader";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getNewEstimation from '@salesforce/apex/FreightEstimationService.getNewEstimation';
import getSplitOrderData from '@salesforce/apex/FreightSplitOrderController.getSplitOrderData';
import saveOrderProductQuantities from '@salesforce/apex/FreightSplitOrderController.saveOrderProductQuantities';
import saveQuantitiesAndApproveFreight from '@salesforce/apex/FreightSplitOrderController.saveQuantitiesAndApproveFreight';

import { CloseActionScreenEvent } from 'lightning/actions';






export default class FreightModalAction extends LightningElement {
_recordId;
splitOrders = [];
isLoading = false;
isQuantityChanged = false;
temp=true;
modelMessage  = '';
showModelMessage = false;

@api 
set recordId(value) {
    this._recordId = value;
    if (this._recordId) {
        this.loadInitialData();
    }
}
get recordId() {
    return this._recordId;
}

connectedCallback() {
    loadStyle(this, modal);
}



get isSaveDisabled() {
    return !this.isQuantityChanged;
}

get isApproveDisabled() {
    if (this.splitOrders.length === 0) return true;

    return this.splitOrders.some(split =>
        !split.isFreightFetched &&
        split.hasFreightIncoterm &&
        !split.transactionMode   // covers null, undefined, ''
    );
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
        total + Number(split.netWeight || 0), 0);
}

handleQuantityChange(event) {
const { splitId, productId } = event.target.dataset;
const newQuantity = Number(event.target.value);

this.splitOrders = this.splitOrders.map(split => {
    if (split.id === splitId) {
        const products = split.products.map(prod =>
            prod.id === productId
                ? { ...prod, orderQuantity: newQuantity ,  netWeight: 0,
}
                : { ...prod }
        );

        // recalc flag
       const hasZeroQuantity = products.some(p => p.orderQuantity === 0);

       

        return {
            ...split,
            products,
            isGetFreightButtonDisabled: hasZeroQuantity || !split.hasFreightIncoterm,
            transactionModeDisable: true,
            transactionMode:'',
            apiResponse: '',
            availableTransports: '', // Fixed: Changed = to :
            freightForwarderName: '',
            boxDimensions: '',
            netWeight: 0,
            approxFreight: 0,
            SplitOrderMessage:'',
            isSplitOrderMessageVisible: false,
            isFreightFetched: false
        };
    }
    return { ...split, products: [...split.products] };
});

this.isQuantityChanged = true;
}


// Helper to normalize API fields that might be object or array or undefined
normalizeArray(value) {
if (!value && value !== 0) return [];
return Array.isArray(value) ? value : [value];
}


handleTransportModeChange(event) {
    try {
        const splitId = event.currentTarget?.dataset?.splitId || null;
        const selectedMode = event?.detail?.value;

        console.log('handleTransportModeChange called', { splitId, selectedMode });

        if (!splitId) {
            console.warn('No splitId found on event.currentTarget.dataset');
            return;
        }
        if (typeof selectedMode === 'undefined') {
            console.warn('No selectedMode found on event.detail.value');
            return;
        }

        const newSplits = this.splitOrders.map(split => {
            if (split.id !== splitId) return split;

            const products = Array.isArray(split.products) ? [...split.products] : [];

            let updatedProducts = products;
            let freightForwarderName = '';
            let boxDimensions = '';
            let approxFreight = 0;
            let quotaionId ='';

            if (split.apiResponse) {
                const response = split.apiResponse;

                const cargos = this.normalizeArray(response.Cargos);
                const couriers = this.normalizeArray(response.Couriers);
                const postal = this.normalizeArray(response.Postal);
                const materials = this.normalizeArray(response.Materials);

                let quotations = [];
                if (selectedMode === 'Cargo') quotations = cargos;
                else if (selectedMode === 'Courier') quotations = couriers;
                else if (selectedMode === 'Postal') quotations = postal;

                let bestQuote = null;
                if (quotations.length > 0) {
                    bestQuote = quotations.reduce((prev, curr) => {
                        const prevVal = (prev && typeof prev.ApproxFreightINR === 'number') ? prev.ApproxFreightINR : Infinity;
                        const currVal = (curr && typeof curr.ApproxFreightINR === 'number') ? curr.ApproxFreightINR : Infinity;
                        return currVal < prevVal ? curr : prev;
                    }, quotations[0]);
                }

                try {
                    const boxes = materials
                        .flatMap(m => {
                            if (!m) return [];
                            const packing = m.PackingInfo;
                            if (!packing) return [];
                            return Array.isArray(packing) ? packing : [packing];
                        })
                        .filter(Boolean)
                        .map(pi => pi.Box)
                        .filter(Boolean);

                    boxDimensions = [...new Set(boxes)].join('\n');
                } catch (e) {
                    console.warn('Error computing boxDimensions', e);
                    boxDimensions = '';
                }

                // 🟢 NEW: Update products with idealQuantity + netWeight
                updatedProducts = products.map(prod => {
                    const matchingMaterial = materials.find(m => m.OrderProductId === prod.id);
                    if (!matchingMaterial) return prod;

                    // ideal quantity logic
                    const idealQ = typeof matchingMaterial.PreferredQuantity !== 'undefined'
                        ? matchingMaterial.PreferredQuantity
                        : matchingMaterial.Quantity;

                    // 🟢 netWeight assignment based on selected transport mode
                    let netWeight = 0;
                    if (selectedMode === 'Cargo' ) {
                        netWeight = matchingMaterial.WeightKGCargo;
                    } else if (selectedMode === 'Courier' ) {
                        netWeight = matchingMaterial.WeightKGCourier;
                    } else if (selectedMode === 'Postal' ) {
                        netWeight = matchingMaterial.WeightKGPostal;
                    }

                    return {
                        ...prod,
                        idealQuantity: idealQ,
                        netWeight: netWeight
                    };
                });

                freightForwarderName = bestQuote
                    ? ( bestQuote.FF || bestQuote.Company || bestQuote.Name ||'')
                    : '';
                quotaionId = bestQuote.QuotaionId ? bestQuote.QuotaionId : ''
                // ✅ Choose freight value dynamically based on split.currencyType
                if (bestQuote && split.currencyType) {
                    const currency = split.currencyType.toUpperCase();
                    let freightValue;
                    console.log('currency : ',currency);

                    if (currency === 'INR') freightValue = bestQuote.ApproxFreightINR;
                    else if (currency === 'EUR') freightValue = bestQuote.ApproxFreightEuro;
                    else if (currency === 'USD') freightValue = bestQuote.ApproxFreightDollars;
                    else if (currency === 'GBP') freightValue = bestQuote.ApproxFreightGBP;

                    approxFreight = typeof freightValue === 'number' ? freightValue : 0;
                } else {
                    approxFreight = 0;
                }
            }
            
            return {
                ...split,
                products: updatedProducts,
                freightForwarderName,
                boxDimensions,
                approxFreight,
                quotaionId:quotaionId,
                transactionMode: selectedMode,
                isGetFreightButtonDisabled: true //as we alredy have frights for all availble transport mode
                // when we called get freight unless there is a change in quantity no new freight needed
                // to be get for given temp split order
            };
        });

        // 🔁 Reactive refresh
        this.splitOrders = JSON.parse(JSON.stringify(newSplits));

        const updatedSplit = this.splitOrders.find(s => s.id === splitId);
        console.log('updated split after change', JSON.stringify(updatedSplit, null, 2));
    } catch (err) {
        console.error('Error in handleTransportModeChange:', err?.message || err, err);
    }
}





handleGetFreight(event) {
    try {
        const splitId = event.target.dataset.splitId;
        const splitIndex = this.splitOrders.findIndex(s => s.id === splitId);

        if (splitIndex === -1) {
            console.warn(`Split with id ${splitId} not found`);
            return;
        }

        // Defensive clone of the target split
        const existingSplit = JSON.parse(JSON.stringify(this.splitOrders[splitIndex]));

        const orderProducts = existingSplit.products.map(p => ({
            id: p.id,
            quantity: p.orderQuantity
        }));

        this.isLoading = true;
        console.log('orderProducts : ', orderProducts);

        getNewEstimation({
            splitOrderNumber: existingSplit.splitOrderNumber,
            plantCode: existingSplit.plantCode,
            orderProducts: orderProducts
        })
        .then(result => {
            const response = JSON.parse(result);
            console.log('API response =>', response);

            // Normalize transport types to arrays
            const cargos   = response.Cargos   ? (Array.isArray(response.Cargos)   ? response.Cargos   : [response.Cargos])   : [];
            const couriers = response.Couriers ? (Array.isArray(response.Couriers) ? response.Couriers : [response.Couriers]) : [];
            const postal   = response.Postal   ? (Array.isArray(response.Postal)   ? response.Postal   : [response.Postal])   : [];

            // Build available transport options
            const availableTransportsOptions = [];
            if (cargos.length > 0)   availableTransportsOptions.push({ label: 'Cargo', value: 'Cargo' });
            if (couriers.length > 0) availableTransportsOptions.push({ label: 'Courier', value: 'Courier' });
            if (postal.length > 0)   availableTransportsOptions.push({ label: 'Postal', value: 'Postal' });

            console.log('availableTransportsOptions : ', availableTransportsOptions);

            // Build updated split safely
            const updatedSplit = {
                ...existingSplit, // keep existing data
                apiResponse: response,
                availableTransports: availableTransportsOptions,
                transactionModeDisable: false,

                // Reset certain fields
                freightForwarderName: '',
                boxDimensions: '',
                netWeight: 0,
                approxFreight: 0,

                // Keep identifiers safe
                id: existingSplit.id,
                plantCode: existingSplit.plantCode,
                splitOrderNumber: existingSplit.splitOrderNumber,
                isGetFreightButtonDisabled:true,

                // Derived fields
                SplitOrderMessage:
                    availableTransportsOptions?.length > 0
                        ? ''
                        : 'no frights availble.contact admin for further help',
                isSplitOrderMessageVisible: !(availableTransportsOptions?.length > 0),
              isFreightFetched:  availableTransportsOptions?.length > 0 //this is set to true as there will be case where there is no freight available and we need to allow user to approve fright as it is.
            };

            // Apply update
            this.splitOrders[splitIndex] = updatedSplit;

            // ✅ Force reactivity with deep clone
           // this.splitOrders = JSON.parse(JSON.stringify(this.splitOrders));

            console.log('Updated splitOrders =>', JSON.stringify(this.splitOrders, null, 2));
        })
        .catch(error => {
            console.error('Error fetching freight:', error);
        })
        .finally(() => {
            this.isLoading = false;
        });
    } catch (err) {
        console.error('Unexpected error in handleGetFreight:', err);
        this.isLoading = false;
    }
}




loadInitialData() {
    this.isLoading = true;

    getSplitOrderData({ orderId: this.recordId })
        .then(result => {

            if (!result) {
                this.showToast('Error', 'No data returned from SAP', 'error');
                return;
            }

            let parsedData;
            try {
                parsedData = JSON.parse(result);
                console.log('parsedData : ', parsedData);

            } catch (e) {
                console.error('Failed to parse SAP response:', e);
                this.showToast('Error', 'Invalid SAP response format', 'error');
                return;
            }

            // Check if this is an error response
            if (parsedData.error) {
                console.log('SAP Error:-->', parsedData.error.code, parsedData.error.message);
                this.showToast(`SAP Error ${parsedData.error.code}`, parsedData.error.message, 'error');
                this.splitOrders = [];
                return;
            }

            // Success: array from SAP
            if (Array.isArray(parsedData)) {

                this.splitOrders = parsedData.map((split, splitIndex) => {

                    // PRODUCT LEVEL — dynamic auto-merge
                    const products = (split.products || []).map((prod, idx) => ({
                        ...prod, // ← NEW fields from Apex auto-included
                        id: prod.orderProductId,
                        orderProduct: prod.orderProductNumber || '',
                        orderQuantity: prod.orderQuantity || 0,
                        idealQuantity: prod.idealQuantity || 0,
                        isFirstInGroup: idx === 0,
                        netWeight: prod.netWeight || 0,
                        orderProductName: prod.orderProductName || '',
                    }));

                    const hasZeroQuantity = products.some(p => p.orderQuantity === 0);
                    // check if any product uses restricted incoterms
                    const hasFreightIncoterm = products.some(
                        p => p.incoterm && ['CIF', 'C&F'].includes(p.incoterm.toUpperCase())
                    );

                    // SPLIT LEVEL — dynamic auto-merge
                    return {
                        ...split, // ← NEW Apex fields auto-included
                        id: split.splitOrderNumber || `SP-${splitIndex + 1}`,
                        splitOrderNumber: split.splitOrderNumber || `SP-${splitIndex + 1}`,
                        plantCode: split.plantCode || '',
                        transactionMode: null,
                        freightForwarderName: split.freightForwarderName || 'dummy',
                        boxDimensions: split.boxDimensions || 'dummy',
                        approxFreight: split.approxFreight || 0,
                        isFreightFetched: false,
                        transactionModeDisable: true,
                        isGetFreightButtonDisabled: hasZeroQuantity || !hasFreightIncoterm,
                        hasFreightIncoterm: hasFreightIncoterm,
                        rowCount: products.length,
                        products
                    };
                });

                console.log('this.splitOrders =>', JSON.stringify(this.splitOrders, null, 2));

            } else {
                console.warn('Unexpected SAP response format', parsedData);
                this.showToast('Error', 'Unexpected SAP response format', 'error');
            }
        })
        .catch(error => {
            console.error('Error fetching split order data:', error);
            this.showToast('Error', 'Error fetching split order data', 'error');
            this.splitOrders = [];
        })
        .finally(() => {
            this.isLoading = false;
        });
}




handleSaveQuantity() {
    // Run validation; if validation fails, stop here
    if (!this.validateRequiredFields(true)) {
        return;
    }

    this.isLoading = true;

    try {
        // Prepare payload
        const payload = this.splitOrders.flatMap(split =>
            (split.products || []).map(prod => ({
                orderProductId: prod.id,
                orderQuantity: Number(prod.orderQuantity || 0),
            }))
        );

        console.log('Payload =>', JSON.stringify(payload));

        // Call Apex method
        saveOrderProductQuantities({ 
            orderId: this.recordId, 
            products: payload 
        })
        .then(() => {
            this.isQuantityChanged = false;
            this.showToast('Success', 'Order quantities have been saved successfully.', 'success');
        })
        .catch(error => {
            console.error('Error saving quantities:', error);
            const message = error?.body?.message || error.message || 'Failed to save order quantities.';
            this.showToast('Error', message, 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });

    } catch (error) {
        console.error('Unexpected error in handleSaveQuantity:', error);
        this.showToast('Error', 'An unexpected error occurred while saving quantities.', 'error');
        this.isLoading = false;
    }
}


handleApproveFreight() {
    // Run validation; if validation fails, exit early
    if (!this.validateRequiredFields()) {
        return;
    }

    this.isLoading = true;

    try {
        // Prepare payloads
        const quantityPayload = this.splitOrders.flatMap(split =>
            split.products.map(prod => ({
                orderProductId: prod.id,
                orderQuantity: Number(prod.orderQuantity)
            }))
        );

        const freightPayload = this.splitOrders.filter(split => split.hasFreightIncoterm) // ⬅️ skip  non CIF/CNF
            .map(split => ({
                splitOrderNumber: split.splitOrderNumber,
                transactionMode: split.transactionMode,
                quotaionId: split.quotaionId,
                rfqNumber: split.apiResponse?.RFQNumber || null,
                estimationId: split.apiResponse?.EstimationId || null,
                orderProductIds: split.products.map(prod => prod.id),
                approxFreight: Number(split.approxFreight) || null,
                currencyType: split.currencyType
            }));


        // Call Apex
        saveQuantitiesAndApproveFreight({ 
            orderId: this.recordId, 
            products: quantityPayload,
            splitData: freightPayload
        })
        .then(() => {
            this.showToast(
                'Freight Approved',
                'The freight details have been approved successfully.',
                'success'
            );
            this.closeModal();
        })
        .catch(error => {
            console.error('Error approving freight:', error);
            const message = error?.body?.message || error.message || 'An unexpected error occurred while approving freight.';
            this.showToast('Error', message, 'error');
        })
        .finally(() => {
            this.isLoading = false;
            //window.location.reload();

        });
    } catch (error) {
        // Catch any unexpected synchronous errors
        console.error('Unexpected error in handleApproveFreight:', error);
        this.showToast('Error', 'An unexpected error occurred.', 'error');
        this.isLoading = false;
    }
}



validateRequiredFields(validateQuantityOnly) {
    let isValid = true;

    // Validate all required lightning-input fields
    this.template.querySelectorAll('lightning-input').forEach(input => {
        if (input.required && !input.value) {
            input.setCustomValidity('This field is required');
            input.reportValidity();
            isValid = false;
        } else {
            input.setCustomValidity('');
            input.reportValidity();
        }
    });

        // Only validate comboboxes if validateQuantityOnly is false
        if (!validateQuantityOnly) {
            this.template.querySelectorAll('lightning-combobox').forEach(combo => {

                const splitId = combo.dataset.splitId;
                const split = this.splitOrders.find(s => s.id === splitId);

                // If the split hasFreightIncoterm as false , skip validation
                if (split && !split.hasFreightIncoterm) {
                    combo.setCustomValidity('');
                    combo.reportValidity();
                    return; // Skip this combobox entirely
                }

                // Normal validation
                if (combo.required && !combo.value) {
                    combo.setCustomValidity('This field is required');
                    combo.reportValidity();
                    isValid = false;
                } else {
                    combo.setCustomValidity('');
                    combo.reportValidity();
                }
            });
        }

    return isValid;
}


handleCancel() {
    this.closeModal();
}





showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
}

closeModal() {
    this.dispatchEvent(new CloseActionScreenEvent());
}



}