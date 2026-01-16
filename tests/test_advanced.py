# -*- coding: utf-8 -*-
"""
Tests unitaires avancés pour le module transport_interurbain
Tests de workflow, edge cases, et scénarios complexes
"""

import logging
from datetime import datetime, timedelta
from freezegun import freeze_time

from odoo.tests import TransactionCase, tagged
from odoo.exceptions import ValidationError, UserError

_logger = logging.getLogger(__name__)


@tagged('post_install', '-at_install', 'transport')
class TestTransportThirdPartyPurchase(TransactionCase):
    """Tests pour l'achat de billets pour un tiers"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        cls.company = cls.env['transport.company'].create({
            'name': 'Third Party Company',
            'state': 'active',
        })
        
        cls.city_dep = cls.env['transport.city'].create({'name': 'Départ', 'code': 'DEP'})
        cls.city_arr = cls.env['transport.city'].create({'name': 'Arrivée', 'code': 'ARR'})
        
        cls.route = cls.env['transport.route'].create({
            'name': 'DEP - ARR',
            'departure_city_id': cls.city_dep.id,
            'arrival_city_id': cls.city_arr.id,
            'base_price': 5000,
            'state': 'active',
        })
        
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-TPP',
            'transport_company_id': cls.company.id,
            'seat_capacity': 40,
            'state': 'available',
        })
        
        cls.trip = cls.env['transport.trip'].create({
            'transport_company_id': cls.company.id,
            'route_id': cls.route.id,
            'bus_id': cls.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=3),
            'meeting_point': 'Gare Test',
            'price': 5000,
        })
        cls.trip.action_schedule()
        
        # Acheteur (passager enregistré)
        cls.buyer = cls.env['transport.passenger'].create({
            'name': 'Acheteur Principal',
            'phone': '+225 07 00 00 00 01',
            'email': 'acheteur@test.ci',
        })
        
        cls.partner = cls.env['res.partner'].create({
            'name': 'Partner Acheteur',
            'phone': '+225 07 00 00 00 01',
        })

    def test_third_party_booking_creation(self):
        """Test de création d'une réservation pour un tiers"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Jean Dupont',  # Le passager réel
            'passenger_phone': '+225 07 11 22 33 44',
            'passenger_email': 'jean@exemple.ci',
            'ticket_price': 5000,
            'boarding_stop_id': self.city_dep.id,
            'alighting_stop_id': self.city_arr.id,
            'is_for_other': True,
            'buyer_id': self.buyer.id,
        })
        
        self.assertTrue(booking.is_for_other)
        self.assertEqual(booking.buyer_id, self.buyer)
        self.assertEqual(booking.passenger_name, 'Jean Dupont')
        # L'acheteur et le passager sont différents
        self.assertNotEqual(booking.passenger_name, self.buyer.name)

    def test_third_party_booking_requires_passenger_info(self):
        """Test que les infos du passager sont requises pour achat tiers"""
        with self.assertRaises(ValidationError):
            self.env['transport.booking'].create({
                'trip_id': self.trip.id,
                'partner_id': self.partner.id,
                'passenger_name': '',  # Pas de nom
                'passenger_phone': '+225 07 11 22 33 44',
                'ticket_price': 5000,
                'boarding_stop_id': self.city_dep.id,
                'alighting_stop_id': self.city_arr.id,
                'is_for_other': True,
                'buyer_id': self.buyer.id,
            })

    def test_buyer_sees_their_purchases(self):
        """Test que l'acheteur voit les billets qu'il a achetés pour d'autres"""
        # Créer plusieurs réservations
        booking1 = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Personne A',
            'passenger_phone': '+225 07 11 11 11 11',
            'ticket_price': 5000,
            'boarding_stop_id': self.city_dep.id,
            'alighting_stop_id': self.city_arr.id,
            'is_for_other': True,
            'buyer_id': self.buyer.id,
        })
        
        booking2 = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Personne B',
            'passenger_phone': '+225 07 22 22 22 22',
            'ticket_price': 5000,
            'boarding_stop_id': self.city_dep.id,
            'alighting_stop_id': self.city_arr.id,
            'is_for_other': True,
            'buyer_id': self.buyer.id,
        })
        
        # Rechercher les achats de l'acheteur
        purchases = self.env['transport.booking'].search([
            ('buyer_id', '=', self.buyer.id),
        ])
        
        self.assertEqual(len(purchases), 2)
        self.assertIn(booking1, purchases)
        self.assertIn(booking2, purchases)


@tagged('post_install', '-at_install', 'transport')
class TestTransportTicketSharing(TransactionCase):
    """Tests pour le partage de tickets"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        cls.company = cls.env['transport.company'].create({
            'name': 'Share Company',
            'state': 'active',
        })
        
        cls.city_dep = cls.env['transport.city'].create({'name': 'Départ Share', 'code': 'DSH'})
        cls.city_arr = cls.env['transport.city'].create({'name': 'Arrivée Share', 'code': 'ASH'})
        
        cls.route = cls.env['transport.route'].create({
            'name': 'DSH - ASH',
            'departure_city_id': cls.city_dep.id,
            'arrival_city_id': cls.city_arr.id,
            'base_price': 4000,
            'state': 'active',
        })
        
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-SHARE',
            'transport_company_id': cls.company.id,
            'seat_capacity': 30,
            'state': 'available',
        })
        
        cls.trip = cls.env['transport.trip'].create({
            'transport_company_id': cls.company.id,
            'route_id': cls.route.id,
            'bus_id': cls.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=2),
            'meeting_point': 'Gare Share',
            'price': 4000,
        })
        cls.trip.action_schedule()
        
        cls.partner = cls.env['res.partner'].create({
            'name': 'Share Passenger',
            'phone': '+225 07 33 00 00 00',
        })

    def test_share_token_generation(self):
        """Test de génération du token de partage"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Share Passenger',
            'passenger_phone': '+225 07 33 00 00 00',
            'ticket_price': 4000,
            'boarding_stop_id': self.city_dep.id,
            'alighting_stop_id': self.city_arr.id,
        })
        booking.action_reserve()
        booking.amount_paid = 4000
        booking.action_confirm()
        
        # Générer le token de partage
        result = booking.action_generate_share_token()
        
        self.assertTrue(booking.share_token)
        self.assertEqual(len(booking.share_token), 12)
        self.assertTrue(booking.share_token.isupper())
        self.assertIn('share_token', result)
        self.assertIn('share_url', result)

    def test_share_token_uniqueness(self):
        """Test d'unicité du token de partage"""
        bookings = []
        for i in range(5):
            booking = self.env['transport.booking'].create({
                'trip_id': self.trip.id,
                'partner_id': self.partner.id,
                'passenger_name': f'Passager {i+1}',
                'passenger_phone': f'+225 07 33 00 00 0{i}',
                'ticket_price': 4000,
                'boarding_stop_id': self.city_dep.id,
                'alighting_stop_id': self.city_arr.id,
            })
            booking.action_reserve()
            booking.amount_paid = 4000
            booking.action_confirm()
            booking.action_generate_share_token()
            bookings.append(booking)
        
        # Vérifier que tous les tokens sont uniques
        tokens = [b.share_token for b in bookings]
        self.assertEqual(len(tokens), len(set(tokens)))

    def test_share_url_computation(self):
        """Test du calcul de l'URL de partage"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'URL Test',
            'passenger_phone': '+225 07 33 11 00 00',
            'ticket_price': 4000,
            'boarding_stop_id': self.city_dep.id,
            'alighting_stop_id': self.city_arr.id,
        })
        booking.action_reserve()
        booking.amount_paid = 4000
        booking.action_confirm()
        booking.action_generate_share_token()
        
        self.assertTrue(booking.share_url)
        self.assertIn('/ticket/share/', booking.share_url)
        self.assertIn(booking.share_token, booking.share_url)

    def test_share_token_not_regenerated(self):
        """Test que le token n'est pas regénéré s'il existe déjà"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Token Test',
            'passenger_phone': '+225 07 33 22 00 00',
            'ticket_price': 4000,
            'boarding_stop_id': self.city_dep.id,
            'alighting_stop_id': self.city_arr.id,
        })
        booking.action_reserve()
        booking.amount_paid = 4000
        booking.action_confirm()
        
        # Première génération
        booking.action_generate_share_token()
        original_token = booking.share_token
        
        # Deuxième appel
        booking.action_generate_share_token()
        
        # Le token devrait être le même
        self.assertEqual(booking.share_token, original_token)


@tagged('post_install', '-at_install', 'transport')
class TestTransportWorkflows(TransactionCase):
    """Tests des workflows complets"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        cls.company = cls.env['transport.company'].create({
            'name': 'Workflow Company',
            'reservation_duration_hours': 2,  # 2 heures pour tester l'expiration
            'state': 'active',
        })
        
        cls.city_dep = cls.env['transport.city'].create({'name': 'WF Départ', 'code': 'WFD'})
        cls.city_arr = cls.env['transport.city'].create({'name': 'WF Arrivée', 'code': 'WFA'})
        
        cls.route = cls.env['transport.route'].create({
            'name': 'WFD - WFA',
            'departure_city_id': cls.city_dep.id,
            'arrival_city_id': cls.city_arr.id,
            'base_price': 6000,
            'state': 'active',
        })
        
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-WF',
            'transport_company_id': cls.company.id,
            'seat_capacity': 20,
            'state': 'available',
        })
        
        cls.partner = cls.env['res.partner'].create({
            'name': 'WF Passenger',
            'phone': '+225 07 44 00 00 00',
        })

    def test_complete_booking_workflow(self):
        """Test du workflow complet de réservation"""
        # 1. Créer un voyage
        trip = self.env['transport.trip'].create({
            'transport_company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare WF',
            'price': 6000,
        })
        self.assertEqual(trip.state, 'draft')
        
        # 2. Programmer le voyage
        trip.action_schedule()
        self.assertEqual(trip.state, 'scheduled')
        
        # 3. Créer une réservation
        booking = self.env['transport.booking'].create({
            'trip_id': trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'WF Passenger',
            'passenger_phone': '+225 07 44 00 00 00',
            'ticket_price': 6000,
            'boarding_stop_id': self.city_dep.id,
            'alighting_stop_id': self.city_arr.id,
        })
        self.assertEqual(booking.state, 'draft')
        
        # 4. Réserver (temporaire)
        booking.action_reserve()
        self.assertEqual(booking.state, 'reserved')
        self.assertEqual(booking.booking_type, 'reservation')
        self.assertTrue(booking.reservation_deadline)
        
        # 5. Payer et confirmer
        booking.amount_paid = 6000
        booking.action_confirm()
        self.assertEqual(booking.state, 'confirmed')
        self.assertEqual(booking.booking_type, 'purchase')
        self.assertTrue(booking.qr_code)
        
        # 6. Démarrer l'embarquement
        trip.action_start_boarding()
        self.assertEqual(trip.state, 'boarding')
        
        # 7. Embarquer le passager
        booking.action_check_in()
        self.assertEqual(booking.state, 'checked_in')
        
        # 8. Démarrer le voyage
        trip.action_depart()
        self.assertEqual(trip.state, 'departed')
        
        # 9. Terminer le voyage
        trip.action_arrive()
        self.assertEqual(trip.state, 'arrived')

    def test_booking_cancellation_workflow(self):
        """Test du workflow d'annulation"""
        trip = self.env['transport.trip'].create({
            'transport_company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare WF',
            'price': 6000,
        })
        trip.action_schedule()
        
        booking = self.env['transport.booking'].create({
            'trip_id': trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Cancel Test',
            'passenger_phone': '+225 07 44 11 00 00',
            'ticket_price': 6000,
            'boarding_stop_id': self.city_dep.id,
            'alighting_stop_id': self.city_arr.id,
        })
        
        booking.action_reserve()
        self.assertEqual(booking.state, 'reserved')
        
        # Annuler avant paiement
        booking.action_cancel()
        self.assertEqual(booking.state, 'cancelled')
        
        # Vérifier qu'on ne peut pas réserver un billet annulé
        with self.assertRaises(UserError):
            booking.action_reserve()

    def test_reservation_expiration(self):
        """Test de l'expiration des réservations non payées"""
        trip = self.env['transport.trip'].create({
            'transport_company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare WF',
            'price': 6000,
        })
        trip.action_schedule()
        
        booking = self.env['transport.booking'].create({
            'trip_id': trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Expire Test',
            'passenger_phone': '+225 07 44 22 00 00',
            'ticket_price': 6000,
            'boarding_stop_id': self.city_dep.id,
            'alighting_stop_id': self.city_arr.id,
        })
        booking.action_reserve()
        
        # Simuler le passage du temps (3 heures, la limite est 2h)
        booking.reservation_deadline = datetime.now() - timedelta(hours=1)
        
        # Exécuter le cron d'expiration
        self.env['transport.booking'].cron_expire_reservations()
        
        booking.invalidate_recordset()
        self.assertEqual(booking.state, 'expired')


@tagged('post_install', '-at_install', 'transport')
class TestTransportEdgeCases(TransactionCase):
    """Tests des cas limites et edge cases"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        cls.company = cls.env['transport.company'].create({
            'name': 'Edge Company',
            'state': 'active',
        })
        
        cls.city_a = cls.env['transport.city'].create({'name': 'Edge A', 'code': 'EA'})
        cls.city_b = cls.env['transport.city'].create({'name': 'Edge B', 'code': 'EB'})
        
        cls.route = cls.env['transport.route'].create({
            'name': 'EA - EB',
            'departure_city_id': cls.city_a.id,
            'arrival_city_id': cls.city_b.id,
            'base_price': 3000,
            'state': 'active',
        })
        
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-EDGE',
            'transport_company_id': cls.company.id,
            'seat_capacity': 3,  # Très petit pour tester les limites
            'state': 'available',
        })
        
        cls.partner = cls.env['res.partner'].create({
            'name': 'Edge User',
            'phone': '+225 07 55 00 00 00',
        })

    def test_overbooking_prevention(self):
        """Test de prévention du surbooking"""
        trip = self.env['transport.trip'].create({
            'transport_company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare Edge',
            'price': 3000,
        })
        trip.action_schedule()
        
        # Créer 3 réservations (capacité max)
        bookings = []
        for i in range(3):
            booking = self.env['transport.booking'].create({
                'trip_id': trip.id,
                'partner_id': self.partner.id,
                'passenger_name': f'Passager {i+1}',
                'passenger_phone': f'+225 07 55 00 00 0{i}',
                'ticket_price': 3000,
                'boarding_stop_id': self.city_a.id,
                'alighting_stop_id': self.city_b.id,
            })
            booking.action_reserve()
            bookings.append(booking)
        
        # La 4ème réservation doit échouer
        booking4 = self.env['transport.booking'].create({
            'trip_id': trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Passager 4',
            'passenger_phone': '+225 07 55 00 00 04',
            'ticket_price': 3000,
            'boarding_stop_id': self.city_a.id,
            'alighting_stop_id': self.city_b.id,
        })
        
        with self.assertRaises(UserError):
            booking4.action_reserve()

    def test_booking_past_trip(self):
        """Test qu'on ne peut pas réserver pour un voyage passé"""
        trip = self.env['transport.trip'].create({
            'transport_company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare Edge',
            'price': 3000,
        })
        trip.action_schedule()
        
        # Simuler que le voyage est passé
        trip.departure_datetime = datetime.now() - timedelta(hours=1)
        
        booking = self.env['transport.booking'].create({
            'trip_id': trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Past Trip Test',
            'passenger_phone': '+225 07 55 11 00 00',
            'ticket_price': 3000,
            'boarding_stop_id': self.city_a.id,
            'alighting_stop_id': self.city_b.id,
        })
        
        with self.assertRaises(UserError):
            booking.action_reserve()

    def test_cancel_checked_in_booking(self):
        """Test qu'on ne peut pas annuler un passager embarqué"""
        trip = self.env['transport.trip'].create({
            'transport_company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare Edge',
            'price': 3000,
        })
        trip.action_schedule()
        trip.action_start_boarding()
        
        booking = self.env['transport.booking'].create({
            'trip_id': trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Checked In Test',
            'passenger_phone': '+225 07 55 22 00 00',
            'ticket_price': 3000,
            'boarding_stop_id': self.city_a.id,
            'alighting_stop_id': self.city_b.id,
        })
        booking.action_reserve()
        booking.amount_paid = 3000
        booking.action_confirm()
        booking.action_check_in()
        
        with self.assertRaises(UserError):
            booking.action_cancel()

    def test_duplicate_phone_validation(self):
        """Test de validation avec numéros de téléphone identiques"""
        trip = self.env['transport.trip'].create({
            'transport_company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare Edge',
            'price': 3000,
        })
        trip.action_schedule()
        
        # Deux réservations avec le même téléphone doivent être possibles
        # (par exemple pour acheter plusieurs billets)
        booking1 = self.env['transport.booking'].create({
            'trip_id': trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Passager 1',
            'passenger_phone': '+225 07 55 33 00 00',
            'ticket_price': 3000,
            'boarding_stop_id': self.city_a.id,
            'alighting_stop_id': self.city_b.id,
        })
        booking1.action_reserve()
        
        booking2 = self.env['transport.booking'].create({
            'trip_id': trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Passager 2',
            'passenger_phone': '+225 07 55 33 00 00',  # Même numéro
            'ticket_price': 3000,
            'boarding_stop_id': self.city_a.id,
            'alighting_stop_id': self.city_b.id,
        })
        booking2.action_reserve()
        
        # Les deux doivent être créées sans erreur
        self.assertEqual(booking1.state, 'reserved')
        self.assertEqual(booking2.state, 'reserved')


@tagged('post_install', '-at_install', 'transport')
class TestTransportBusManagement(TransactionCase):
    """Tests pour la gestion des bus"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        cls.company = cls.env['transport.company'].create({
            'name': 'Bus Company',
            'state': 'active',
        })
        
        cls.city_a = cls.env['transport.city'].create({'name': 'Bus A', 'code': 'BA'})
        cls.city_b = cls.env['transport.city'].create({'name': 'Bus B', 'code': 'BB'})
        
        cls.route = cls.env['transport.route'].create({
            'name': 'BA - BB',
            'departure_city_id': cls.city_a.id,
            'arrival_city_id': cls.city_b.id,
            'base_price': 4000,
            'state': 'active',
        })

    def test_bus_cannot_be_assigned_twice_same_day(self):
        """Test qu'un bus ne peut pas être assigné à deux voyages le même jour"""
        bus = self.env['transport.bus'].create({
            'name': 'BUS-CONFLICT',
            'transport_company_id': self.company.id,
            'seat_capacity': 40,
            'state': 'available',
        })
        
        departure_date = datetime.now() + timedelta(days=2)
        
        # Premier voyage
        trip1 = self.env['transport.trip'].create({
            'transport_company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': bus.id,
            'departure_datetime': departure_date.replace(hour=8),
            'meeting_point': 'Gare 1',
            'price': 4000,
        })
        trip1.action_schedule()
        
        # Deuxième voyage le même jour
        with self.assertRaises(ValidationError):
            self.env['transport.trip'].create({
                'transport_company_id': self.company.id,
                'route_id': self.route.id,
                'bus_id': bus.id,
                'departure_datetime': departure_date.replace(hour=14),
                'meeting_point': 'Gare 2',
                'price': 4000,
            })

    def test_bus_state_management(self):
        """Test de la gestion des états du bus"""
        bus = self.env['transport.bus'].create({
            'name': 'BUS-STATE',
            'transport_company_id': self.company.id,
            'seat_capacity': 40,
            'state': 'available',
        })
        
        self.assertEqual(bus.state, 'available')
        
        # Passer en maintenance
        bus.state = 'maintenance'
        self.assertEqual(bus.state, 'maintenance')
        
        # Un bus en maintenance ne peut pas être assigné à un voyage
        with self.assertRaises(ValidationError):
            self.env['transport.trip'].create({
                'transport_company_id': self.company.id,
                'route_id': self.route.id,
                'bus_id': bus.id,
                'departure_datetime': datetime.now() + timedelta(days=1),
                'meeting_point': 'Gare Test',
                'price': 4000,
            })
