/**
 * Date utility functions
 */

export class DateUtils {
    /**
     * Formats a date string to DD/MM/YYYY format
     * @param {string} dateString - Date in MM/DD/YYYY format
     * @returns {string} Date in DD/MM/YYYY format
     */
    static formatDateForDisplay(dateString) {
        if (!dateString) return '';

        const parts = dateString.split('/');
        if (parts.length !== 3) return dateString;

        const [month, day, year] = parts;
        return `${day}/${month}/${year}`;
    }

    /**
     * Generates current date in MM/DD/YYYY format
     * @returns {string} Current date
     */
    static getCurrentDate() {
        const today = new Date();
        const dd = today.getDate() < 10 ? '0' + today.getDate() : today.getDate();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const yyyy = today.getFullYear();

        return `${mm}/${dd}/${yyyy}`;
    }

    /**
     * Parses MM/DD/YYYY date string to Date object
     * @param {string} dateString - Date in MM/DD/YYYY format
     * @returns {Date} Date object
     */
    static parseDate(dateString) {
        const [month, day, year] = dateString.split('/');
        return new Date(year, month - 1, day);
    }
}