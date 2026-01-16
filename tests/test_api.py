# -*- coding: utf-8 -*-
"""
Tests unitaires pour les API REST du module transport_interurbain
Tests des endpoints mobile pour usagers et agents
"""

import json
import logging
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock

from odoo.tests import TransactionCase, tagged, HttpCase
from odoo.exceptions import ValidationError, UserError

_logger = logging.getLogger(__name__)


@tagged('post_install', '-at_install', 'transport', 'api')
class TestTransportAPIUsager(HttpCase):
    """Tests pour l'API mobile usager"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        # Créer compagnie de transport
        cls.company = cls.env['transport.company'].create({
            'name': 'API Test Company',
            'phone': '+225 01 00 00 00 00',
            'state': 'active',
            'allow_online_payment': True,
        })
        
        # Créer villes
        cls.city_departure = cls.env['transport.city'].create({
            'name': 'Abidjan',
            'code': 'ABJ',
            'is_major_city': True,
        })
        cls.city_arrival = cls.env['transport.city'].create({
            'name': 'Yamoussoukro',
            'code': 'YAM',
            'is_major_city': True,
        })
        
        # Créer itinéraire
        cls.route = cls.env['transport.route'].create({
            'name': 'ABJ - YAM',
            'departure_city_id': cls.city_departure.id,
            'arrival_city_id': cls.city_arrival.id,
            'distance_km': 240,
            'estimated_duration': 3.5,
            'base_price': 5000,
            'state': 'active',
        })
        
        # Créer bus
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-API-001',
            'transport_company_id': cls.company.id,
            'immatriculation': 'AP 0001 II',
            'seat_capacity': 50,
            'state': 'available',
        })
        
        # Créer voyage
        cls.trip = cls.env['transport.trip'].create({
            'transport_company_id': cls.company.id,
            'route_id': cls.route.id,
            'bus_id': cls.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=2),
            'meeting_point': 'Gare routière Adjamé',
            'price': 5000,
            'vip_price': 8000,
            'child_price': 2500,
        })
        cls.trip.action_schedule()
        
        # Créer passager
        cls.passenger = cls.env['transport.passenger'].create({
            'name': 'Test API User',
            'phone': '+225 07 99 00 00 00',
            'email': 'apiuser@test.ci',
            'pin_hash': cls.env['transport.passenger']._hash_pin('1234'),
        })

    def test_api_get_cities(self):
        """Test de récupération des villes"""
        response = self.url_open(
            '/api/v1/usager/cities',
            data=json.dumps({}),
            headers={'Content-Type': 'application/json'}
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        self.assertIn('result', result)
        cities = result.get('result', {}).get('data', [])
        self.assertTrue(len(cities) >= 2)
        
        # Vérifier les champs
        city_names = [c['name'] for c in cities]
        self.assertIn('Abidjan', city_names)
        self.assertIn('Yamoussoukro', city_names)

    def test_api_search_trips(self):
        """Test de recherche de voyages"""
        search_date = (datetime.now() + timedelta(days=2)).strftime('%Y-%m-%d')
        
        response = self.url_open(
            '/api/v1/usager/trips/search',
            data=json.dumps({
                'from_city_id': self.city_departure.id,
                'to_city_id': self.city_arrival.id,
                'date': search_date,
            }),
            headers={'Content-Type': 'application/json'}
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        trips = result.get('result', {}).get('data', [])
        self.assertTrue(len(trips) >= 1)
        
        # Vérifier les données du voyage
        trip = trips[0]
        self.assertEqual(trip['price'], 5000)
        self.assertIn('available_seats', trip)

    def test_api_get_trip_details(self):
        """Test de récupération des détails d'un voyage"""
        response = self.url_open(
            '/api/v1/usager/trips/%d' % self.trip.id,
            data=json.dumps({}),
            headers={'Content-Type': 'application/json'}
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        trip = result.get('result', {}).get('data', {})
        
        self.assertEqual(trip['id'], self.trip.id)
        self.assertEqual(trip['price'], 5000)
        self.assertIn('route', trip)
        self.assertIn('company', trip)

    def test_api_register_passenger(self):
        """Test d'inscription d'un nouveau passager"""
        response = self.url_open(
            '/api/v1/usager/auth/register',
            data=json.dumps({
                'name': 'Nouveau Passager',
                'phone': '+225 07 11 22 33 44',
                'pin': '5678',
            }),
            headers={'Content-Type': 'application/json'}
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        
        self.assertIn('result', result)
        data = result.get('result', {})
        self.assertTrue(data.get('success', False))
        self.assertIn('passenger_id', data)
        self.assertIn('token', data)

    def test_api_login_passenger(self):
        """Test de connexion d'un passager"""
        response = self.url_open(
            '/api/v1/usager/auth/login',
            data=json.dumps({
                'phone': '+225 07 99 00 00 00',
                'pin': '1234',
            }),
            headers={'Content-Type': 'application/json'}
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        
        data = result.get('result', {})
        self.assertTrue(data.get('success', False))
        self.assertEqual(data.get('passenger', {}).get('id'), self.passenger.id)
        self.assertIn('token', data)

    def test_api_login_wrong_pin(self):
        """Test de connexion avec mauvais PIN"""
        response = self.url_open(
            '/api/v1/usager/auth/login',
            data=json.dumps({
                'phone': '+225 07 99 00 00 00',
                'pin': '0000',  # Mauvais PIN
            }),
            headers={'Content-Type': 'application/json'}
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        
        data = result.get('result', {})
        self.assertFalse(data.get('success', True))
        self.assertIn('error', data)

    def test_api_get_companies(self):
        """Test de récupération des compagnies"""
        response = self.url_open(
            '/api/v1/usager/companies',
            data=json.dumps({}),
            headers={'Content-Type': 'application/json'}
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        companies = result.get('result', {}).get('data', [])
        
        self.assertTrue(len(companies) >= 1)
        company_names = [c['name'] for c in companies]
        self.assertIn('API Test Company', company_names)


@tagged('post_install', '-at_install', 'transport', 'api')
class TestTransportAPIAgent(HttpCase):
    """Tests pour l'API mobile agent"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        # Créer utilisateur agent
        cls.agent_user = cls.env['res.users'].create({
            'name': 'Agent Test',
            'login': 'agent_test@test.ci',
            'password': 'agent123',
            'groups_id': [(4, cls.env.ref('base.group_user').id)],
        })
        
        # Créer compagnie
        cls.company = cls.env['transport.company'].create({
            'name': 'Agent Test Company',
            'state': 'active',
        })
        
        # Créer villes
        cls.city_a = cls.env['transport.city'].create({'name': 'Ville A', 'code': 'A'})
        cls.city_b = cls.env['transport.city'].create({'name': 'Ville B', 'code': 'B'})
        
        # Créer itinéraire
        cls.route = cls.env['transport.route'].create({
            'name': 'A - B',
            'departure_city_id': cls.city_a.id,
            'arrival_city_id': cls.city_b.id,
            'base_price': 3000,
            'state': 'active',
        })
        
        # Créer bus
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-AGENT',
            'transport_company_id': cls.company.id,
            'seat_capacity': 30,
            'state': 'available',
        })
        
        # Créer voyage
        cls.trip = cls.env['transport.trip'].create({
            'transport_company_id': cls.company.id,
            'route_id': cls.route.id,
            'bus_id': cls.bus.id,
            'departure_datetime': datetime.now() + timedelta(hours=2),
            'meeting_point': 'Gare Agent',
            'price': 3000,
        })
        cls.trip.action_schedule()
        cls.trip.action_start_boarding()
        
        # Créer passager et réservation
        cls.partner = cls.env['res.partner'].create({
            'name': 'Passager Agent Test',
            'phone': '+225 07 88 00 00 00',
        })
        
        cls.booking = cls.env['transport.booking'].create({
            'trip_id': cls.trip.id,
            'partner_id': cls.partner.id,
            'passenger_name': 'Passager Agent Test',
            'passenger_phone': '+225 07 88 00 00 00',
            'ticket_price': 3000,
            'boarding_stop_id': cls.city_a.id,
            'alighting_stop_id': cls.city_b.id,
        })
        cls.booking.action_reserve()
        cls.booking.amount_paid = 3000
        cls.booking.action_confirm()

    def test_api_agent_login(self):
        """Test de connexion agent"""
        response = self.url_open(
            '/api/v1/agent/auth/login',
            data=json.dumps({
                'login': 'agent_test@test.ci',
                'password': 'agent123',
            }),
            headers={'Content-Type': 'application/json'}
        )
        self.assertEqual(response.status_code, 200)

    def test_api_agent_scan_ticket(self):
        """Test de scan de ticket"""
        # D'abord se connecter
        login_response = self.url_open(
            '/api/v1/agent/auth/login',
            data=json.dumps({
                'login': 'agent_test@test.ci',
                'password': 'agent123',
            }),
            headers={'Content-Type': 'application/json'}
        )
        token = login_response.json().get('result', {}).get('token')
        
        # Scanner le ticket
        response = self.url_open(
            '/api/v1/agent/ticket/scan',
            data=json.dumps({
                'ticket_token': self.booking.ticket_token,
            }),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {token}',
            }
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        
        ticket = result.get('result', {}).get('data', {})
        self.assertEqual(ticket.get('name'), self.booking.name)
        self.assertEqual(ticket.get('passenger_name'), 'Passager Agent Test')

    def test_api_agent_validate_ticket(self):
        """Test de validation (embarquement) de ticket"""
        # Se connecter
        login_response = self.url_open(
            '/api/v1/agent/auth/login',
            data=json.dumps({
                'login': 'agent_test@test.ci',
                'password': 'agent123',
            }),
            headers={'Content-Type': 'application/json'}
        )
        token = login_response.json().get('result', {}).get('token')
        
        # Valider le ticket
        response = self.url_open(
            '/api/v1/agent/ticket/validate',
            data=json.dumps({
                'ticket_token': self.booking.ticket_token,
            }),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {token}',
            }
        )
        self.assertEqual(response.status_code, 200)
        
        # Vérifier l'état
        self.booking.invalidate_recordset()
        self.assertEqual(self.booking.state, 'checked_in')


@tagged('post_install', '-at_install', 'transport', 'api')
class TestTransportAPIBooking(HttpCase):
    """Tests pour les fonctionnalités de réservation via API"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        cls.company = cls.env['transport.company'].create({
            'name': 'Booking API Company',
            'state': 'active',
            'allow_online_payment': True,
        })
        
        cls.city_from = cls.env['transport.city'].create({'name': 'Départ API', 'code': 'DEP'})
        cls.city_to = cls.env['transport.city'].create({'name': 'Arrivée API', 'code': 'ARR'})
        
        cls.route = cls.env['transport.route'].create({
            'name': 'DEP - ARR',
            'departure_city_id': cls.city_from.id,
            'arrival_city_id': cls.city_to.id,
            'base_price': 4000,
            'state': 'active',
        })
        
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-BOOKING',
            'transport_company_id': cls.company.id,
            'seat_capacity': 20,
            'state': 'available',
        })
        
        cls.trip = cls.env['transport.trip'].create({
            'transport_company_id': cls.company.id,
            'route_id': cls.route.id,
            'bus_id': cls.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=3),
            'meeting_point': 'Gare Booking',
            'price': 4000,
        })
        cls.trip.action_schedule()
        
        cls.passenger = cls.env['transport.passenger'].create({
            'name': 'Booking Test User',
            'phone': '+225 07 77 00 00 00',
            'pin_hash': cls.env['transport.passenger']._hash_pin('4321'),
        })

    def _get_auth_token(self):
        """Obtenir un token d'authentification"""
        response = self.url_open(
            '/api/v1/usager/auth/login',
            data=json.dumps({
                'phone': '+225 07 77 00 00 00',
                'pin': '4321',
            }),
            headers={'Content-Type': 'application/json'}
        )
        return response.json().get('result', {}).get('token')

    def test_api_create_booking_for_self(self):
        """Test de création de réservation pour soi-même"""
        token = self._get_auth_token()
        
        response = self.url_open(
            '/api/v1/usager/bookings/create',
            data=json.dumps({
                'trip_id': self.trip.id,
                'passenger_name': 'Booking Test User',
                'passenger_phone': '+225 07 77 00 00 00',
                'boarding_stop_id': self.city_from.id,
                'alighting_stop_id': self.city_to.id,
                'for_other': False,
            }),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {token}',
            }
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        
        booking_data = result.get('result', {}).get('data', {})
        self.assertTrue(booking_data.get('id'))
        self.assertEqual(booking_data.get('passenger_name'), 'Booking Test User')
        self.assertFalse(booking_data.get('is_for_other'))

    def test_api_create_booking_for_other(self):
        """Test de création de réservation pour un tiers"""
        token = self._get_auth_token()
        
        response = self.url_open(
            '/api/v1/usager/bookings/create',
            data=json.dumps({
                'trip_id': self.trip.id,
                'passenger_name': 'Jean Dupont',
                'passenger_phone': '+225 07 66 55 44 33',
                'boarding_stop_id': self.city_from.id,
                'alighting_stop_id': self.city_to.id,
                'for_other': True,
                'other_passenger': {
                    'name': 'Jean Dupont',
                    'phone': '+225 07 66 55 44 33',
                    'email': 'jean@exemple.ci',
                    'relation': 'Ami',
                }
            }),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {token}',
            }
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        
        booking_data = result.get('result', {}).get('data', {})
        self.assertTrue(booking_data.get('id'))
        self.assertEqual(booking_data.get('passenger_name'), 'Jean Dupont')
        self.assertTrue(booking_data.get('is_for_other'))
        
        # Vérifier que l'acheteur est bien enregistré
        booking = self.env['transport.booking'].browse(booking_data['id'])
        self.assertEqual(booking.buyer_id.id, self.passenger.id)

    def test_api_get_my_bookings(self):
        """Test de récupération de mes réservations"""
        token = self._get_auth_token()
        
        # D'abord créer une réservation
        self.url_open(
            '/api/v1/usager/bookings/create',
            data=json.dumps({
                'trip_id': self.trip.id,
                'passenger_name': 'Booking Test User',
                'passenger_phone': '+225 07 77 00 00 00',
                'boarding_stop_id': self.city_from.id,
                'alighting_stop_id': self.city_to.id,
            }),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {token}',
            }
        )
        
        # Récupérer les réservations
        response = self.url_open(
            '/api/v1/usager/bookings',
            data=json.dumps({}),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {token}',
            }
        )
        self.assertEqual(response.status_code, 200)
        result = response.json()
        
        bookings = result.get('result', {}).get('data', [])
        self.assertTrue(len(bookings) >= 1)


@tagged('post_install', '-at_install', 'transport', 'api')
class TestTransportAPITicketShare(HttpCase):
    """Tests pour le partage de tickets via API"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        cls.company = cls.env['transport.company'].create({
            'name': 'Share API Company',
            'state': 'active',
        })
        
        cls.city_a = cls.env['transport.city'].create({'name': 'Share A', 'code': 'SHA'})
        cls.city_b = cls.env['transport.city'].create({'name': 'Share B', 'code': 'SHB'})
        
        cls.route = cls.env['transport.route'].create({
            'name': 'SHA - SHB',
            'departure_city_id': cls.city_a.id,
            'arrival_city_id': cls.city_b.id,
            'base_price': 2500,
            'state': 'active',
        })
        
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-SHARE',
            'transport_company_id': cls.company.id,
            'seat_capacity': 25,
            'state': 'available',
        })
        
        cls.trip = cls.env['transport.trip'].create({
            'transport_company_id': cls.company.id,
            'route_id': cls.route.id,
            'bus_id': cls.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare Share',
            'price': 2500,
        })
        cls.trip.action_schedule()
        
        cls.partner = cls.env['res.partner'].create({
            'name': 'Share User',
            'phone': '+225 07 55 00 00 00',
        })
        
        cls.booking = cls.env['transport.booking'].create({
            'trip_id': cls.trip.id,
            'partner_id': cls.partner.id,
            'passenger_name': 'Share User',
            'passenger_phone': '+225 07 55 00 00 00',
            'ticket_price': 2500,
            'boarding_stop_id': cls.city_a.id,
            'alighting_stop_id': cls.city_b.id,
        })
        cls.booking.action_reserve()
        cls.booking.amount_paid = 2500
        cls.booking.action_confirm()

    def test_api_generate_share_token(self):
        """Test de génération du token de partage"""
        # Générer le token de partage
        result = self.booking.action_generate_share_token()
        
        self.assertIn('share_token', result)
        self.assertIn('share_url', result)
        self.assertTrue(self.booking.share_token)
        self.assertTrue(len(self.booking.share_token) == 12)

    def test_api_access_shared_ticket(self):
        """Test d'accès au ticket partagé via URL publique"""
        # Générer le token
        self.booking.action_generate_share_token()
        share_token = self.booking.share_token
        
        # Accéder à l'URL de partage
        response = self.url_open(f'/ticket/share/{share_token}')
        self.assertEqual(response.status_code, 200)
        
        # Vérifier que la page contient les infos du ticket
        content = response.text
        self.assertIn(self.booking.name, content)
        self.assertIn('Share User', content)

    def test_api_shared_ticket_invalid_token(self):
        """Test d'accès avec token invalide"""
        response = self.url_open('/ticket/share/INVALID_TOKEN')
        self.assertEqual(response.status_code, 200)
        
        # Vérifier le message d'erreur
        content = response.text
        self.assertIn('introuvable', content.lower())

    def test_api_shared_ticket_json(self):
        """Test d'accès au ticket partagé en JSON"""
        self.booking.action_generate_share_token()
        share_token = self.booking.share_token
        
        response = self.url_open(
            f'/ticket/share/{share_token}/json',
            headers={'Content-Type': 'application/json'}
        )
        self.assertEqual(response.status_code, 200)
        
        result = response.json()
        self.assertTrue(result.get('success'))
        ticket = result.get('ticket', {})
        self.assertEqual(ticket.get('name'), self.booking.name)
