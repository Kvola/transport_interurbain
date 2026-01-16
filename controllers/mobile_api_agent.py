# -*- coding: utf-8 -*-
"""
API REST Mobile pour les Agents d'Embarquement - Transport Interurbain
Version: 1.0.0

Cette API permet aux agents d'embarquement de:
- S'authentifier
- Scanner les QR codes des passagers
- Scanner les QR codes des tickets
- Vérifier le paiement des tickets
- Procéder à l'embarquement des passagers
- Consulter la liste des passagers d'un voyage

Endpoints:
- POST /api/v1/transport/agent/auth/login - Connexion
- POST /api/v1/transport/agent/auth/logout - Déconnexion
- GET /api/v1/transport/agent/profile - Profil agent
- GET /api/v1/transport/agent/trips - Voyages assignés à l'agent
- GET /api/v1/transport/agent/trips/<id>/passengers - Passagers d'un voyage
- POST /api/v1/transport/agent/scan/passenger - Scanner QR passager
- POST /api/v1/transport/agent/scan/ticket - Scanner QR ticket
- POST /api/v1/transport/agent/boarding/<booking_id> - Embarquer un passager
- GET /api/v1/transport/agent/trips/<id>/stats - Statistiques embarquement
"""

import logging
from datetime import datetime, timedelta

from odoo import http, _, fields
from odoo.http import request

from .api_utils import (
    APIErrorCodes,
    api_response, api_error, api_validation_error,
    InputValidator,
    generate_api_token,
    require_agent_auth,
    api_exception_handler,
    rate_limit,
    get_client_ip,
    format_currency,
    format_datetime,
    format_date,
    TOKEN_EXPIRY_HOURS,
)

_logger = logging.getLogger(__name__)


class TransportAgentMobileAPI(http.Controller):
    """Contrôleur API REST pour l'application mobile des agents d'embarquement"""

    # ==================== AUTHENTIFICATION ====================

    @http.route('/api/v1/transport/agent/auth/login', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @rate_limit(max_requests=20, window=60)
    def login(self, **kw):
        """
        Connexion d'un agent d'embarquement
        
        Body:
            - login: Email ou identifiant (requis)
            - password: Mot de passe (requis)
        """
        data = request.jsonrequest
        
        login = data.get('login', '').strip()
        password = data.get('password', '')
        
        if not login or not password:
            return api_error(
                message="Identifiant et mot de passe requis",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        # Authentifier l'utilisateur
        try:
            uid = request.session.authenticate(
                request.session.db,
                login,
                password
            )
            
            if not uid:
                return api_error(
                    message="Identifiants incorrects",
                    code=APIErrorCodes.INVALID_CREDENTIALS
                )
            
            user = request.env['res.users'].sudo().browse(uid)
            
            # Vérifier que c'est bien un agent de transport
            if not user.has_group('transport_interurbain.group_transport_agent'):
                return api_error(
                    message="Accès non autorisé. Vous n'êtes pas un agent d'embarquement.",
                    code=APIErrorCodes.UNAUTHORIZED
                )
            
            # Générer un token d'API
            token = generate_api_token()
            user.sudo().write({
                'transport_agent_token': token,
                'transport_agent_token_expiry': fields.Datetime.now() + timedelta(hours=TOKEN_EXPIRY_HOURS),
            })
            
            return api_response(
                data={
                    'token': token,
                    'expires_at': (datetime.now() + timedelta(hours=TOKEN_EXPIRY_HOURS)).isoformat(),
                    'agent': self._format_agent(user),
                },
                message="Connexion réussie"
            )
            
        except Exception as e:
            _logger.exception(f"Erreur login agent: {e}")
            return api_error(
                message="Erreur d'authentification",
                code=APIErrorCodes.INVALID_CREDENTIALS
            )

    @http.route('/api/v1/transport/agent/auth/logout', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_agent_auth
    def logout(self, agent_user=None, **kw):
        """Déconnexion de l'agent"""
        agent_user.sudo().write({
            'transport_agent_token': False,
            'transport_agent_token_expiry': False,
        })
        return api_response(message="Déconnexion réussie")

    @http.route('/api/v1/transport/agent/profile', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @require_agent_auth
    def get_profile(self, agent_user=None, **kw):
        """Obtenir le profil de l'agent"""
        return api_response(
            data={'agent': self._format_agent(agent_user, include_company=True)}
        )

    # ==================== VOYAGES ====================

    @http.route('/api/v1/transport/agent/trips', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @require_agent_auth
    def get_assigned_trips(self, agent_user=None, **kw):
        """
        Obtenir les voyages assignés à l'agent
        
        Retourne les voyages du jour pour la compagnie de l'agent.
        """
        Trip = request.env['transport.trip'].sudo()
        
        params = request.params
        
        # Déterminer la compagnie de l'agent
        company = self._get_agent_company(agent_user)
        
        if not company:
            return api_error(
                message="Aucune compagnie de transport associée à votre compte",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        # Date par défaut: aujourd'hui
        date_str = params.get('date')
        if date_str:
            valid, trip_date = InputValidator.validate_date(date_str)
            if not valid:
                trip_date = fields.Date.today()
        else:
            trip_date = fields.Date.today()
        
        # Rechercher les voyages
        domain = [
            ('transport_company_id', '=', company.id),
            ('departure_date', '=', trip_date),
            ('state', 'in', ['scheduled', 'boarding', 'departed']),
        ]
        
        trips = Trip.search(domain, order='departure_datetime')
        
        return api_response(
            data={
                'trips': [self._format_trip_for_agent(t) for t in trips],
                'date': str(trip_date),
                'company': {
                    'id': company.id,
                    'name': company.name,
                },
            }
        )

    @http.route('/api/v1/transport/agent/trips/<int:trip_id>/passengers', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @require_agent_auth
    def get_trip_passengers(self, trip_id, agent_user=None, **kw):
        """
        Obtenir la liste des passagers d'un voyage
        
        Retourne tous les passagers avec leur statut d'embarquement.
        """
        Trip = request.env['transport.trip'].sudo()
        Booking = request.env['transport.booking'].sudo()
        
        trip = Trip.browse(trip_id)
        
        if not trip.exists():
            return api_error(
                message="Voyage non trouvé",
                code=APIErrorCodes.RESOURCE_NOT_FOUND
            )
        
        # Vérifier que l'agent peut accéder à ce voyage
        company = self._get_agent_company(agent_user)
        if company and trip.transport_company_id.id != company.id:
            return api_error(
                message="Vous n'avez pas accès à ce voyage",
                code=APIErrorCodes.UNAUTHORIZED
            )
        
        # Récupérer toutes les réservations confirmées
        bookings = Booking.search([
            ('trip_id', '=', trip.id),
            ('state', 'in', ['confirmed', 'checked_in']),
        ], order='passenger_name')
        
        return api_response(
            data={
                'trip': self._format_trip_for_agent(trip),
                'passengers': [self._format_booking_for_agent(b) for b in bookings],
                'summary': {
                    'total_confirmed': len(bookings),
                    'checked_in': len(bookings.filtered(lambda b: b.state == 'checked_in')),
                    'pending': len(bookings.filtered(lambda b: b.state == 'confirmed')),
                },
            }
        )

    @http.route('/api/v1/transport/agent/trips/<int:trip_id>/stats', type='json', auth='none',
                methods=['GET'], csrf=False, cors='*')
    @api_exception_handler
    @require_agent_auth
    def get_trip_stats(self, trip_id, agent_user=None, **kw):
        """Statistiques d'embarquement d'un voyage"""
        Trip = request.env['transport.trip'].sudo()
        Booking = request.env['transport.booking'].sudo()
        
        trip = Trip.browse(trip_id)
        
        if not trip.exists():
            return api_error(
                message="Voyage non trouvé",
                code=APIErrorCodes.RESOURCE_NOT_FOUND
            )
        
        company = self._get_agent_company(agent_user)
        if company and trip.transport_company_id.id != company.id:
            return api_error(
                message="Vous n'avez pas accès à ce voyage",
                code=APIErrorCodes.UNAUTHORIZED
            )
        
        all_bookings = Booking.search([('trip_id', '=', trip.id)])
        
        stats = {
            'total_seats': trip.total_seats,
            'available_seats': trip.available_seats,
            'bookings': {
                'total': len(all_bookings),
                'confirmed': len(all_bookings.filtered(lambda b: b.state == 'confirmed')),
                'checked_in': len(all_bookings.filtered(lambda b: b.state == 'checked_in')),
                'cancelled': len(all_bookings.filtered(lambda b: b.state == 'cancelled')),
                'expired': len(all_bookings.filtered(lambda b: b.state == 'expired')),
            },
            'revenue': {
                'total': sum(all_bookings.filtered(lambda b: b.state in ['confirmed', 'checked_in']).mapped('total_amount')),
                'currency': 'FCFA',
            },
            'ticket_types': {
                'adult': len(all_bookings.filtered(lambda b: b.ticket_type == 'adult' and b.state in ['confirmed', 'checked_in'])),
                'child': len(all_bookings.filtered(lambda b: b.ticket_type == 'child' and b.state in ['confirmed', 'checked_in'])),
                'vip': len(all_bookings.filtered(lambda b: b.ticket_type == 'vip' and b.state in ['confirmed', 'checked_in'])),
            },
        }
        
        # Calculer le taux d'embarquement
        confirmed_count = stats['bookings']['confirmed'] + stats['bookings']['checked_in']
        if confirmed_count > 0:
            stats['boarding_rate'] = round(stats['bookings']['checked_in'] / confirmed_count * 100, 1)
        else:
            stats['boarding_rate'] = 0
        
        return api_response(data={'stats': stats})

    # ==================== SCAN QR CODE ====================

    @http.route('/api/v1/transport/agent/scan/passenger', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_agent_auth
    def scan_passenger_qr(self, agent_user=None, **kw):
        """
        Scanner le QR Code unique d'un passager
        
        Body:
            - qr_data: Données du QR code (format: PASSENGER:<token>)
            - trip_id: ID du voyage actuel (requis)
        
        Retourne:
            - Les informations du passager
            - Tous ses tickets pour le voyage spécifié
            - Le statut de paiement de chaque ticket
        """
        data = request.jsonrequest
        
        qr_data = data.get('qr_data', '').strip()
        trip_id = data.get('trip_id')
        
        if not qr_data:
            return api_error(
                message="Données QR code requises",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        if not trip_id:
            return api_error(
                message="ID du voyage requis",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        # Parser le QR code
        if not qr_data.startswith('PASSENGER:'):
            return api_error(
                message="Format de QR code invalide. Utilisez le QR code unique du passager.",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        passenger_token = qr_data.replace('PASSENGER:', '')
        
        Passenger = request.env['transport.passenger'].sudo()
        Booking = request.env['transport.booking'].sudo()
        Trip = request.env['transport.trip'].sudo()
        
        # Rechercher le passager
        passenger = Passenger.search([('unique_token', '=', passenger_token)], limit=1)
        
        if not passenger:
            return api_error(
                message="Passager non trouvé. QR code invalide.",
                code=APIErrorCodes.PASSENGER_NOT_FOUND
            )
        
        # Vérifier le voyage
        trip = Trip.browse(int(trip_id))
        if not trip.exists():
            return api_error(
                message="Voyage non trouvé",
                code=APIErrorCodes.TRIP_NOT_AVAILABLE
            )
        
        # Chercher les réservations du passager pour ce voyage
        bookings = Booking.search([
            ('passenger_id', '=', passenger.id),
            ('trip_id', '=', trip.id),
        ])
        
        if not bookings:
            return api_response(
                data={
                    'passenger': {
                        'name': passenger.name,
                        'phone': passenger.phone,
                        'loyalty_level': passenger.loyalty_level,
                    },
                    'has_valid_ticket': False,
                    'bookings': [],
                    'message': "Ce passager n'a aucune réservation pour ce voyage.",
                }
            )
        
        # Analyser les réservations
        valid_bookings = bookings.filtered(lambda b: b.state in ['confirmed', 'checked_in'])
        
        response_data = {
            'passenger': {
                'id': passenger.id,
                'name': passenger.name,
                'phone': passenger.phone,
                'email': passenger.email,
                'loyalty_level': passenger.loyalty_level,
                'loyalty_points': passenger.loyalty_points,
            },
            'has_valid_ticket': len(valid_bookings) > 0,
            'bookings': [{
                'id': b.id,
                'reference': b.name,
                'state': b.state,
                'state_label': dict(b._fields['state'].selection).get(b.state),
                'is_paid': b.state in ['confirmed', 'checked_in'],
                'is_boarded': b.state == 'checked_in',
                'seat': b.seat_number or "Non assigné",
                'ticket_type': b.ticket_type,
                'total_amount': b.total_amount,
                'amount_paid': b.amount_paid,
                'amount_due': b.amount_due,
                'can_board': b.state == 'confirmed',
            } for b in bookings],
        }
        
        # Déterminer le message approprié
        if not valid_bookings:
            response_data['message'] = "⚠️ ATTENTION: Ce passager n'a pas de ticket payé pour ce voyage!"
            response_data['alert_type'] = 'danger'
        elif all(b.state == 'checked_in' for b in valid_bookings):
            response_data['message'] = "✓ Passager déjà embarqué"
            response_data['alert_type'] = 'info'
        else:
            response_data['message'] = "✓ Passager avec ticket valide - Prêt pour l'embarquement"
            response_data['alert_type'] = 'success'
        
        return api_response(data=response_data)

    @http.route('/api/v1/transport/agent/scan/ticket', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_agent_auth
    def scan_ticket_qr(self, agent_user=None, **kw):
        """
        Scanner le QR Code d'un ticket spécifique
        
        Body:
            - qr_data: Données du QR code (format: TICKET:<ref>|TOKEN:<token>|TRIP:<trip_ref>)
        
        Retourne:
            - Les informations du ticket
            - Le statut de paiement
            - La possibilité d'embarquer
        """
        data = request.jsonrequest
        
        qr_data = data.get('qr_data', '').strip()
        
        if not qr_data:
            return api_error(
                message="Données QR code requises",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        # Parser le QR code du ticket
        if not qr_data.startswith('TICKET:'):
            return api_error(
                message="Format de QR code invalide. Utilisez le QR code du ticket.",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        try:
            parts = qr_data.split('|')
            ticket_ref = parts[0].replace('TICKET:', '')
            ticket_token = parts[1].replace('TOKEN:', '') if len(parts) > 1 else None
        except Exception:
            return api_error(
                message="Format de QR code invalide",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        Booking = request.env['transport.booking'].sudo()
        
        # Rechercher la réservation
        domain = [('name', '=', ticket_ref)]
        if ticket_token:
            domain.append(('ticket_token', '=', ticket_token))
        
        booking = Booking.search(domain, limit=1)
        
        if not booking:
            return api_error(
                message="Ticket non trouvé. QR code invalide ou expiré.",
                code=APIErrorCodes.BOOKING_NOT_FOUND
            )
        
        # Vérifier la compagnie
        company = self._get_agent_company(agent_user)
        if company and booking.transport_company_id.id != company.id:
            return api_error(
                message="Ce ticket appartient à une autre compagnie",
                code=APIErrorCodes.UNAUTHORIZED
            )
        
        # Construire la réponse
        response_data = {
            'ticket': {
                'id': booking.id,
                'reference': booking.name,
                'state': booking.state,
                'state_label': dict(booking._fields['state'].selection).get(booking.state),
            },
            'passenger': {
                'name': booking.passenger_name,
                'phone': booking.passenger_phone,
            },
            'trip': {
                'id': booking.trip_id.id,
                'reference': booking.trip_id.name,
                'route': f"{booking.trip_id.route_id.departure_city_id.name} → {booking.trip_id.route_id.arrival_city_id.name}",
                'departure': format_datetime(booking.trip_id.departure_datetime),
            },
            'seat': booking.seat_number or "Non assigné",
            'ticket_type': booking.ticket_type,
            'payment': {
                'total_amount': booking.total_amount,
                'amount_paid': booking.amount_paid,
                'amount_due': booking.amount_due,
                'is_paid': booking.amount_due <= 0,
            },
            'boarding': {
                'is_boarded': booking.state == 'checked_in',
                'can_board': booking.state == 'confirmed',
            },
        }
        
        # Déterminer le message et l'alerte
        if booking.state == 'checked_in':
            response_data['message'] = "✓ Passager déjà embarqué"
            response_data['alert_type'] = 'info'
        elif booking.state == 'confirmed':
            response_data['message'] = "✓ Ticket valide - Prêt pour l'embarquement"
            response_data['alert_type'] = 'success'
        elif booking.state in ['draft', 'reserved']:
            response_data['message'] = "⚠️ ATTENTION: Ticket non payé!"
            response_data['alert_type'] = 'danger'
        elif booking.state == 'cancelled':
            response_data['message'] = "❌ Ticket annulé"
            response_data['alert_type'] = 'danger'
        elif booking.state == 'expired':
            response_data['message'] = "❌ Ticket expiré"
            response_data['alert_type'] = 'danger'
        else:
            response_data['message'] = f"État du ticket: {response_data['ticket']['state_label']}"
            response_data['alert_type'] = 'warning'
        
        return api_response(data=response_data)

    # ==================== EMBARQUEMENT ====================

    @http.route('/api/v1/transport/agent/boarding/<int:booking_id>', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_agent_auth
    def board_passenger(self, booking_id, agent_user=None, **kw):
        """
        Embarquer un passager
        
        Cette action marque le passager comme embarqué si le ticket est valide et payé.
        """
        Booking = request.env['transport.booking'].sudo()
        
        booking = Booking.browse(booking_id)
        
        if not booking.exists():
            return api_error(
                message="Réservation non trouvée",
                code=APIErrorCodes.BOOKING_NOT_FOUND
            )
        
        # Vérifier la compagnie
        company = self._get_agent_company(agent_user)
        if company and booking.transport_company_id.id != company.id:
            return api_error(
                message="Vous n'avez pas accès à cette réservation",
                code=APIErrorCodes.UNAUTHORIZED
            )
        
        # Vérifier l'état
        if booking.state == 'checked_in':
            return api_error(
                message="Ce passager est déjà embarqué",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        if booking.state != 'confirmed':
            return api_error(
                message=f"Impossible d'embarquer: ticket en état '{dict(booking._fields['state'].selection).get(booking.state)}'",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        # Vérifier le paiement
        if booking.amount_due > 0:
            return api_error(
                message=f"Ticket non payé intégralement. Reste à payer: {format_currency(booking.amount_due)}",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        # Embarquer le passager
        try:
            booking.action_check_in()
            
            # Ajouter des points de fidélité au passager
            if booking.passenger_id:
                points = int(booking.total_amount / 100)  # 1 point pour 100 FCFA
                booking.passenger_id.add_loyalty_points(points)
            
            return api_response(
                data={
                    'booking': self._format_booking_for_agent(booking),
                    'message': f"✓ {booking.passenger_name} embarqué avec succès"
                },
                message="Embarquement réussi"
            )
            
        except Exception as e:
            _logger.exception(f"Erreur embarquement: {e}")
            return api_error(
                message=str(e),
                code=APIErrorCodes.SERVER_ERROR
            )

    @http.route('/api/v1/transport/agent/boarding/batch', type='json', auth='none',
                methods=['POST'], csrf=False, cors='*')
    @api_exception_handler
    @require_agent_auth
    def board_passengers_batch(self, agent_user=None, **kw):
        """
        Embarquer plusieurs passagers en une fois
        
        Body:
            - booking_ids: Liste des IDs de réservations à embarquer
        """
        data = request.jsonrequest
        
        booking_ids = data.get('booking_ids', [])
        
        if not booking_ids:
            return api_error(
                message="Aucune réservation spécifiée",
                code=APIErrorCodes.VALIDATION_ERROR
            )
        
        Booking = request.env['transport.booking'].sudo()
        
        results = {
            'success': [],
            'failed': [],
        }
        
        company = self._get_agent_company(agent_user)
        
        for booking_id in booking_ids:
            booking = Booking.browse(booking_id)
            
            if not booking.exists():
                results['failed'].append({
                    'id': booking_id,
                    'reason': "Réservation non trouvée"
                })
                continue
            
            if company and booking.transport_company_id.id != company.id:
                results['failed'].append({
                    'id': booking_id,
                    'reason': "Accès non autorisé"
                })
                continue
            
            if booking.state == 'checked_in':
                results['failed'].append({
                    'id': booking_id,
                    'reference': booking.name,
                    'reason': "Déjà embarqué"
                })
                continue
            
            if booking.state != 'confirmed':
                results['failed'].append({
                    'id': booking_id,
                    'reference': booking.name,
                    'reason': f"État invalide: {booking.state}"
                })
                continue
            
            if booking.amount_due > 0:
                results['failed'].append({
                    'id': booking_id,
                    'reference': booking.name,
                    'reason': f"Non payé (reste: {format_currency(booking.amount_due)})"
                })
                continue
            
            try:
                booking.action_check_in()
                if booking.passenger_id:
                    points = int(booking.total_amount / 100)
                    booking.passenger_id.add_loyalty_points(points)
                
                results['success'].append({
                    'id': booking.id,
                    'reference': booking.name,
                    'passenger': booking.passenger_name,
                })
            except Exception as e:
                results['failed'].append({
                    'id': booking_id,
                    'reference': booking.name,
                    'reason': str(e)
                })
        
        return api_response(
            data=results,
            message=f"{len(results['success'])} passager(s) embarqué(s), {len(results['failed'])} échec(s)"
        )

    # ==================== UTILITAIRES ====================

    def _get_agent_company(self, user):
        """Obtenir la compagnie de transport associée à l'agent"""
        # Chercher si l'utilisateur est lié à une compagnie
        Company = request.env['transport.company'].sudo()
        
        # D'abord chercher par employee_ids ou partner_id
        if user.partner_id:
            company = Company.search([
                '|',
                ('partner_id', '=', user.partner_id.id),
                ('user_ids', 'in', [user.id]),
            ], limit=1)
            
            if company:
                return company
        
        # Sinon, chercher via les employés
        Employee = request.env.get('hr.employee')
        if Employee:
            employee = Employee.sudo().search([('user_id', '=', user.id)], limit=1)
            if employee and employee.company_id:
                company = Company.search([
                    ('company_id', '=', employee.company_id.id),
                ], limit=1)
                if company:
                    return company
        
        # Retourner la première compagnie active si aucune association
        return Company.search([('state', '=', 'active')], limit=1)

    def _format_agent(self, user, include_company=False):
        """Formater les données d'un agent pour l'API"""
        data = {
            'id': user.id,
            'name': user.name,
            'login': user.login,
            'email': user.email,
            'phone': user.partner_id.phone if user.partner_id else None,
        }
        
        if include_company:
            company = self._get_agent_company(user)
            if company:
                data['company'] = {
                    'id': company.id,
                    'name': company.name,
                    'logo': company.logo.decode('utf-8') if company.logo else None,
                }
        
        return data

    def _format_trip_for_agent(self, trip):
        """Formater un voyage pour l'API agent"""
        Booking = request.env['transport.booking'].sudo()
        
        # Statistiques rapides
        bookings = Booking.search([
            ('trip_id', '=', trip.id),
            ('state', 'in', ['confirmed', 'checked_in']),
        ])
        
        return {
            'id': trip.id,
            'reference': trip.name,
            'route': {
                'departure': trip.route_id.departure_city_id.name,
                'arrival': trip.route_id.arrival_city_id.name,
            },
            'departure_datetime': format_datetime(trip.departure_datetime),
            'departure_time': trip.departure_datetime.strftime('%H:%M') if trip.departure_datetime else None,
            'state': trip.state,
            'state_label': dict(trip._fields['state'].selection).get(trip.state),
            'meeting_point': trip.meeting_point,
            'bus': {
                'name': trip.bus_id.name,
                'plate': trip.bus_id.license_plate,
            },
            'driver': trip.driver_name,
            'stats': {
                'total_confirmed': len(bookings),
                'checked_in': len(bookings.filtered(lambda b: b.state == 'checked_in')),
                'pending': len(bookings.filtered(lambda b: b.state == 'confirmed')),
                'total_seats': trip.total_seats,
                'available_seats': trip.available_seats,
            },
        }

    def _format_booking_for_agent(self, booking):
        """Formater une réservation pour l'API agent"""
        return {
            'id': booking.id,
            'reference': booking.name,
            'passenger': {
                'id': booking.passenger_id.id if booking.passenger_id else None,
                'name': booking.passenger_name,
                'phone': booking.passenger_phone,
            },
            'seat': booking.seat_number or "Non assigné",
            'ticket_type': booking.ticket_type,
            'state': booking.state,
            'state_label': dict(booking._fields['state'].selection).get(booking.state),
            'is_paid': booking.amount_due <= 0,
            'is_boarded': booking.state == 'checked_in',
            'can_board': booking.state == 'confirmed' and booking.amount_due <= 0,
            'total_amount': booking.total_amount,
            'amount_due': booking.amount_due,
            'boarding_stop': booking.boarding_stop_id.name if booking.boarding_stop_id else None,
            'alighting_stop': booking.alighting_stop_id.name if booking.alighting_stop_id else None,
        }
