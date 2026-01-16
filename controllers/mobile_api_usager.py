# -*- coding: utf-8 -*-
"""
API REST Mobile pour les Usagers - Transport Interurbain
Version: 1.0.0

Cette API permet aux usagers de:
- S'inscrire et s'authentifier
- Consulter leur profil et QR code unique
- Rechercher des voyages disponibles
- Réserver et acheter des tickets
- Consulter leurs tickets et historique
- Recevoir des reçus de paiement

Endpoints:
- POST /api/v1/transport/usager/auth/register - Inscription
- POST /api/v1/transport/usager/auth/login - Connexion
- POST /api/v1/transport/usager/auth/logout - Déconnexion
- POST /api/v1/transport/usager/auth/refresh - Rafraîchir token
- GET /api/v1/transport/usager/profile - Profil utilisateur
- PUT /api/v1/transport/usager/profile - Modifier profil
- GET /api/v1/transport/usager/qrcode - QR Code unique
- GET /api/v1/transport/usager/cities - Liste des villes
- GET /api/v1/transport/usager/companies - Liste des compagnies
- POST /api/v1/transport/usager/trips/search - Rechercher voyages
- GET /api/v1/transport/usager/trips/<id> - Détails voyage
- POST /api/v1/transport/usager/bookings - Créer réservation
- GET /api/v1/transport/usager/bookings - Mes réservations
- GET /api/v1/transport/usager/bookings/<id> - Détails réservation
- POST /api/v1/transport/usager/bookings/<id>/pay - Payer réservation
- GET /api/v1/transport/usager/bookings/<id>/ticket - Ticket avec QR
- GET /api/v1/transport/usager/bookings/<id>/receipt - Reçu de paiement
- POST /api/v1/transport/usager/bookings/<id>/cancel - Annuler réservation
"""

import logging
import base64
from datetime import datetime, timedelta

from odoo import http, _, fields
from odoo.http import request

from .api_utils import (
    APIErrorCodes,
    api_response, api_error, api_validation_error,
    InputValidator,
    generate_api_token,
    require_passenger_auth,
    api_exception_handler,
    rate_limit,
    get_client_ip,
    format_currency,
    format_datetime,
    format_date,
    TOKEN_EXPIRY_HOURS,
)

_logger = logging.getLogger(__name__)


class TransportUsagerMobileAPI(http.Controller):
    """Contrôleur API REST pour l'application mobile des usagers"""

    # ==================== PING / HEALTH CHECK ====================

    @http.route('/api/v1/transport/ping', type='http', auth='none', 
                methods=['GET'], csrf=False, cors='*')
    def ping(self, **kw):
        """
        Endpoint de vérification de la disponibilité du serveur
        Utilisé pour le mode offline des applications mobiles
        """
        import json
        from datetime import datetime
        
        response_data = json.dumps({
            'success': True,
            'message': 'pong',
            'timestamp': datetime.now().isoformat(),
            'server': 'transport_interurbain',
        })
        
        return Response(
            response_data,
            status=200,
            headers=[
                ('Content-Type', 'application/json'),
                ('Access-Control-Allow-Origin', '*'),
            ]
        )

    # ==================== AUTHENTIFICATION ====================

    @http.route('/api/v1/transport/usager/auth/register', type='json', auth='none', 
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @rate_limit(max_requests=10, window=60)
    def register(self, **kw):
        """
        Inscription d'un nouvel usager
        
        Body:
            - name: Nom complet (requis)
            - phone: Numéro de téléphone (requis)
            - email: Email (optionnel)
            - pin_code: Code PIN 4 chiffres (requis)
            - id_type: Type de pièce d'identité (optionnel)
            - id_number: Numéro de pièce (optionnel)
            - date_of_birth: Date de naissance YYYY-MM-DD (optionnel)
            - gender: 'male' ou 'female' (optionnel)
        """
        data = request.jsonrequest
        
        # Validation
        errors = []
        
        if not data.get('name'):
            errors.append("Le nom est requis")
        
        valid_phone, phone_result = InputValidator.validate_phone(data.get('phone'))
        if not valid_phone:
            errors.append(phone_result)
        
        valid_pin, pin_result = InputValidator.validate_pin(data.get('pin_code'))
        if not valid_pin:
            errors.append(pin_result)
        
        if data.get('email'):
            valid_email, email_result = InputValidator.validate_email(data.get('email'))
            if not valid_email:
                errors.append(email_result)
        
        if errors:
            return api_validation_error(errors)
        
        Passenger = request.env['transport.passenger'].sudo()
        
        # Vérifier si le téléphone existe déjà
        existing = Passenger.search([('phone', '=', phone_result)], limit=1)
        if existing:
            return api_error(
                message="Ce numéro de téléphone est déjà enregistré",
                code=APIErrorCodes.VALIDATION_ERROR,
            )
        
        # Créer le passager
        try:
            passenger_vals = {
                'name': data['name'].strip(),
                'phone': phone_result,
                'email': data.get('email', '').strip() if data.get('email') else False,
                'pin_code': pin_result,
                'id_type': data.get('id_type'),
                'id_number': data.get('id_number'),
                'gender': data.get('gender'),
            }
            
            if data.get('date_of_birth'):
                valid_date, date_result = InputValidator.validate_date(data['date_of_birth'])
                if valid_date:
                    passenger_vals['date_of_birth'] = date_result
            
            passenger = Passenger.create(passenger_vals)
            
            # Générer le token d'authentification
            token = generate_api_token()
            passenger.write({
                'mobile_token': token,
                'mobile_token_expiry': fields.Datetime.now() + timedelta(hours=TOKEN_EXPIRY_HOURS),
            })
            
            return api_response(
                data={
                    'token': token,
                    'expires_at': (datetime.now() + timedelta(hours=TOKEN_EXPIRY_HOURS)).isoformat(),
                    'passenger': self._format_passenger(passenger),
                },
                message="Inscription réussie"
            )
            
        except Exception as e:
            _logger.exception(f"Erreur inscription: {e}")
            return api_error(
                message="Erreur lors de l'inscription",
                code=APIErrorCodes.SERVER_ERROR,
                details={'error': str(e)}
            )

    @http.route('/api/v1/transport/usager/auth/login', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @rate_limit(max_requests=20, window=60)
    def login(self, **kw):
        """
        Connexion d'un usager
        
        Body:
            - phone: Numéro de téléphone (requis)
            - pin_code: Code PIN 4 chiffres (requis)
        """
        data = request.jsonrequest
        
        valid_phone, phone_result = InputValidator.validate_phone(data.get('phone'))
        if not valid_phone:
            return api_error(
                message=phone_result,
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        if not data.get('pin_code'):
            return api_error(
                message="Code PIN requis",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        Passenger = request.env['transport.passenger'].sudo()
        
        passenger = Passenger.search([
            ('phone', '=', phone_result),
            ('active', '=', True),
        ], limit=1)
        
        if not passenger:
            return api_error(
                message="Compte non trouvé",
                code=APIErrorCodes.INVALID_CREDENTIALS
            )
        
        if passenger.pin_code != str(data['pin_code']):
            return api_error(
                message="Code PIN incorrect",
                code=APIErrorCodes.INVALID_CREDENTIALS
            )
        
        # Générer un nouveau token
        token = generate_api_token()
        passenger.write({
            'mobile_token': token,
            'mobile_token_expiry': fields.Datetime.now() + timedelta(hours=TOKEN_EXPIRY_HOURS),
        })
        
        return api_response(
            data={
                'token': token,
                'expires_at': (datetime.now() + timedelta(hours=TOKEN_EXPIRY_HOURS)).isoformat(),
                'passenger': self._format_passenger(passenger),
            },
            message="Connexion réussie"
        )

    @http.route('/api/v1/transport/usager/auth/logout', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def logout(self, passenger=None, **kw):
        """Déconnexion"""
        passenger.write({
            'mobile_token': False,
            'mobile_token_expiry': False,
        })
        return api_response(message="Déconnexion réussie")

    @http.route('/api/v1/transport/usager/auth/refresh', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def refresh_token(self, passenger=None, **kw):
        """Rafraîchir le token d'authentification"""
        token = generate_api_token()
        passenger.write({
            'mobile_token': token,
            'mobile_token_expiry': fields.Datetime.now() + timedelta(hours=TOKEN_EXPIRY_HOURS),
        })
        
        return api_response(
            data={
                'token': token,
                'expires_at': (datetime.now() + timedelta(hours=TOKEN_EXPIRY_HOURS)).isoformat(),
            },
            message="Token rafraîchi"
        )

    # ==================== PROFIL ====================

    @http.route('/api/v1/transport/usager/profile', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def get_profile(self, passenger=None, **kw):
        """Obtenir le profil de l'usager"""
        return api_response(
            data={'passenger': self._format_passenger(passenger, include_stats=True)}
        )

    @http.route('/api/v1/transport/usager/profile', type='json', auth='none',
                methods=['PUT', 'PATCH'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def update_profile(self, passenger=None, **kw):
        """Modifier le profil de l'usager"""
        data = request.jsonrequest
        
        update_vals = {}
        errors = []
        
        if 'name' in data:
            if data['name']:
                update_vals['name'] = data['name'].strip()
            else:
                errors.append("Le nom ne peut pas être vide")
        
        if 'email' in data:
            if data['email']:
                valid, result = InputValidator.validate_email(data['email'])
                if valid:
                    update_vals['email'] = result
                else:
                    errors.append(result)
            else:
                update_vals['email'] = False
        
        if 'date_of_birth' in data:
            if data['date_of_birth']:
                valid, result = InputValidator.validate_date(data['date_of_birth'])
                if valid:
                    update_vals['date_of_birth'] = result
                else:
                    errors.append(result)
        
        if 'gender' in data and data['gender'] in ['male', 'female', False]:
            update_vals['gender'] = data['gender']
        
        if 'id_type' in data:
            update_vals['id_type'] = data['id_type']
        
        if 'id_number' in data:
            update_vals['id_number'] = data['id_number']
        
        if 'preferred_seat_position' in data:
            update_vals['preferred_seat_position'] = data['preferred_seat_position']
        
        if errors:
            return api_validation_error(errors)
        
        if update_vals:
            passenger.write(update_vals)
        
        return api_response(
            data={'passenger': self._format_passenger(passenger)},
            message="Profil mis à jour"
        )

    @http.route('/api/v1/transport/usager/profile/change-pin', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def change_pin(self, passenger=None, **kw):
        """Changer le code PIN"""
        data = request.jsonrequest
        
        if passenger.pin_code != str(data.get('current_pin', '')):
            return api_error(
                message="Code PIN actuel incorrect",
                code=APIErrorCodes.INVALID_CREDENTIALS
            )
        
        valid, result = InputValidator.validate_pin(data.get('new_pin'))
        if not valid:
            return api_error(
                message=result,
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        passenger.write({'pin_code': result})
        
        return api_response(message="Code PIN modifié avec succès")

    # ==================== QR CODE ====================

    @http.route('/api/v1/transport/usager/qrcode', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def get_qrcode(self, passenger=None, **kw):
        """
        Obtenir le QR Code unique de l'usager
        
        Ce QR Code identifie de manière unique l'usager et permet
        à l'agent d'embarquement de vérifier tous ses tickets.
        """
        return api_response(
            data={
                'qr_code_data': f"PASSENGER:{passenger.unique_token}",
                'qr_code_image': passenger.unique_qr_code.decode('utf-8') if passenger.unique_qr_code else None,
                'passenger_name': passenger.name,
                'passenger_phone': passenger.phone,
            }
        )

    # ==================== VILLES ET COMPAGNIES ====================

    @http.route('/api/v1/transport/usager/cities', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @rate_limit(max_requests=100, window=60)
    def get_cities(self, **kw):
        """Liste des villes disponibles"""
        City = request.env['transport.city'].sudo()
        
        cities = City.search([('active', '=', True)], order='is_major_city desc, name')
        
        return api_response(
            data={
                'cities': [{
                    'id': city.id,
                    'name': city.name,
                    'region': city.region,
                    'is_major': city.is_major_city,
                } for city in cities]
            }
        )

    @http.route('/api/v1/transport/usager/companies', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @rate_limit(max_requests=100, window=60)
    def get_companies(self, **kw):
        """Liste des compagnies de transport"""
        Company = request.env['transport.company'].sudo()
        
        companies = Company.search([('state', '=', 'active')], order='rating desc, name')
        
        return api_response(
            data={
                'companies': [{
                    'id': company.id,
                    'name': company.name,
                    'logo': company.logo.decode('utf-8') if company.logo else None,
                    'rating': company.rating,
                    'phone': company.phone,
                    'email': company.email,
                    'description': company.description,
                } for company in companies]
            }
        )

    # ==================== RECHERCHE DE VOYAGES ====================

    @http.route('/api/v1/transport/usager/trips/search', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @rate_limit(max_requests=60, window=60)
    def search_trips(self, **kw):
        """
        Rechercher des voyages disponibles
        
        Body:
            - departure_city_id: ID ville de départ (requis)
            - arrival_city_id: ID ville d'arrivée (requis)
            - departure_date: Date de départ YYYY-MM-DD (requis)
            - return_date: Date de retour YYYY-MM-DD (optionnel)
            - passengers: Nombre de passagers (défaut: 1)
            - company_id: Filtrer par compagnie (optionnel)
        """
        data = request.jsonrequest
        
        # Validation
        errors = []
        
        valid, departure_city_id = InputValidator.validate_positive_int(
            data.get('departure_city_id'), "Ville de départ"
        )
        if not valid:
            errors.append(departure_city_id)
        
        valid, arrival_city_id = InputValidator.validate_positive_int(
            data.get('arrival_city_id'), "Ville d'arrivée"
        )
        if not valid:
            errors.append(arrival_city_id)
        
        valid, departure_date = InputValidator.validate_date(data.get('departure_date'))
        if not valid:
            errors.append(departure_date)
        
        if errors:
            return api_validation_error(errors)
        
        passengers = int(data.get('passengers', 1))
        
        Route = request.env['transport.route'].sudo()
        Trip = request.env['transport.trip'].sudo()
        
        # Chercher les itinéraires
        routes = Route.search([
            ('departure_city_id', '=', departure_city_id),
            ('arrival_city_id', '=', arrival_city_id),
            ('state', '=', 'active'),
        ])
        
        if not routes:
            return api_response(
                data={'trips': [], 'return_trips': []},
                message="Aucun itinéraire trouvé"
            )
        
        # Domaine de base pour les voyages
        domain = [
            ('route_id', 'in', routes.ids),
            ('departure_date', '=', departure_date),
            ('state', '=', 'scheduled'),
            ('is_published', '=', True),
            ('available_seats', '>=', passengers),
        ]
        
        if data.get('company_id'):
            domain.append(('transport_company_id', '=', int(data['company_id'])))
        
        trips = Trip.search(domain, order='departure_datetime')
        
        # Voyages retour si demandé
        return_trips_data = []
        if data.get('return_date'):
            valid, return_date = InputValidator.validate_date(data['return_date'])
            if valid:
                return_routes = Route.search([
                    ('departure_city_id', '=', arrival_city_id),
                    ('arrival_city_id', '=', departure_city_id),
                    ('state', '=', 'active'),
                ])
                
                if return_routes:
                    return_domain = [
                        ('route_id', 'in', return_routes.ids),
                        ('departure_date', '=', return_date),
                        ('state', '=', 'scheduled'),
                        ('is_published', '=', True),
                        ('available_seats', '>=', passengers),
                    ]
                    
                    if data.get('company_id'):
                        return_domain.append(('transport_company_id', '=', int(data['company_id'])))
                    
                    return_trips = Trip.search(return_domain, order='departure_datetime')
                    return_trips_data = [self._format_trip(t) for t in return_trips]
        
        return api_response(
            data={
                'trips': [self._format_trip(t) for t in trips],
                'return_trips': return_trips_data,
            }
        )

    @http.route('/api/v1/transport/usager/trips/<int:trip_id>', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    def get_trip_detail(self, trip_id, **kw):
        """Détails d'un voyage"""
        Trip = request.env['transport.trip'].sudo()
        
        trip = Trip.browse(trip_id)
        if not trip.exists() or trip.state != 'scheduled':
            return api_error(
                message="Voyage non trouvé ou non disponible",
                code=APIErrorCodes.TRIP_NOT_AVAILABLE
            )
        
        return api_response(
            data={'trip': self._format_trip(trip, include_seats=True)}
        )

    # ==================== RÉSERVATIONS ====================

    @http.route('/api/v1/transport/usager/bookings', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def create_booking(self, passenger=None, **kw):
        """
        Créer une nouvelle réservation (pour soi-même ou pour un autre passager)
        
        Body:
            - trip_id: ID du voyage (requis)
            - seat_id: ID du siège (optionnel)
            - ticket_type: 'adult', 'child', 'vip' (défaut: adult)
            - luggage_weight: Poids des bagages en kg (optionnel)
            - booking_type: 'reservation' ou 'purchase' (défaut: reservation)
            
            Pour acheter pour quelqu'un d'autre (optionnel):
            - for_other: true si achat pour un tiers
            - other_passenger: {
                - name: Nom du passager (requis)
                - phone: Téléphone du passager (requis)
                - email: Email (optionnel)
                - id_type: Type de pièce d'identité (optionnel)
                - id_number: Numéro de pièce (optionnel)
              }
        """
        data = request.jsonrequest
        
        # Validation
        valid, trip_id = InputValidator.validate_positive_int(data.get('trip_id'), "Voyage")
        if not valid:
            return api_error(message=trip_id, code=APIErrorCodes.VALIDATION_ERROR)
        
        Trip = request.env['transport.trip'].sudo()
        Booking = request.env['transport.booking'].sudo()
        
        trip = Trip.browse(trip_id)
        if not trip.exists() or trip.state != 'scheduled':
            return api_error(
                message="Voyage non disponible",
                code=APIErrorCodes.TRIP_NOT_AVAILABLE
            )
        
        # Vérifier la disponibilité
        if trip.available_seats <= 0:
            return api_error(
                message="Plus de places disponibles",
                code=APIErrorCodes.SEAT_NOT_AVAILABLE
            )
        
        # Déterminer si c'est un achat pour quelqu'un d'autre
        is_for_other = data.get('for_other', False)
        other_passenger_data = data.get('other_passenger', {})
        
        if is_for_other:
            # Validation des données du passager tiers
            if not other_passenger_data.get('name'):
                return api_error(
                    message="Le nom du passager est requis",
                    code=APIErrorCodes.VALIDATION_ERROR
                )
            
            valid_phone, phone_result = InputValidator.validate_phone(other_passenger_data.get('phone'))
            if not valid_phone:
                return api_error(
                    message=f"Téléphone du passager invalide: {phone_result}",
                    code=APIErrorCodes.VALIDATION_ERROR
                )
            
            # Infos du passager tiers
            traveler_name = other_passenger_data['name']
            traveler_phone = other_passenger_data.get('phone', '')
            traveler_email = other_passenger_data.get('email', '')
            traveler_id_type = other_passenger_data.get('id_type')
            traveler_id_number = other_passenger_data.get('id_number')
        else:
            # Achat pour soi-même
            traveler_name = passenger.name
            traveler_phone = passenger.phone
            traveler_email = passenger.email
            traveler_id_type = passenger.id_type
            traveler_id_number = passenger.id_number
        
        # Créer ou récupérer le partner associé au voyageur
        Partner = request.env['res.partner'].sudo()
        partner = Partner.search([('phone', '=', traveler_phone)], limit=1)
        if not partner:
            partner = Partner.create({
                'name': traveler_name,
                'phone': traveler_phone,
                'email': traveler_email,
            })
        
        # Préparer les valeurs de réservation
        ticket_type = data.get('ticket_type', 'adult')
        
        if ticket_type == 'vip':
            ticket_price = trip.vip_price or trip.price
        elif ticket_type == 'child':
            ticket_price = trip.child_price or (trip.price * 0.5)
        else:
            ticket_price = trip.price
        
        booking_vals = {
            'trip_id': trip.id,
            'partner_id': partner.id,
            'passenger_id': passenger.id,  # L'acheteur (compte connecté)
            'passenger_name': traveler_name,  # Le voyageur
            'passenger_phone': traveler_phone,
            'passenger_email': traveler_email,
            'ticket_type': ticket_type,
            'ticket_price': ticket_price,
            'boarding_stop_id': trip.route_id.departure_city_id.id,
            'alighting_stop_id': trip.route_id.arrival_city_id.id,
            'booking_type': data.get('booking_type', 'reservation'),
            # Champs pour les achats pour tiers
            'is_for_other': is_for_other,
            'buyer_id': passenger.id if is_for_other else False,
            'buyer_name': passenger.name if is_for_other else False,
            'buyer_phone': passenger.phone if is_for_other else False,
            # Infos du voyageur (pour affichage sur le billet)
            'traveler_name': traveler_name if is_for_other else False,
            'traveler_phone': traveler_phone if is_for_other else False,
            'traveler_email': traveler_email if is_for_other else False,
        }
        
        # Ajouter les infos d'identité si fournies
        if traveler_id_type:
            booking_vals['traveler_id_type'] = traveler_id_type
        if traveler_id_number:
            booking_vals['traveler_id_number'] = traveler_id_number
        
        if data.get('seat_id'):
            booking_vals['seat_id'] = int(data['seat_id'])
        
        if data.get('luggage_weight'):
            booking_vals['luggage_weight'] = float(data['luggage_weight'])
        
        try:
            booking = Booking.create(booking_vals)
            
            if booking.booking_type == 'reservation':
                booking.action_reserve()
            
            return api_response(
                data={'booking': self._format_booking(booking)},
                message="Réservation créée avec succès"
            )
            
        except Exception as e:
            _logger.exception(f"Erreur création réservation: {e}")
            return api_error(
                message=str(e),
                code=APIErrorCodes.SERVER_ERROR
            )

    @http.route('/api/v1/transport/usager/bookings', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def get_bookings(self, passenger=None, **kw):
        """
        Obtenir les réservations de l'usager
        
        Query params:
            - state: Filtrer par état (optionnel)
            - limit: Nombre max de résultats (défaut: 50)
            - offset: Décalage pour pagination (défaut: 0)
        """
        Booking = request.env['transport.booking'].sudo()
        
        params = request.params
        
        domain = [('passenger_id', '=', passenger.id)]
        
        if params.get('state'):
            domain.append(('state', '=', params['state']))
        
        limit = min(int(params.get('limit', 50)), 100)
        offset = int(params.get('offset', 0))
        
        bookings = Booking.search(domain, limit=limit, offset=offset, order='create_date desc')
        total = Booking.search_count(domain)
        
        return api_response(
            data={
                'bookings': [self._format_booking(b) for b in bookings],
                'total': total,
                'limit': limit,
                'offset': offset,
            }
        )

    @http.route('/api/v1/transport/usager/bookings/<int:booking_id>', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def get_booking_detail(self, booking_id, passenger=None, **kw):
        """Détails d'une réservation"""
        Booking = request.env['transport.booking'].sudo()
        
        booking = Booking.search([
            ('id', '=', booking_id),
            ('passenger_id', '=', passenger.id),
        ], limit=1)
        
        if not booking:
            return api_error(
                message="Réservation non trouvée",
                code=APIErrorCodes.BOOKING_NOT_FOUND
            )
        
        return api_response(
            data={'booking': self._format_booking(booking, include_details=True)}
        )

    @http.route('/api/v1/transport/usager/bookings/<int:booking_id>/pay', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def pay_booking(self, booking_id, passenger=None, **kw):
        """
        Payer une réservation
        
        Body:
            - payment_method: 'wave', 'orange_money', 'mtn_money', etc.
            - phone: Numéro de téléphone pour le paiement
        """
        data = request.jsonrequest
        
        Booking = request.env['transport.booking'].sudo()
        Payment = request.env['transport.payment'].sudo()
        
        booking = Booking.search([
            ('id', '=', booking_id),
            ('passenger_id', '=', passenger.id),
        ], limit=1)
        
        if not booking:
            return api_error(
                message="Réservation non trouvée",
                code=APIErrorCodes.BOOKING_NOT_FOUND
            )
        
        if booking.state not in ['draft', 'reserved']:
            return api_error(
                message="Cette réservation ne peut pas être payée",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        if booking.amount_due <= 0:
            return api_error(
                message="Cette réservation est déjà payée",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        payment_method = data.get('payment_method', 'wave')
        payment_phone = data.get('phone', passenger.phone)
        
        # Créer le paiement
        payment = Payment.create({
            'booking_id': booking.id,
            'amount': booking.amount_due,
            'payment_method': payment_method,
            'payment_phone': payment_phone,
            'state': 'pending',
        })
        
        # Pour Wave, initier le paiement
        if payment_method == 'wave':
            try:
                payment.action_process_wave_payment()
                
                return api_response(
                    data={
                        'payment_id': payment.id,
                        'payment_url': payment.wave_payment_url,
                        'status': 'pending',
                        'amount': booking.amount_due,
                    },
                    message="Paiement initié"
                )
            except Exception as e:
                return api_error(
                    message=f"Erreur lors de l'initiation du paiement: {e}",
                    code=APIErrorCodes.PAYMENT_FAILED
                )
        else:
            # Pour les autres méthodes, simuler un paiement réussi (à adapter)
            payment.write({
                'state': 'completed',
                'transaction_id': f"TRANS-{payment.id}",
            })
            
            booking.write({
                'amount_paid': booking.total_amount,
                'payment_method': payment_method,
                'payment_reference': payment.name,
            })
            
            booking.action_confirm()
            
            return api_response(
                data={
                    'payment': {
                        'id': payment.id,
                        'reference': payment.name,
                        'amount': payment.amount,
                        'status': 'completed',
                    },
                    'booking': self._format_booking(booking),
                },
                message="Paiement effectué avec succès"
            )

    @http.route('/api/v1/transport/usager/bookings/<int:booking_id>/ticket', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def get_ticket(self, booking_id, passenger=None, **kw):
        """
        Obtenir le ticket de voyage avec QR Code
        
        Le ticket contient:
        - Informations du voyage
        - QR Code unique du ticket
        - QR Code unique du passager
        - Informations d'achat pour tiers si applicable
        """
        Booking = request.env['transport.booking'].sudo()
        
        # Chercher la réservation - soit l'usager est le passager, soit l'acheteur
        booking = Booking.search([
            ('id', '=', booking_id),
            '|',
            ('passenger_id', '=', passenger.id),
            ('buyer_id', '=', passenger.id),
        ], limit=1)
        
        if not booking:
            return api_error(
                message="Réservation non trouvée",
                code=APIErrorCodes.BOOKING_NOT_FOUND
            )
        
        if booking.state not in ['confirmed', 'checked_in', 'completed']:
            return api_error(
                message="Le ticket n'est pas encore disponible. Veuillez d'abord payer la réservation.",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        # Déterminer le voyageur réel et l'acheteur
        traveler = booking.passenger_id
        buyer = booking.buyer_id if booking.is_for_other else None
        
        # Construire les infos du passager/voyageur
        passenger_info = {
            'name': traveler.name if booking.is_for_other else passenger.name,
            'phone': traveler.phone if booking.is_for_other else passenger.phone,
            'unique_qr_code': traveler.unique_qr_code.decode('utf-8') if traveler.unique_qr_code else None,
            'unique_qr_data': f"PASSENGER:{traveler.unique_token}",
        }
        
        # Si c'est un achat pour tiers avec nom/téléphone custom
        if booking.is_for_other:
            if booking.traveler_name:
                passenger_info['name'] = booking.traveler_name
            if booking.traveler_phone:
                passenger_info['phone'] = booking.traveler_phone
        
        ticket_data = {
            'ticket_number': booking.name,
            'ticket_token': booking.ticket_token,
            'ticket_qr_code': booking.qr_code.decode('utf-8') if booking.qr_code else None,
            'ticket_qr_data': f"TICKET:{booking.name}|TOKEN:{booking.ticket_token}|TRIP:{booking.trip_id.name}",
            'passenger': passenger_info,
            'trip': self._format_trip(booking.trip_id),
            'seat': booking.seat_number or "Non assigné",
            'boarding_point': booking.boarding_stop_id.name if booking.boarding_stop_id else '',
            'alighting_point': booking.alighting_stop_id.name if booking.alighting_stop_id else '',
            'status': booking.state,
            'is_for_other': booking.is_for_other,
        }
        
        # Ajouter les infos de l'acheteur si achat pour tiers
        if booking.is_for_other and buyer:
            ticket_data['buyer'] = {
                'name': booking.buyer_name or buyer.name,
                'phone': booking.buyer_phone or buyer.phone,
            }
        
        return api_response(
            data={
                'ticket': ticket_data,
            }
        )

    @http.route('/api/v1/transport/usager/bookings/<int:booking_id>/share', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def generate_share_link(self, booking_id, passenger=None, **kw):
        """
        Générer un lien de partage pour le billet
        
        Permet à l'acheteur de partager le billet avec le voyageur.
        Génère un token unique si pas encore créé.
        
        Returns:
            share_token: Token de partage
            share_url: URL complète de partage
            share_message: Message pré-formaté pour partage
        """
        Booking = request.env['transport.booking'].sudo()
        
        # L'usager peut partager si c'est l'acheteur ou le passager
        booking = Booking.search([
            ('id', '=', booking_id),
            '|',
            ('passenger_id', '=', passenger.id),
            ('buyer_id', '=', passenger.id),
        ], limit=1)
        
        if not booking:
            return api_error(
                message="Réservation non trouvée",
                code=APIErrorCodes.BOOKING_NOT_FOUND
            )
        
        if booking.state not in ['confirmed', 'checked_in', 'completed']:
            return api_error(
                message="Le billet n'est pas encore disponible pour le partage",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        # Générer le token de partage si pas encore fait
        share_info = booking.action_generate_share_token()
        
        # Formater le message de partage
        traveler_name = booking.traveler_name or booking.passenger_name
        departure_date = booking.trip_id.departure_datetime.strftime('%d/%m/%Y à %H:%M') if booking.trip_id.departure_datetime else ''
        route = f"{booking.trip_id.route_id.departure_city_id.name} → {booking.trip_id.route_id.arrival_city_id.name}"
        
        share_message = f"""🎫 Votre billet de transport

👤 Passager: {traveler_name}
🚌 Compagnie: {booking.transport_company_id.name}
📍 Trajet: {route}
📅 Départ: {departure_date}
💺 Siège: {booking.seat_number or 'Non assigné'}
🎟️ N° Billet: {booking.name}

📲 Consultez votre billet ici:
{share_info.get('share_url')}

Présentez le QR code à l'embarquement.
Bon voyage! 🚌"""

        # Message court pour SMS
        sms_message = f"Votre billet {booking.name} - {route} le {departure_date}. Voir: {share_info.get('share_url')}"
        
        return api_response(
            data={
                'share_token': share_info.get('share_token'),
                'share_url': share_info.get('share_url'),
                'share_message': share_message,
                'sms_message': sms_message,
                'ticket_number': booking.name,
                'passenger_name': traveler_name,
                'passenger_phone': booking.traveler_phone or booking.passenger_phone,
                'route': route,
                'departure_datetime': departure_date,
                'company_name': booking.transport_company_id.name,
            },
            message="Lien de partage généré avec succès"
        )

    @http.route('/api/v1/transport/usager/bookings/<int:booking_id>/receipt', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def get_receipt(self, booking_id, passenger=None, **kw):
        """
        Obtenir le reçu de paiement
        
        Retourne les détails du paiement pour la réservation.
        """
        Booking = request.env['transport.booking'].sudo()
        
        booking = Booking.search([
            ('id', '=', booking_id),
            ('passenger_id', '=', passenger.id),
        ], limit=1)
        
        if not booking:
            return api_error(
                message="Réservation non trouvée",
                code=APIErrorCodes.BOOKING_NOT_FOUND
            )
        
        if booking.state not in ['confirmed', 'checked_in', 'completed']:
            return api_error(
                message="Aucun reçu disponible pour cette réservation",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        payments = booking.payment_ids.filtered(lambda p: p.state == 'completed')
        
        return api_response(
            data={
                'receipt': {
                    'booking_reference': booking.name,
                    'passenger_name': passenger.name,
                    'passenger_phone': passenger.phone,
                    'trip': {
                        'reference': booking.trip_id.name,
                        'route': f"{booking.trip_id.route_id.departure_city_id.name} → {booking.trip_id.route_id.arrival_city_id.name}",
                        'departure': format_datetime(booking.trip_id.departure_datetime),
                        'company': booking.trip_id.transport_company_id.name,
                    },
                    'pricing': {
                        'ticket_price': booking.ticket_price,
                        'luggage_extra': booking.luggage_extra_price,
                        'total': booking.total_amount,
                        'currency': 'FCFA',
                    },
                    'payments': [{
                        'reference': p.name,
                        'amount': p.amount,
                        'method': dict(p._fields['payment_method'].selection).get(p.payment_method, p.payment_method),
                        'date': format_datetime(p.payment_date),
                        'transaction_id': p.transaction_id,
                    } for p in payments],
                    'payment_date': format_datetime(booking.payment_date),
                    'receipt_date': format_datetime(datetime.now()),
                },
            }
        )

    @http.route('/api/v1/transport/usager/bookings/<int:booking_id>/cancel', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_passenger_auth
    def cancel_booking(self, booking_id, passenger=None, **kw):
        """Annuler une réservation"""
        Booking = request.env['transport.booking'].sudo()
        
        booking = Booking.search([
            ('id', '=', booking_id),
            ('passenger_id', '=', passenger.id),
        ], limit=1)
        
        if not booking:
            return api_error(
                message="Réservation non trouvée",
                code=APIErrorCodes.BOOKING_NOT_FOUND
            )
        
        if booking.state in ['checked_in', 'completed', 'cancelled', 'refunded']:
            return api_error(
                message="Cette réservation ne peut pas être annulée",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        try:
            booking.action_cancel()
            
            return api_response(
                data={'booking': self._format_booking(booking)},
                message="Réservation annulée"
            )
        except Exception as e:
            return api_error(
                message=str(e),
                code=APIErrorCodes.SERVER_ERROR
            )

    # ==================== UTILITAIRES DE FORMATAGE ====================

    def _format_passenger(self, passenger, include_stats=False):
        """Formater les données d'un passager pour l'API"""
        data = {
            'id': passenger.id,
            'name': passenger.name,
            'phone': passenger.phone,
            'email': passenger.email,
            'id_type': passenger.id_type,
            'id_number': passenger.id_number,
            'date_of_birth': format_date(passenger.date_of_birth) if passenger.date_of_birth else None,
            'gender': passenger.gender,
            'preferred_seat_position': passenger.preferred_seat_position,
            'loyalty_points': passenger.loyalty_points,
            'loyalty_level': passenger.loyalty_level,
            'unique_token': passenger.unique_token,
        }
        
        if include_stats:
            data.update({
                'booking_count': passenger.booking_count,
                'total_spent': passenger.total_spent,
                'last_trip_date': format_datetime(passenger.last_trip_date) if passenger.last_trip_date else None,
            })
        
        return data

    def _format_trip(self, trip, include_seats=False):
        """Formater les données d'un voyage pour l'API"""
        data = {
            'id': trip.id,
            'reference': trip.name,
            'company': {
                'id': trip.transport_company_id.id,
                'name': trip.transport_company_id.name,
                'logo': trip.transport_company_id.logo.decode('utf-8') if trip.transport_company_id.logo else None,
                'rating': trip.transport_company_id.rating,
            },
            'route': {
                'id': trip.route_id.id,
                'departure_city': {
                    'id': trip.route_id.departure_city_id.id,
                    'name': trip.route_id.departure_city_id.name,
                },
                'arrival_city': {
                    'id': trip.route_id.arrival_city_id.id,
                    'name': trip.route_id.arrival_city_id.name,
                },
                'distance_km': trip.route_id.distance_km,
                'duration_hours': trip.route_id.duration_hours,
            },
            'departure_datetime': format_datetime(trip.departure_datetime),
            'departure_date': format_date(trip.departure_date),
            'departure_time': trip.departure_datetime.strftime('%H:%M') if trip.departure_datetime else None,
            'arrival_datetime': format_datetime(trip.arrival_datetime) if trip.arrival_datetime else None,
            'meeting_point': trip.meeting_point,
            'meeting_point_address': trip.meeting_point_address,
            'meeting_time_before': trip.meeting_time_before,
            'price': trip.price,
            'vip_price': trip.vip_price,
            'child_price': trip.child_price,
            'currency': 'FCFA',
            'available_seats': trip.available_seats,
            'total_seats': trip.total_seats,
            'bus': {
                'id': trip.bus_id.id,
                'name': trip.bus_id.name,
                'model': trip.bus_id.model,
                'amenities': trip.bus_id.amenities,
            },
            'manage_luggage': trip.manage_luggage,
            'luggage_included_kg': trip.luggage_included_kg,
            'extra_luggage_price': trip.extra_luggage_price,
        }
        
        if include_seats:
            # Inclure les sièges disponibles
            available_seats = []
            for seat in trip.bus_id.seat_ids:
                # Vérifier si le siège est réservé
                is_booked = request.env['transport.booking'].sudo().search_count([
                    ('trip_id', '=', trip.id),
                    ('seat_id', '=', seat.id),
                    ('state', 'in', ['reserved', 'confirmed', 'checked_in']),
                ]) > 0
                
                available_seats.append({
                    'id': seat.id,
                    'number': seat.seat_number,
                    'type': seat.seat_type,
                    'row': seat.row_number,
                    'column': seat.column_number,
                    'is_available': not is_booked,
                    'price_supplement': seat.price_supplement or 0,
                })
            
            data['seats'] = available_seats
        
        return data

    def _format_booking(self, booking, include_details=False):
        """Formater les données d'une réservation pour l'API"""
        data = {
            'id': booking.id,
            'reference': booking.name,
            'state': booking.state,
            'state_label': dict(booking._fields['state'].selection).get(booking.state),
            'booking_type': booking.booking_type,
            'booking_date': format_date(booking.booking_date),
            'trip': {
                'id': booking.trip_id.id,
                'reference': booking.trip_id.name,
                'company': booking.trip_id.transport_company_id.name,
                'route': f"{booking.trip_id.route_id.departure_city_id.name} → {booking.trip_id.route_id.arrival_city_id.name}",
                'departure': format_datetime(booking.trip_id.departure_datetime),
                'meeting_point': booking.trip_id.meeting_point,
            },
            'seat': booking.seat_number or "Non assigné",
            'ticket_type': booking.ticket_type,
            'ticket_price': booking.ticket_price,
            'luggage_weight': booking.luggage_weight,
            'luggage_extra_price': booking.luggage_extra_price,
            'total_amount': booking.total_amount,
            'amount_paid': booking.amount_paid,
            'amount_due': booking.amount_due,
            'currency': 'FCFA',
            'has_ticket': booking.state in ['confirmed', 'checked_in', 'completed'],
            'has_qr_code': bool(booking.qr_code),
            # Informations achat pour tiers
            'is_for_other': booking.is_for_other,
        }
        
        # Si achat pour un tiers, ajouter les infos de l'acheteur
        if booking.is_for_other:
            data['buyer'] = {
                'name': booking.buyer_name,
                'phone': booking.buyer_phone,
            }
        
        if booking.booking_type == 'reservation':
            data['reservation_deadline'] = format_datetime(booking.reservation_deadline)
        
        if include_details:
            data['passenger'] = {
                'name': booking.passenger_name,
                'phone': booking.passenger_phone,
                'email': booking.passenger_email,
                'id_type': booking.traveler_id_type,
                'id_number': booking.traveler_id_number,
            }
            data['boarding_stop'] = {
                'id': booking.boarding_stop_id.id,
                'name': booking.boarding_stop_id.name,
            } if booking.boarding_stop_id else None
            data['alighting_stop'] = {
                'id': booking.alighting_stop_id.id,
                'name': booking.alighting_stop_id.name,
            } if booking.alighting_stop_id else None
            
            if booking.is_round_trip and booking.return_booking_id:
                data['return_booking'] = {
                    'id': booking.return_booking_id.id,
                    'reference': booking.return_booking_id.name,
                }
        
        return data
