/** @odoo-module **/

document.addEventListener('DOMContentLoaded', function() {
    // Seat selection functionality
    const seatGrid = document.querySelector('.o_transport_seat_grid');
    if (seatGrid) {
        initSeatSelection(seatGrid);
    }
    
    // Round trip toggle
    const roundTripCheckbox = document.getElementById('round_trip');
    const returnDateGroup = document.getElementById('return_date_group');
    if (roundTripCheckbox && returnDateGroup) {
        roundTripCheckbox.addEventListener('change', function() {
            returnDateGroup.style.display = this.checked ? 'block' : 'none';
            const returnDateInput = returnDateGroup.querySelector('input');
            if (returnDateInput) {
                returnDateInput.required = this.checked;
            }
        });
    }
    
    // Auto-update departure date minimum
    const departureDateInput = document.querySelector('input[name="departure_date"]');
    if (departureDateInput) {
        const today = new Date().toISOString().split('T')[0];
        departureDateInput.min = today;
        if (!departureDateInput.value) {
            departureDateInput.value = today;
        }
        
        departureDateInput.addEventListener('change', function() {
            const returnDateInput = document.querySelector('input[name="return_date"]');
            if (returnDateInput) {
                returnDateInput.min = this.value;
            }
        });
    }
    
    // City swap button
    const swapBtn = document.getElementById('swap_cities');
    if (swapBtn) {
        swapBtn.addEventListener('click', function(e) {
            e.preventDefault();
            const departureSelect = document.querySelector('select[name="departure_id"]');
            const arrivalSelect = document.querySelector('select[name="arrival_id"]');
            if (departureSelect && arrivalSelect) {
                const tempValue = departureSelect.value;
                departureSelect.value = arrivalSelect.value;
                arrivalSelect.value = tempValue;
            }
        });
    }
});

function initSeatSelection(seatGrid) {
    const seats = seatGrid.querySelectorAll('.o_transport_seat.available');
    const seatInput = document.getElementById('seat_id');
    const seatDisplay = document.getElementById('selected_seat_display');
    
    seats.forEach(seat => {
        seat.addEventListener('click', function() {
            // Remove selection from other seats
            seats.forEach(s => s.classList.remove('selected'));
            
            // Select this seat
            this.classList.add('selected');
            
            // Update hidden input
            if (seatInput) {
                seatInput.value = this.dataset.seatId;
            }
            
            // Update display
            if (seatDisplay) {
                seatDisplay.textContent = this.dataset.seatNumber;
                seatDisplay.closest('.seat-selection-info')?.classList.remove('d-none');
            }
        });
    });
}

// Booking form validation
function validateBookingForm(form) {
    const requiredFields = form.querySelectorAll('[required]');
    let isValid = true;
    
    requiredFields.forEach(field => {
        if (!field.value.trim()) {
            field.classList.add('is-invalid');
            isValid = false;
        } else {
            field.classList.remove('is-invalid');
        }
    });
    
    // Validate phone number
    const phoneField = form.querySelector('input[name="passenger_phone"]');
    if (phoneField && phoneField.value) {
        const phoneRegex = /^[\d\s\+\-\.]{8,20}$/;
        if (!phoneRegex.test(phoneField.value)) {
            phoneField.classList.add('is-invalid');
            isValid = false;
        }
    }
    
    // Validate email
    const emailField = form.querySelector('input[name="passenger_email"]');
    if (emailField && emailField.value) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(emailField.value)) {
            emailField.classList.add('is-invalid');
            isValid = false;
        }
    }
    
    return isValid;
}

// Price calculation
function updateTotalPrice() {
    const ticketType = document.querySelector('input[name="ticket_type"]:checked');
    const luggageWeight = document.querySelector('input[name="luggage_weight"]');
    const basePriceEl = document.getElementById('base_price');
    const totalPriceEl = document.getElementById('total_price');
    const luggageExtraEl = document.getElementById('luggage_extra');
    
    if (!ticketType || !basePriceEl || !totalPriceEl) return;
    
    let basePrice = parseFloat(basePriceEl.dataset.price) || 0;
    let vipPrice = parseFloat(basePriceEl.dataset.vipPrice) || basePrice;
    let childPrice = parseFloat(basePriceEl.dataset.childPrice) || basePrice * 0.5;
    
    let price = basePrice;
    if (ticketType.value === 'vip') {
        price = vipPrice;
    } else if (ticketType.value === 'child') {
        price = childPrice;
    }
    
    // Add luggage extra
    let luggageExtra = 0;
    if (luggageWeight && luggageExtraEl) {
        const weight = parseFloat(luggageWeight.value) || 0;
        const includedKg = parseFloat(luggageWeight.dataset.includedKg) || 15;
        const extraPrice = parseFloat(luggageWeight.dataset.extraPrice) || 500;
        
        if (weight > includedKg) {
            luggageExtra = (weight - includedKg) * extraPrice;
        }
        
        luggageExtraEl.textContent = formatCurrency(luggageExtra);
        luggageExtraEl.closest('.luggage-extra-row').style.display = luggageExtra > 0 ? '' : 'none';
    }
    
    const total = price + luggageExtra;
    totalPriceEl.textContent = formatCurrency(total);
    
    // Update hidden input if exists
    const totalInput = document.querySelector('input[name="total_amount"]');
    if (totalInput) {
        totalInput.value = total;
    }
}

function formatCurrency(amount) {
    return new Intl.NumberFormat('fr-FR', {
        style: 'currency',
        currency: 'XOF',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0,
    }).format(amount);
}

// Initialize price calculation listeners
document.addEventListener('DOMContentLoaded', function() {
    const ticketTypeInputs = document.querySelectorAll('input[name="ticket_type"]');
    const luggageWeightInput = document.querySelector('input[name="luggage_weight"]');
    
    ticketTypeInputs.forEach(input => {
        input.addEventListener('change', updateTotalPrice);
    });
    
    if (luggageWeightInput) {
        luggageWeightInput.addEventListener('input', updateTotalPrice);
    }
    
    // Initial calculation
    if (ticketTypeInputs.length > 0) {
        updateTotalPrice();
    }
});

// Countdown timer for reservation expiry
function initReservationCountdown() {
    const countdownElements = document.querySelectorAll('.reservation-countdown');
    
    countdownElements.forEach(el => {
        const deadline = new Date(el.dataset.deadline);
        
        const updateCountdown = () => {
            const now = new Date();
            const diff = deadline - now;
            
            if (diff <= 0) {
                el.innerHTML = '<span class="text-danger">Expirée</span>';
                return;
            }
            
            const hours = Math.floor(diff / (1000 * 60 * 60));
            const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
            const seconds = Math.floor((diff % (1000 * 60)) / 1000);
            
            let display = '';
            if (hours > 0) {
                display += `${hours}h `;
            }
            display += `${minutes}m ${seconds}s`;
            
            if (diff < 3600000) { // Less than 1 hour
                el.classList.add('text-danger');
            } else if (diff < 7200000) { // Less than 2 hours
                el.classList.add('text-warning');
            }
            
            el.textContent = display;
        };
        
        updateCountdown();
        setInterval(updateCountdown, 1000);
    });
}

document.addEventListener('DOMContentLoaded', initReservationCountdown);
