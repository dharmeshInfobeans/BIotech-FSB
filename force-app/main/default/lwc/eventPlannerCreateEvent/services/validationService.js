/**
 * ValidationService - Centralized validation logic for event forms
 */

import { VALIDATION_MESSAGES } from '../constants/validationMessages';
import { EVENT_TYPES, CALL_TYPES, PLACEHOLDER_VALUES } from '../constants/eventTypes';

export class ValidationService {
    /**
     * Validates Leave event form data
     * @param {EventFormData} formData - Form data to validate
     * @returns {string[]} Array of error messages
     */
    static validateLeaveEvent(formData) {
        const errors = [];

        if (!formData.notes) {
            errors.push('Notes is required');
        }

        if (!formData.leaveType) {
            errors.push('Leave type is required');
        }

        return errors;
    }

    /**
     * Validates Holiday event form data
     * @param {EventFormData} formData - Form data to validate
     * @returns {string[]} Array of error messages
     */
    static validateHolidayEvent(formData) {
        const errors = [];

        if (!formData.notes) {
            errors.push('Notes is required');
        }

        return errors;
    }

    /**
     * Validates Out of Office event form data
     * @param {EventFormData} formData - Form data to validate
     * @returns {string[]} Array of error messages
     */
    static validateOutOfOfficeEvent(formData) {
        const errors = [];

        if (!formData.notes) {
            errors.push('Notes is required');
        }

        if (!formData.reviewCallType) {
            errors.push('Review call type is required');
        }

        return errors;
    }

    /**
     * Validates Customer Visit event form data
     * @param {EventFormData} formData - Form data to validate
     * @returns {string[]} Array of error messages
     */
    static validateCustomerVisit(formData) {
        const errors = [];

        if (!formData.subject) {
            errors.push('Subject is required');
        }

        if (!formData.callType || formData.callType === PLACEHOLDER_VALUES.SELECT) {
            errors.push('Call type is required');
        }

        if (!formData.meetingType || formData.meetingType === PLACEHOLDER_VALUES.SELECT) {
            errors.push('Meeting type is required');
        }

        if (formData.callType === CALL_TYPES.IN_CLINIC_BRANDING &&
            (!formData.subCallType || formData.subCallType === PLACEHOLDER_VALUES.SELECT)) {
            errors.push(VALIDATION_MESSAGES.SUB_CALL_TYPE_REQUIRED);
        }

        return errors;
    }

    /**
     * Validates Phakic Training specific requirements
     * @param {EventFormData} formData - Form data to validate
     * @returns {string[]} Array of error messages
     */
    static validatePhakicTraining(formData) {
        const errors = [];

        // Check if Level Type is selected
        if (!formData.levelType || formData.levelType === '' || formData.levelType === PLACEHOLDER_VALUES.SELECT) {
            errors.push(VALIDATION_MESSAGES.LEVEL_TYPE_REQUIRED);
        }

        // Validate Phakic products - only products with "PHAKIC" or "Phakic" in name are allowed
        if (formData.product) {
            const products = formData.product.includes(';')
                ? formData.product.split(';')
                : [formData.product];

            const hasNonPhakicProduct = products.some(
                p => !p.toUpperCase().includes('PHAKIC')
            );

            if (hasNonPhakicProduct) {
                errors.push(VALIDATION_MESSAGES.PHAKIC_PRODUCTS_ONLY);
            }
        }

        return errors;
    }

    /**
     * Main validation method - routes to appropriate validator based on event type
     * @param {EventFormData} formData - Form data to validate
     * @returns {string[]} Array of error messages
     */
    static validateForm(formData) {
        let errors = [];

        // Validate based on event type
        switch (formData.eventType) {
            case EVENT_TYPES.LEAVE:
                errors = errors.concat(this.validateLeaveEvent(formData));
                break;
            case EVENT_TYPES.HOLIDAY:
                errors = errors.concat(this.validateHolidayEvent(formData));
                break;
            case EVENT_TYPES.OUT_OF_OFFICE:
                errors = errors.concat(this.validateOutOfOfficeEvent(formData));
                break;
            case EVENT_TYPES.CUSTOMER_VISIT:
                errors = errors.concat(this.validateCustomerVisit(formData));

                // Additional validation for Phakic Training
                if (formData.callType === CALL_TYPES.PHAKIC_TRAINING) {
                    errors = errors.concat(this.validatePhakicTraining(formData));
                }
                break;
            default:
                errors.push('Invalid event type');
        }

        return errors;
    }
}