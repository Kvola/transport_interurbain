# -*- coding: utf-8 -*-

from odoo import http
from odoo.http import request
from odoo.addons.portal.controllers.portal import CustomerPortal, pager as portal_pager


class TransportPortal(CustomerPortal):
    """Portail client pour le transport"""

    def _prepare_home_portal_values(self, counters):
        """Ajouter le compteur de réservations au portail"""
        values = super()._prepare_home_portal_values(counters)
        if 'transport_booking_count' in counters:
            Booking = request.env['transport.booking']
            values['transport_booking_count'] = Booking.search_count([
                ('partner_id', '=', request.env.user.partner_id.id)
            ])
        return values

    @http.route(['/my/bookings', '/my/bookings/page/<int:page>'], 
                type='http', auth='user', website=True)
    def portal_my_bookings(self, page=1, sortby=None, filterby=None, **kw):
        """Liste des réservations du client"""
        Booking = request.env['transport.booking']
        partner = request.env.user.partner_id
        
        domain = [('partner_id', '=', partner.id)]
        
        # Filtres
        searchbar_filters = {
            'all': {'label': 'Tous', 'domain': []},
            'pending': {'label': 'En attente', 'domain': [('state', 'in', ['draft', 'reserved'])]},
            'confirmed': {'label': 'Confirmés', 'domain': [('state', '=', 'confirmed')]},
            'completed': {'label': 'Terminés', 'domain': [('state', '=', 'completed')]},
        }
        if not filterby:
            filterby = 'all'
        domain += searchbar_filters[filterby]['domain']
        
        # Tri
        searchbar_sortings = {
            'date': {'label': 'Date de départ', 'order': 'departure_datetime desc'},
            'name': {'label': 'Référence', 'order': 'name'},
            'state': {'label': 'État', 'order': 'state'},
        }
        if not sortby:
            sortby = 'date'
        order = searchbar_sortings[sortby]['order']
        
        # Compteur
        booking_count = Booking.search_count(domain)
        
        # Pager
        pager = portal_pager(
            url='/my/bookings',
            url_args={'sortby': sortby, 'filterby': filterby},
            total=booking_count,
            page=page,
            step=10,
        )
        
        # Récupérer les réservations
        bookings = Booking.search(
            domain,
            order=order,
            limit=10,
            offset=pager['offset'],
        )
        
        # Statistiques
        all_bookings = Booking.search([('partner_id', '=', partner.id)])
        stats = {
            'total': len(all_bookings),
            'confirmed': len(all_bookings.filtered(lambda b: b.state == 'confirmed')),
            'pending': len(all_bookings.filtered(lambda b: b.state in ['draft', 'reserved'])),
            'spent': sum(all_bookings.filtered(lambda b: b.state in ['confirmed', 'completed']).mapped('total_amount')),
        }
        
        return request.render('transport_interurbain.portal_my_bookings', {
            'bookings': bookings,
            'page_name': 'transport_bookings',
            'pager': pager,
            'searchbar_filters': searchbar_filters,
            'filterby': filterby,
            'searchbar_sortings': searchbar_sortings,
            'sortby': sortby,
            'stats': stats,
        })

    @http.route('/my/bookings/<int:booking_id>', type='http', auth='user', website=True)
    def portal_booking_detail(self, booking_id, **kw):
        """Détail d'une réservation"""
        Booking = request.env['transport.booking']
        booking = Booking.browse(booking_id)
        
        # Vérifier les droits
        if not booking.exists() or booking.partner_id != request.env.user.partner_id:
            return request.redirect('/my/bookings')
        
        return request.render('transport_interurbain.portal_booking_detail', {
            'booking': booking,
            'page_name': booking.name,
        })

    @http.route('/transport/booking/<int:booking_id>/pay', type='http', auth='user', website=True)
    def booking_pay(self, booking_id, **kw):
        """Initier le paiement d'une réservation"""
        Booking = request.env['transport.booking'].sudo()
        Payment = request.env['transport.payment'].sudo()
        
        booking = Booking.browse(booking_id)
        
        if not booking.exists() or booking.partner_id != request.env.user.partner_id:
            return request.redirect('/my/bookings')
        
        if booking.amount_due <= 0:
            return request.redirect(f'/my/bookings/{booking.id}')
        
        # Créer le paiement Wave
        payment = Payment.create({
            'booking_id': booking.id,
            'amount': booking.amount_due,
            'payment_method': 'wave',
        })
        
        # Initier le paiement Wave
        try:
            result = payment.action_process_wave_payment()
            if result and result.get('type') == 'ir.actions.act_url':
                return request.redirect(result.get('url'))
        except Exception as e:
            # En cas d'erreur, proposer le paiement en agence
            pass
        
        # Fallback: page de confirmation pour paiement en agence
        return request.render('transport_interurbain.portal_booking_detail', {
            'booking': booking,
            'page_name': booking.name,
            'payment_error': True,
        })

    @http.route('/transport/booking/<int:booking_id>/ticket', type='http', auth='user', website=True)
    def booking_ticket(self, booking_id, **kw):
        """Télécharger le ticket PDF"""
        Booking = request.env['transport.booking'].sudo()
        booking = Booking.browse(booking_id)
        
        if not booking.exists() or booking.partner_id != request.env.user.partner_id:
            return request.redirect('/my/bookings')
        
        if booking.state not in ['confirmed', 'checked_in']:
            return request.redirect(f'/my/bookings/{booking.id}')
        
        # Générer le PDF
        pdf_content, _ = request.env['ir.actions.report'].sudo()._render_qweb_pdf(
            'transport_interurbain.action_report_ticket', [booking.id]
        )
        
        filename = f"Ticket-{booking.name}.pdf"
        pdfhttpheaders = [
            ('Content-Type', 'application/pdf'),
            ('Content-Length', len(pdf_content)),
            ('Content-Disposition', f'attachment; filename="{filename}"'),
        ]
        
        return request.make_response(pdf_content, headers=pdfhttpheaders)

    @http.route('/transport/booking/<int:booking_id>/cancel', type='http', auth='user', website=True)
    def booking_cancel(self, booking_id, **kw):
        """Annuler une réservation"""
        Booking = request.env['transport.booking'].sudo()
        booking = Booking.browse(booking_id)
        
        if not booking.exists() or booking.partner_id != request.env.user.partner_id:
            return request.redirect('/my/bookings')
        
        if booking.state in ['draft', 'reserved', 'confirmed']:
            booking.action_cancel()
        
        return request.redirect('/my/bookings')
