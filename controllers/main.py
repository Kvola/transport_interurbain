# -*- coding: utf-8 -*-

from odoo import http
from odoo.http import request
from datetime import datetime, timedelta


class TransportController(http.Controller):
    """Contrôleur principal pour le transport interurbain"""

    @http.route('/transport', type='http', auth='public', website=True)
    def transport_home(self, **kw):
        """Page d'accueil du transport"""
        City = request.env['transport.city'].sudo()
        Company = request.env['transport.company'].sudo()
        Trip = request.env['transport.trip'].sudo()
        
        today = datetime.now().date()
        
        cities = City.search([('active', '=', True)], order='is_major_city desc, name')
        companies = Company.search([('state', '=', 'active')], order='rating desc', limit=8)
        today_trips = Trip.search([
            ('departure_date', '=', today),
            ('state', '=', 'scheduled'),
            ('is_published', '=', True),
            ('available_seats', '>', 0),
        ], order='departure_datetime', limit=9)
        
        return request.render('transport_interurbain.transport_portal_home', {
            'cities': cities,
            'companies': companies,
            'today_trips': today_trips,
            'today': today.strftime('%Y-%m-%d'),
        })

    @http.route('/transport/search', type='http', auth='public', website=True)
    def transport_search(self, departure_id=None, arrival_id=None, departure_date=None, 
                         return_date=None, **kw):
        """Recherche de voyages"""
        if not departure_id or not arrival_id or not departure_date:
            return request.redirect('/transport')
        
        City = request.env['transport.city'].sudo()
        Route = request.env['transport.route'].sudo()
        Trip = request.env['transport.trip'].sudo()
        
        departure_city = City.browse(int(departure_id))
        arrival_city = City.browse(int(arrival_id))
        
        if not departure_city.exists() or not arrival_city.exists():
            return request.redirect('/transport')
        
        # Chercher les itinéraires correspondants
        routes = Route.search([
            ('departure_city_id', '=', departure_city.id),
            ('arrival_city_id', '=', arrival_city.id),
            ('state', '=', 'active'),
        ])
        
        # Chercher les voyages
        trips = Trip.search([
            ('route_id', 'in', routes.ids),
            ('departure_date', '=', departure_date),
            ('state', '=', 'scheduled'),
            ('is_published', '=', True),
        ], order='departure_datetime')
        
        # Voyages retour si demandé
        return_trips = None
        if return_date:
            return_routes = Route.search([
                ('departure_city_id', '=', arrival_city.id),
                ('arrival_city_id', '=', departure_city.id),
                ('state', '=', 'active'),
            ])
            return_trips = Trip.search([
                ('route_id', 'in', return_routes.ids),
                ('departure_date', '=', return_date),
                ('state', '=', 'scheduled'),
                ('is_published', '=', True),
            ], order='departure_datetime')
        
        return request.render('transport_interurbain.transport_search_results', {
            'departure_city': departure_city,
            'arrival_city': arrival_city,
            'departure_date': departure_date,
            'return_date': return_date,
            'trips': trips,
            'return_trips': return_trips,
        })

    @http.route('/transport/trip/<int:trip_id>', type='http', auth='public', website=True)
    def trip_detail(self, trip_id, **kw):
        """Détail d'un voyage pour réservation"""
        Trip = request.env['transport.trip'].sudo()
        trip = Trip.browse(trip_id)
        
        if not trip.exists() or trip.state != 'scheduled':
            return request.redirect('/transport')
        
        # Préparer les sièges
        seats = []
        booked_seat_ids = trip.booking_ids.filtered(
            lambda b: b.state in ['reserved', 'confirmed']
        ).mapped('seat_id.id')
        
        for seat in trip.bus_id.seat_ids.sorted('seat_number'):
            seats.append({
                'id': seat.id,
                'seat_number': seat.seat_number,
                'seat_type': seat.seat_type,
                'is_booked': seat.id in booked_seat_ids,
            })
        
        user = request.env.user if request.env.user._is_internal() or request.env.user._is_portal() else None
        
        return request.render('transport_interurbain.transport_trip_detail', {
            'trip': trip,
            'seats': seats,
            'user': user.partner_id if user else None,
        })

    @http.route('/transport/booking/create', type='http', auth='user', website=True, methods=['POST'])
    def create_booking(self, **kw):
        """Créer une réservation"""
        Trip = request.env['transport.trip'].sudo()
        Booking = request.env['transport.booking'].sudo()
        Seat = request.env['transport.bus.seat'].sudo()
        
        trip_id = int(kw.get('trip_id', 0))
        trip = Trip.browse(trip_id)
        
        if not trip.exists() or trip.state != 'scheduled':
            return request.redirect('/transport')
        
        # Vérifier le siège
        seat_id = int(kw.get('seat_id', 0))
        seat = Seat.browse(seat_id) if seat_id else None
        
        # Calculer le prix
        ticket_type = kw.get('ticket_type', 'adult')
        if ticket_type == 'vip':
            price = trip.vip_price or trip.price
        elif ticket_type == 'child':
            price = trip.child_price or trip.price * 0.5
        else:
            price = trip.price
        
        # Calculer supplément bagages
        luggage_weight = float(kw.get('luggage_weight', 0))
        luggage_extra = 0
        if trip.manage_luggage and luggage_weight > trip.luggage_included_kg:
            luggage_extra = (luggage_weight - trip.luggage_included_kg) * trip.extra_luggage_price
        
        booking_type = kw.get('booking_type', 'reservation')
        
        # Créer la réservation
        booking_vals = {
            'trip_id': trip.id,
            'partner_id': request.env.user.partner_id.id,
            'passenger_name': kw.get('passenger_name'),
            'passenger_phone': kw.get('passenger_phone'),
            'passenger_email': kw.get('passenger_email'),
            'seat_id': seat.id if seat else False,
            'ticket_type': ticket_type,
            'ticket_price': price,
            'luggage_weight': luggage_weight,
            'luggage_count': int(kw.get('luggage_count', 1)),
            'booking_type': booking_type,
            'reservation_fee': trip.transport_company_id.reservation_fee if booking_type == 'reservation' else 0,
            'boarding_stop_id': trip.route_id.departure_city_id.id,
            'alighting_stop_id': trip.route_id.arrival_city_id.id,
        }
        
        # Gérer aller-retour
        return_trip_id = kw.get('return_trip_id')
        return_seat_id = kw.get('return_seat_id')
        
        if return_trip_id:
            return_trip = Trip.browse(int(return_trip_id))
            if return_trip.exists() and return_trip.state == 'scheduled':
                booking_vals['is_round_trip'] = True
                booking_vals['return_trip_id'] = return_trip.id
        
        booking = Booking.create(booking_vals)
        
        # Si aller-retour, créer aussi le billet retour
        if return_trip_id and booking.return_trip_id:
            return_seat = Seat.browse(int(return_seat_id)) if return_seat_id else None
            
            return_booking = Booking.create({
                'trip_id': booking.return_trip_id.id,
                'partner_id': request.env.user.partner_id.id,
                'passenger_name': kw.get('passenger_name'),
                'passenger_phone': kw.get('passenger_phone'),
                'passenger_email': kw.get('passenger_email'),
                'seat_id': return_seat.id if return_seat else False,
                'ticket_type': ticket_type,
                'ticket_price': booking.return_trip_id.price,
                'luggage_weight': luggage_weight,
                'luggage_count': int(kw.get('luggage_count', 1)),
                'booking_type': booking_type,
                'reservation_fee': booking.return_trip_id.transport_company_id.reservation_fee if booking_type == 'reservation' else 0,
                'boarding_stop_id': booking.return_trip_id.route_id.departure_city_id.id,
                'alighting_stop_id': booking.return_trip_id.route_id.arrival_city_id.id,
            })
            
            # Lier les deux billets
            booking.return_booking_id = return_booking.id
        
        if booking_type == 'reservation':
            booking.action_reserve()
            if booking.return_booking_id:
                booking.return_booking_id.action_reserve()
            return request.redirect(f'/my/bookings/{booking.id}')
        else:
            # Rediriger vers le paiement Wave
            return request.redirect(f'/transport/booking/{booking.id}/pay')

    @http.route('/transport/booking/<int:booking_id>/rate', type='http', auth='user', website=True, methods=['GET', 'POST'])
    def rate_booking(self, booking_id, **kw):
        """Évaluer un voyage terminé"""
        Booking = request.env['transport.booking'].sudo()
        booking = Booking.browse(booking_id)
        
        if not booking.exists() or booking.partner_id != request.env.user.partner_id:
            return request.redirect('/my/bookings')
        
        if booking.state != 'completed':
            return request.redirect(f'/my/bookings/{booking.id}')
        
        if request.httprequest.method == 'POST':
            rating = int(kw.get('rating', 0))
            comment = kw.get('comment', '')
            
            if 1 <= rating <= 5:
                booking.write({
                    'rating': rating,
                    'rating_comment': comment,
                })
            
            return request.redirect(f'/my/bookings/{booking.id}')
        
        return request.render('transport_interurbain.portal_rate_booking', {
            'booking': booking,
        })

    @http.route('/transport/company/<int:company_id>', type='http', auth='public', website=True)
    def company_page(self, company_id, **kw):
        """Page d'une compagnie"""
        Company = request.env['transport.company'].sudo()
        Trip = request.env['transport.trip'].sudo()
        
        company = Company.browse(company_id)
        if not company.exists() or company.state != 'active':
            return request.redirect('/transport')
        
        trips = Trip.search([
            ('transport_company_id', '=', company.id),
            ('state', '=', 'scheduled'),
            ('is_published', '=', True),
            ('departure_datetime', '>=', datetime.now()),
        ], order='departure_datetime', limit=20)
        
        return request.render('transport_interurbain.transport_company_page', {
            'company': company,
            'trips': trips,
        })

    @http.route('/transport/trips/today', type='http', auth='public', website=True)
    def public_today_trips(self, **kw):
        """Page publique des voyages du jour"""
        Trip = request.env['transport.trip'].sudo()
        
        trips = Trip.search([
            ('departure_date', '=', datetime.now().date()),
            ('state', '=', 'scheduled'),
            ('is_published', '=', True),
        ], order='departure_datetime')
        
        return request.render('transport_interurbain.transport_public_trips', {
            'trips': trips,
        })

    @http.route('/transport/companies', type='http', auth='public', website=True)
    def companies_list(self, **kw):
        """Liste des compagnies de transport"""
        Company = request.env['transport.company'].sudo()
        
        companies = Company.search([('state', '=', 'active')], order='rating desc, name')
        
        return request.render('transport_interurbain.transport_companies_list', {
            'companies': companies,
        })

    @http.route('/my/transport/dashboard', type='http', auth='user', website=True)
    def user_dashboard(self, **kw):
        """Tableau de bord enrichi pour l'usager"""
        Booking = request.env['transport.booking'].sudo()
        partner = request.env.user.partner_id
        
        # Récupérer toutes les réservations
        all_bookings = Booking.search([('partner_id', '=', partner.id)])
        completed_bookings = all_bookings.filtered(lambda b: b.state == 'completed')
        
        # Prochain voyage
        next_booking = Booking.search([
            ('partner_id', '=', partner.id),
            ('state', 'in', ['confirmed', 'reserved']),
            ('departure_datetime', '>=', datetime.now()),
        ], order='departure_datetime', limit=1)
        
        # Réservations récentes
        recent_bookings = Booking.search([
            ('partner_id', '=', partner.id),
        ], order='create_date desc', limit=5)
        
        # Calculer statistiques
        total_km = sum(b.route_id.distance_km for b in completed_bookings if b.route_id)
        total_spent = sum(b.total_amount for b in all_bookings.filtered(lambda b: b.state in ['confirmed', 'completed']))
        
        # Compagnie préférée
        company_counts = {}
        for b in completed_bookings:
            if b.transport_company_id:
                company_counts[b.transport_company_id.name] = company_counts.get(b.transport_company_id.name, 0) + 1
        favorite_company = max(company_counts, key=company_counts.get) if company_counts else 'N/A'
        
        # Itinéraires fréquents
        route_counts = {}
        for b in completed_bookings:
            if b.route_id:
                route_name = b.route_id.name
                route_counts[route_name] = route_counts.get(route_name, 0) + 1
        frequent_routes = [{'name': k, 'count': v} for k, v in sorted(route_counts.items(), key=lambda x: -x[1])]
        
        stats = {
            'total_trips': len(completed_bookings),
            'total_km': total_km,
            'total_spent': total_spent,
            'favorite_company': favorite_company,
        }
        
        return request.render('transport_interurbain.portal_user_dashboard', {
            'stats': stats,
            'next_booking': next_booking,
            'recent_bookings': recent_bookings,
            'frequent_routes': frequent_routes,
        })

    # ============================================
    # API JSON pour applications mobiles/frontend
    # ============================================

    @http.route('/api/transport/cities', type='json', auth='public', methods=['POST'], csrf=False)
    def api_get_cities(self, **kw):
        """API: Liste des villes"""
        cities = request.env['transport.city'].sudo().search([('active', '=', True)])
        return [{
            'id': c.id,
            'name': c.name,
            'code': c.code,
            'region': c.region,
            'is_major': c.is_major_city,
        } for c in cities]

    @http.route('/api/transport/routes', type='json', auth='public', methods=['POST'], csrf=False)
    def api_get_routes(self, departure_id=None, arrival_id=None, **kw):
        """API: Liste des itinéraires"""
        domain = [('state', '=', 'active')]
        if departure_id:
            domain.append(('departure_city_id', '=', int(departure_id)))
        if arrival_id:
            domain.append(('arrival_city_id', '=', int(arrival_id)))
        
        routes = request.env['transport.route'].sudo().search(domain)
        return [{
            'id': r.id,
            'name': r.name,
            'departure_city': r.departure_city_id.name,
            'arrival_city': r.arrival_city_id.name,
            'distance_km': r.distance_km,
            'duration_hours': r.estimated_duration,
            'base_price': r.base_price,
        } for r in routes]

    @http.route('/api/transport/trips', type='json', auth='public', methods=['POST'], csrf=False)
    def api_get_trips(self, route_id=None, date=None, company_id=None, **kw):
        """API: Liste des voyages"""
        domain = [
            ('state', '=', 'scheduled'),
            ('is_published', '=', True),
        ]
        if route_id:
            domain.append(('route_id', '=', int(route_id)))
        if date:
            domain.append(('departure_date', '=', date))
        if company_id:
            domain.append(('transport_company_id', '=', int(company_id)))
        
        trips = request.env['transport.trip'].sudo().search(domain, order='departure_datetime')
        return [{
            'id': t.id,
            'reference': t.name,
            'company': t.transport_company_id.name,
            'route': t.route_id.name,
            'departure_datetime': t.departure_datetime.isoformat() if t.departure_datetime else None,
            'arrival_datetime': t.arrival_datetime.isoformat() if t.arrival_datetime else None,
            'meeting_point': t.meeting_point,
            'price': t.price,
            'vip_price': t.vip_price,
            'child_price': t.child_price,
            'total_seats': t.total_seats,
            'available_seats': t.available_seats,
            'bus_amenities': {
                'ac': t.bus_id.has_ac,
                'wifi': t.bus_id.has_wifi,
                'tv': t.bus_id.has_tv,
                'usb': t.bus_id.has_usb,
            },
        } for t in trips]

    @http.route('/api/transport/trip/<int:trip_id>/seats', type='json', auth='public', methods=['POST'], csrf=False)
    def api_get_trip_seats(self, trip_id, **kw):
        """API: Sièges disponibles pour un voyage"""
        trip = request.env['transport.trip'].sudo().browse(trip_id)
        if not trip.exists():
            return {'error': 'Voyage non trouvé'}
        
        booked_seat_ids = trip.booking_ids.filtered(
            lambda b: b.state in ['reserved', 'confirmed']
        ).mapped('seat_id.id')
        
        return [{
            'id': s.id,
            'number': s.seat_number,
            'type': s.seat_type,
            'position': s.position,
            'available': s.id not in booked_seat_ids,
        } for s in trip.bus_id.seat_ids.sorted('seat_number')]

    @http.route('/api/transport/companies', type='json', auth='public', methods=['POST'], csrf=False)
    def api_get_companies(self, **kw):
        """API: Liste des compagnies"""
        companies = request.env['transport.company'].sudo().search([('state', '=', 'active')])
        return [{
            'id': c.id,
            'name': c.name,
            'phone': c.phone,
            'email': c.email,
            'rating': c.rating,
            'rating_count': c.rating_count,
            'allow_online_payment': c.allow_online_payment,
        } for c in companies]
