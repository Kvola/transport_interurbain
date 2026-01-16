# -*- coding: utf-8 -*-

from odoo import http
from odoo.http import request
import json
import hmac
import hashlib


class TransportPaymentController(http.Controller):
    """Contrôleur pour les paiements Wave"""

    @http.route('/transport/payment/success/<int:payment_id>', type='http', auth='public', website=True)
    def payment_success(self, payment_id, **kw):
        """Callback de succès Wave"""
        Payment = request.env['transport.payment'].sudo()
        payment = Payment.browse(payment_id)
        
        if payment.exists() and payment.state == 'processing':
            payment.action_complete_payment()
        
        booking = payment.booking_id
        if request.env.user._is_public():
            return request.render('transport_interurbain.transport_payment_success_public', {
                'booking': booking,
            })
        
        return request.redirect(f'/my/bookings/{booking.id}')

    @http.route('/transport/payment/error/<int:payment_id>', type='http', auth='public', website=True)
    def payment_error(self, payment_id, **kw):
        """Callback d'erreur Wave"""
        Payment = request.env['transport.payment'].sudo()
        payment = Payment.browse(payment_id)
        
        if payment.exists():
            payment.action_fail_payment()
        
        booking = payment.booking_id
        if request.env.user._is_public():
            return request.render('transport_interurbain.transport_payment_error_public', {
                'booking': booking,
            })
        
        return request.redirect(f'/my/bookings/{booking.id}?payment_error=1')

    @http.route('/transport/payment/webhook/<int:payment_id>', type='json', auth='public', 
                methods=['POST'], csrf=False)
    def payment_webhook(self, payment_id, **kw):
        """Webhook Wave pour confirmation asynchrone"""
        Payment = request.env['transport.payment'].sudo()
        
        # Récupérer les données du webhook
        data = request.jsonrequest
        
        # Vérifier la signature (à adapter selon Wave)
        # signature = request.httprequest.headers.get('Wave-Signature')
        # if not self._verify_wave_signature(data, signature, payment_id):
        #     return {'error': 'Invalid signature'}
        
        # Traiter le webhook
        Payment.process_wave_webhook(payment_id, data)
        
        return {'status': 'ok'}

    def _verify_wave_signature(self, data, signature, payment_id):
        """Vérifier la signature du webhook Wave"""
        payment = request.env['transport.payment'].sudo().browse(payment_id)
        if not payment.exists():
            return False
        
        api_key = payment.company_id.wave_api_key
        if not api_key:
            return False
        
        # Calculer la signature attendue
        payload = json.dumps(data, separators=(',', ':')).encode('utf-8')
        expected_signature = hmac.new(
            api_key.encode('utf-8'),
            payload,
            hashlib.sha256
        ).hexdigest()
        
        return hmac.compare_digest(signature, expected_signature)

    # ============================================
    # API pour paiement mobile
    # ============================================

    @http.route('/api/transport/booking/create', type='json', auth='user', methods=['POST'], csrf=False)
    def api_create_booking(self, trip_id, passenger_name, passenger_phone, seat_id=None,
                           ticket_type='adult', booking_type='reservation', **kw):
        """API: Créer une réservation"""
        Trip = request.env['transport.trip'].sudo()
        Booking = request.env['transport.booking'].sudo()
        
        trip = Trip.browse(int(trip_id))
        if not trip.exists() or trip.state != 'scheduled':
            return {'error': 'Voyage non disponible'}
        
        # Calculer le prix
        if ticket_type == 'vip':
            price = trip.vip_price or trip.price
        elif ticket_type == 'child':
            price = trip.child_price or trip.price * 0.5
        else:
            price = trip.price
        
        # Créer la réservation
        booking = Booking.create({
            'trip_id': trip.id,
            'partner_id': request.env.user.partner_id.id,
            'passenger_name': passenger_name,
            'passenger_phone': passenger_phone,
            'passenger_email': kw.get('passenger_email'),
            'seat_id': int(seat_id) if seat_id else False,
            'ticket_type': ticket_type,
            'ticket_price': price,
            'booking_type': booking_type,
            'reservation_fee': trip.company_id.reservation_fee if booking_type == 'reservation' else 0,
            'boarding_stop_id': trip.route_id.departure_city_id.id,
            'alighting_stop_id': trip.route_id.arrival_city_id.id,
        })
        
        if booking_type == 'reservation':
            booking.action_reserve()
        
        return {
            'success': True,
            'booking_id': booking.id,
            'booking_reference': booking.name,
            'total_amount': booking.total_amount,
            'amount_due': booking.amount_due,
            'reservation_deadline': booking.reservation_deadline.isoformat() if booking.reservation_deadline else None,
        }

    @http.route('/api/transport/booking/<int:booking_id>/pay/wave', type='json', auth='user', 
                methods=['POST'], csrf=False)
    def api_initiate_wave_payment(self, booking_id, **kw):
        """API: Initier un paiement Wave"""
        Booking = request.env['transport.booking'].sudo()
        Payment = request.env['transport.payment'].sudo()
        
        booking = Booking.browse(booking_id)
        if not booking.exists():
            return {'error': 'Réservation non trouvée'}
        
        if booking.partner_id != request.env.user.partner_id:
            return {'error': 'Accès non autorisé'}
        
        if booking.amount_due <= 0:
            return {'error': 'Aucun montant à payer'}
        
        # Créer le paiement
        payment = Payment.create({
            'booking_id': booking.id,
            'amount': booking.amount_due,
            'payment_method': 'wave',
        })
        
        try:
            result = payment.action_process_wave_payment()
            if result and result.get('type') == 'ir.actions.act_url':
                return {
                    'success': True,
                    'payment_id': payment.id,
                    'payment_url': result.get('url'),
                }
        except Exception as e:
            return {'error': str(e)}
        
        return {'error': 'Erreur lors de l\'initiation du paiement'}

    @http.route('/api/transport/my/bookings', type='json', auth='user', methods=['POST'], csrf=False)
    def api_my_bookings(self, **kw):
        """API: Liste des réservations de l'utilisateur"""
        Booking = request.env['transport.booking'].sudo()
        partner = request.env.user.partner_id
        
        bookings = Booking.search([
            ('partner_id', '=', partner.id)
        ], order='departure_datetime desc', limit=50)
        
        return [{
            'id': b.id,
            'reference': b.name,
            'trip_reference': b.trip_id.name,
            'route': b.route_id.name,
            'departure_datetime': b.departure_datetime.isoformat() if b.departure_datetime else None,
            'seat_number': b.seat_number,
            'passenger_name': b.passenger_name,
            'total_amount': b.total_amount,
            'amount_paid': b.amount_paid,
            'amount_due': b.amount_due,
            'state': b.state,
            'booking_type': b.booking_type,
            'reservation_deadline': b.reservation_deadline.isoformat() if b.reservation_deadline else None,
        } for b in bookings]
