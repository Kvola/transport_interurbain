# -*- coding: utf-8 -*-

from odoo import http
from odoo.http import request
import logging

_logger = logging.getLogger(__name__)


class TicketShareController(http.Controller):
    """Contrôleur pour le partage public de billets"""

    @http.route('/ticket/share/<string:share_token>', type='http', auth='public', 
                website=True, csrf=False)
    def view_shared_ticket(self, share_token, **kw):
        """
        Page publique pour visualiser un billet partagé.
        Accessible sans authentification via un token unique.
        """
        Booking = request.env['transport.booking'].sudo()
        
        booking = Booking.search([
            ('share_token', '=', share_token),
            ('state', 'in', ['confirmed', 'checked_in', 'completed']),
        ], limit=1)
        
        if not booking:
            return request.render('transport_interurbain.ticket_share_not_found', {})
        
        # Préparer les données du billet
        ticket_data = {
            'booking': booking,
            'ticket_number': booking.name,
            'passenger_name': booking.traveler_name or booking.passenger_name,
            'passenger_phone': booking.traveler_phone or booking.passenger_phone,
            'trip': booking.trip_id,
            'company': booking.transport_company_id,
            'route': booking.trip_id.route_id,
            'seat': booking.seat_number or 'Non assigné',
            'departure_datetime': booking.trip_id.departure_datetime,
            'meeting_point': booking.trip_id.meeting_point,
            'qr_code': booking.qr_code.decode('utf-8') if booking.qr_code else None,
            'is_for_other': booking.is_for_other,
            'buyer_name': booking.buyer_name if booking.is_for_other else None,
            'status': booking.state,
            'status_label': dict(booking._fields['state'].selection).get(booking.state),
        }
        
        return request.render('transport_interurbain.ticket_share_view', ticket_data)

    @http.route('/ticket/share/<string:share_token>/qr', type='http', auth='public', csrf=False)
    def get_shared_ticket_qr(self, share_token, **kw):
        """
        Retourne l'image QR code du billet partagé.
        """
        Booking = request.env['transport.booking'].sudo()
        
        booking = Booking.search([
            ('share_token', '=', share_token),
            ('state', 'in', ['confirmed', 'checked_in', 'completed']),
        ], limit=1)
        
        if not booking or not booking.qr_code:
            return request.not_found()
        
        import base64
        qr_data = base64.b64decode(booking.qr_code)
        
        return request.make_response(
            qr_data,
            headers=[
                ('Content-Type', 'image/png'),
                ('Content-Disposition', f'inline; filename=ticket_{booking.name}_qr.png'),
            ]
        )

    @http.route('/ticket/share/<string:share_token>/download', type='http', auth='public', csrf=False)
    def download_shared_ticket(self, share_token, **kw):
        """
        Télécharge le billet au format PDF.
        """
        Booking = request.env['transport.booking'].sudo()
        
        booking = Booking.search([
            ('share_token', '=', share_token),
            ('state', 'in', ['confirmed', 'checked_in', 'completed']),
        ], limit=1)
        
        if not booking:
            return request.not_found()
        
        # Générer le PDF du ticket
        pdf_content, _ = request.env['ir.actions.report'].sudo()._render_qweb_pdf(
            'transport_interurbain.report_ticket',
            [booking.id]
        )
        
        return request.make_response(
            pdf_content,
            headers=[
                ('Content-Type', 'application/pdf'),
                ('Content-Disposition', f'attachment; filename=Billet_{booking.name}.pdf'),
            ]
        )
