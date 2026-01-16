# -*- coding: utf-8 -*-

from odoo.tests import TransactionCase, tagged
from odoo.exceptions import ValidationError, UserError
from datetime import datetime, timedelta
from freezegun import freeze_time


@tagged('post_install', '-at_install', 'transport')
class TestTransportTrip(TransactionCase):
    """Tests pour le modèle transport.trip"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        # Créer les données de test
        cls.company = cls.env['transport.company'].create({
            'name': 'Compagnie Test',
            'phone': '+225 01 02 03 04 05',
            'email': 'test@company.ci',
            'state': 'active',
        })
        
        cls.city_departure = cls.env['transport.city'].create({
            'name': 'Abidjan Test',
            'code': 'ABJ_TEST',
            'region': 'Lagunes',
            'is_major_city': True,
        })
        
        cls.city_arrival = cls.env['transport.city'].create({
            'name': 'Yamoussoukro Test',
            'code': 'YAM_TEST',
            'region': 'Lacs',
            'is_major_city': True,
        })
        
        cls.city_intermediate = cls.env['transport.city'].create({
            'name': 'Toumodi Test',
            'code': 'TOU_TEST',
            'region': 'Lacs',
        })
        
        cls.route = cls.env['transport.route'].create({
            'name': 'ABJ_TEST - YAM_TEST',
            'departure_city_id': cls.city_departure.id,
            'arrival_city_id': cls.city_arrival.id,
            'distance_km': 240,
            'estimated_duration': 3.5,
            'base_price': 5000,
            'state': 'active',
        })
        
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-TEST-001',
            'company_id': cls.company.id,
            'immatriculation': 'AA 0000 BB',
            'seat_capacity': 50,
            'state': 'available',
        })
        
        cls.partner = cls.env['res.partner'].create({
            'name': 'Client Test',
            'phone': '+225 07 00 00 00 00',
            'email': 'client@test.ci',
        })

    def test_trip_creation(self):
        """Test de création d'un voyage"""
        trip = self.env['transport.trip'].create({
            'company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare Test',
            'price': 5000,
        })
        
        self.assertTrue(trip.name != '/')
        self.assertEqual(trip.state, 'draft')
        self.assertEqual(trip.total_seats, 50)
        self.assertEqual(trip.available_seats, 50)
        self.assertEqual(trip.booked_seats, 0)

    def test_trip_schedule(self):
        """Test de programmation d'un voyage"""
        trip = self.env['transport.trip'].create({
            'company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare Test',
            'price': 5000,
        })
        
        trip.action_schedule()
        self.assertEqual(trip.state, 'scheduled')

    def test_trip_cannot_schedule_without_bus(self):
        """Test qu'on ne peut pas programmer sans bus"""
        trip = self.env['transport.trip'].create({
            'company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare Test',
            'price': 5000,
        })
        trip.bus_id = False
        
        with self.assertRaises(UserError):
            trip.action_schedule()

    def test_trip_price_validation(self):
        """Test des contraintes de prix"""
        with self.assertRaises(ValidationError):
            self.env['transport.trip'].create({
                'company_id': self.company.id,
                'route_id': self.route.id,
                'bus_id': self.bus.id,
                'departure_datetime': datetime.now() + timedelta(days=1),
                'meeting_point': 'Gare Test',
                'price': 5000,
                'vip_price': 3000,  # VIP inférieur au normal = erreur
            })

    def test_trip_child_price_validation(self):
        """Test que le prix enfant ne dépasse pas le prix normal"""
        with self.assertRaises(ValidationError):
            self.env['transport.trip'].create({
                'company_id': self.company.id,
                'route_id': self.route.id,
                'bus_id': self.bus.id,
                'departure_datetime': datetime.now() + timedelta(days=1),
                'meeting_point': 'Gare Test',
                'price': 5000,
                'child_price': 6000,  # Enfant supérieur au normal = erreur
            })

    def test_trip_bus_company_validation(self):
        """Test que le bus appartient à la compagnie"""
        other_company = self.env['transport.company'].create({
            'name': 'Autre Compagnie',
            'state': 'active',
        })
        
        with self.assertRaises(ValidationError):
            self.env['transport.trip'].create({
                'company_id': other_company.id,
                'route_id': self.route.id,
                'bus_id': self.bus.id,  # Bus de self.company
                'departure_datetime': datetime.now() + timedelta(days=1),
                'meeting_point': 'Gare Test',
                'price': 5000,
            })

    def test_trip_available_seats_calculation(self):
        """Test du calcul des places disponibles"""
        trip = self.env['transport.trip'].create({
            'company_id': self.company.id,
            'route_id': self.route.id,
            'bus_id': self.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare Test',
            'price': 5000,
        })
        trip.action_schedule()
        
        # Créer une réservation
        booking = self.env['transport.booking'].create({
            'trip_id': trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Test Passager',
            'passenger_phone': '+225 07 00 00 00 00',
            'ticket_price': 5000,
            'boarding_stop_id': self.city_departure.id,
            'alighting_stop_id': self.city_arrival.id,
        })
        booking.action_reserve()
        
        # Recalculer
        trip._compute_seat_availability()
        self.assertEqual(trip.booked_seats, 1)
        self.assertEqual(trip.available_seats, 49)


@tagged('post_install', '-at_install', 'transport')
class TestTransportBooking(TransactionCase):
    """Tests pour le modèle transport.booking"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        cls.company = cls.env['transport.company'].create({
            'name': 'Compagnie Test',
            'phone': '+225 01 02 03 04 05',
            'reservation_duration_hours': 24,
            'state': 'active',
        })
        
        cls.city_departure = cls.env['transport.city'].create({
            'name': 'Abidjan',
            'code': 'ABJ',
            'is_major_city': True,
        })
        
        cls.city_arrival = cls.env['transport.city'].create({
            'name': 'Bouaké',
            'code': 'BKE',
            'is_major_city': True,
        })
        
        cls.route = cls.env['transport.route'].create({
            'name': 'ABJ - BKE',
            'departure_city_id': cls.city_departure.id,
            'arrival_city_id': cls.city_arrival.id,
            'distance_km': 350,
            'estimated_duration': 4.5,
            'base_price': 6000,
            'state': 'active',
        })
        
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-002',
            'company_id': cls.company.id,
            'immatriculation': 'CC 1111 DD',
            'seat_capacity': 40,
            'state': 'available',
        })
        
        cls.trip = cls.env['transport.trip'].create({
            'company_id': cls.company.id,
            'route_id': cls.route.id,
            'bus_id': cls.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=2),
            'meeting_point': 'Gare routière',
            'price': 6000,
            'vip_price': 10000,
            'child_price': 3000,
        })
        cls.trip.action_schedule()
        
        cls.partner = cls.env['res.partner'].create({
            'name': 'Passager Test',
            'phone': '+225 05 00 00 00 00',
            'email': 'passager@test.ci',
        })

    def test_booking_creation(self):
        """Test de création d'une réservation"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Test Passager',
            'passenger_phone': '+225 05 00 00 00 00',
            'ticket_price': 6000,
            'boarding_stop_id': self.city_departure.id,
            'alighting_stop_id': self.city_arrival.id,
        })
        
        self.assertTrue(booking.name != '/')
        self.assertEqual(booking.state, 'draft')
        self.assertEqual(booking.ticket_price, 6000)

    def test_booking_reservation(self):
        """Test de réservation"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Test Passager',
            'passenger_phone': '+225 05 00 00 00 00',
            'ticket_price': 6000,
            'boarding_stop_id': self.city_departure.id,
            'alighting_stop_id': self.city_arrival.id,
        })
        
        booking.action_reserve()
        self.assertEqual(booking.state, 'reserved')
        self.assertEqual(booking.booking_type, 'reservation')
        self.assertTrue(booking.reservation_deadline)

    def test_booking_confirmation_requires_payment(self):
        """Test que la confirmation requiert le paiement"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Test Passager',
            'passenger_phone': '+225 05 00 00 00 00',
            'ticket_price': 6000,
            'boarding_stop_id': self.city_departure.id,
            'alighting_stop_id': self.city_arrival.id,
        })
        booking.action_reserve()
        
        with self.assertRaises(UserError):
            booking.action_confirm()  # Pas de paiement

    def test_booking_confirmation_with_payment(self):
        """Test de confirmation avec paiement"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Test Passager',
            'passenger_phone': '+225 05 00 00 00 00',
            'ticket_price': 6000,
            'boarding_stop_id': self.city_departure.id,
            'alighting_stop_id': self.city_arrival.id,
        })
        booking.action_reserve()
        
        # Simuler le paiement
        booking.amount_paid = booking.total_amount
        booking.action_confirm()
        
        self.assertEqual(booking.state, 'confirmed')
        self.assertTrue(booking.qr_code)

    def test_booking_phone_validation(self):
        """Test de validation du numéro de téléphone"""
        with self.assertRaises(ValidationError):
            self.env['transport.booking'].create({
                'trip_id': self.trip.id,
                'partner_id': self.partner.id,
                'passenger_name': 'Test',
                'passenger_phone': 'invalide',  # Format invalide
                'ticket_price': 6000,
                'boarding_stop_id': self.city_departure.id,
                'alighting_stop_id': self.city_arrival.id,
            })

    def test_booking_email_validation(self):
        """Test de validation de l'email"""
        with self.assertRaises(ValidationError):
            self.env['transport.booking'].create({
                'trip_id': self.trip.id,
                'partner_id': self.partner.id,
                'passenger_name': 'Test',
                'passenger_phone': '+225 05 00 00 00 00',
                'passenger_email': 'email-invalide',  # Format invalide
                'ticket_price': 6000,
                'boarding_stop_id': self.city_departure.id,
                'alighting_stop_id': self.city_arrival.id,
            })

    def test_booking_stops_order_validation(self):
        """Test que l'arrêt de descente est après l'arrêt de montée"""
        with self.assertRaises(ValidationError):
            self.env['transport.booking'].create({
                'trip_id': self.trip.id,
                'partner_id': self.partner.id,
                'passenger_name': 'Test',
                'passenger_phone': '+225 05 00 00 00 00',
                'ticket_price': 6000,
                'boarding_stop_id': self.city_arrival.id,  # Inversé
                'alighting_stop_id': self.city_departure.id,  # Inversé
            })

    def test_booking_total_amount_computation(self):
        """Test du calcul du montant total"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Test',
            'passenger_phone': '+225 05 00 00 00 00',
            'ticket_price': 6000,
            'reservation_fee': 500,
            'boarding_stop_id': self.city_departure.id,
            'alighting_stop_id': self.city_arrival.id,
            'booking_type': 'reservation',
        })
        
        self.assertEqual(booking.total_amount, 6500)  # 6000 + 500

    def test_booking_amount_due_computation(self):
        """Test du calcul du montant restant"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Test',
            'passenger_phone': '+225 05 00 00 00 00',
            'ticket_price': 6000,
            'boarding_stop_id': self.city_departure.id,
            'alighting_stop_id': self.city_arrival.id,
        })
        
        self.assertEqual(booking.amount_due, 6000)
        
        booking.amount_paid = 2000
        self.assertEqual(booking.amount_due, 4000)

    def test_booking_cannot_overpay(self):
        """Test qu'on ne peut pas payer plus que le total"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Test',
            'passenger_phone': '+225 05 00 00 00 00',
            'ticket_price': 6000,
            'boarding_stop_id': self.city_departure.id,
            'alighting_stop_id': self.city_arrival.id,
        })
        
        with self.assertRaises(ValidationError):
            booking.amount_paid = 10000  # Plus que le total

    def test_booking_cancellation(self):
        """Test d'annulation"""
        booking = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Test',
            'passenger_phone': '+225 05 00 00 00 00',
            'ticket_price': 6000,
            'boarding_stop_id': self.city_departure.id,
            'alighting_stop_id': self.city_arrival.id,
        })
        booking.action_reserve()
        booking.action_cancel()
        
        self.assertEqual(booking.state, 'cancelled')


@tagged('post_install', '-at_install', 'transport')
class TestTransportSeatAvailability(TransactionCase):
    """Tests pour le calcul de disponibilité des sièges par segment"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        cls.company = cls.env['transport.company'].create({
            'name': 'Compagnie Test',
            'state': 'active',
        })
        
        # Créer un itinéraire avec arrêt intermédiaire: A -> B -> C
        cls.city_a = cls.env['transport.city'].create({'name': 'Ville A', 'code': 'A'})
        cls.city_b = cls.env['transport.city'].create({'name': 'Ville B', 'code': 'B'})
        cls.city_c = cls.env['transport.city'].create({'name': 'Ville C', 'code': 'C'})
        
        cls.route = cls.env['transport.route'].create({
            'name': 'A - C',
            'departure_city_id': cls.city_a.id,
            'arrival_city_id': cls.city_c.id,
            'distance_km': 200,
            'estimated_duration': 3,
            'base_price': 5000,
            'state': 'active',
        })
        
        # Ajouter l'arrêt intermédiaire B
        cls.env['transport.route.stop'].create({
            'route_id': cls.route.id,
            'city_id': cls.city_b.id,
            'sequence': 1,
            'duration_from_start': 1.5,
            'price_from_start': 2500,
            'price_to_end': 2500,
        })
        
        cls.bus = cls.env['transport.bus'].create({
            'name': 'BUS-SMALL',
            'company_id': cls.company.id,
            'immatriculation': 'XX 0000 YY',
            'seat_capacity': 5,  # Petit bus pour le test
            'state': 'available',
        })
        
        cls.trip = cls.env['transport.trip'].create({
            'company_id': cls.company.id,
            'route_id': cls.route.id,
            'bus_id': cls.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare A',
            'price': 5000,
        })
        cls.trip.action_schedule()
        
        cls.partner = cls.env['res.partner'].create({'name': 'Client'})

    def test_full_route_availability(self):
        """Test disponibilité sur le trajet complet"""
        available = self.trip.get_available_seats(self.city_a, self.city_c)
        self.assertEqual(available, 5)

    def test_segment_availability_after_booking(self):
        """Test disponibilité après une réservation sur un segment"""
        # Réserver 2 places de A à B
        for i in range(2):
            booking = self.env['transport.booking'].create({
                'trip_id': self.trip.id,
                'partner_id': self.partner.id,
                'passenger_name': f'Passager {i+1}',
                'passenger_phone': '+225 00 00 00 00 00',
                'ticket_price': 2500,
                'boarding_stop_id': self.city_a.id,
                'alighting_stop_id': self.city_b.id,
            })
            booking.action_reserve()
        
        # Segment A->B: 3 places restantes
        available_ab = self.trip.get_available_seats(self.city_a, self.city_b)
        self.assertEqual(available_ab, 3)
        
        # Segment B->C: 5 places (les passagers A->B sont descendus)
        available_bc = self.trip.get_available_seats(self.city_b, self.city_c)
        self.assertEqual(available_bc, 5)
        
        # Trajet complet A->C: 3 places (limité par segment A->B)
        available_ac = self.trip.get_available_seats(self.city_a, self.city_c)
        self.assertEqual(available_ac, 3)

    def test_overbooking_prevention(self):
        """Test de prévention du surbooking"""
        # Remplir le bus pour le trajet A->C
        for i in range(5):
            booking = self.env['transport.booking'].create({
                'trip_id': self.trip.id,
                'partner_id': self.partner.id,
                'passenger_name': f'Passager {i+1}',
                'passenger_phone': '+225 00 00 00 00 00',
                'ticket_price': 5000,
                'boarding_stop_id': self.city_a.id,
                'alighting_stop_id': self.city_c.id,
            })
            booking.action_reserve()
        
        # Essayer d'ajouter une 6ème réservation
        booking6 = self.env['transport.booking'].create({
            'trip_id': self.trip.id,
            'partner_id': self.partner.id,
            'passenger_name': 'Passager 6',
            'passenger_phone': '+225 00 00 00 00 00',
            'ticket_price': 5000,
            'boarding_stop_id': self.city_a.id,
            'alighting_stop_id': self.city_c.id,
        })
        
        with self.assertRaises(UserError):
            booking6.action_reserve()


@tagged('post_install', '-at_install', 'transport')
class TestTransportPayment(TransactionCase):
    """Tests pour le modèle transport.payment"""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        
        cls.company = cls.env['transport.company'].create({
            'name': 'Compagnie Payment',
            'state': 'active',
            'allow_online_payment': True,
            'wave_merchant_id': 'WAVE_TEST_123',
            'wave_api_key': 'api_key_test',
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
            'name': 'BUS-PAY',
            'company_id': cls.company.id,
            'seat_capacity': 50,
            'state': 'available',
        })
        
        cls.trip = cls.env['transport.trip'].create({
            'company_id': cls.company.id,
            'route_id': cls.route.id,
            'bus_id': cls.bus.id,
            'departure_datetime': datetime.now() + timedelta(days=1),
            'meeting_point': 'Gare',
            'price': 5000,
        })
        cls.trip.action_schedule()
        
        cls.partner = cls.env['res.partner'].create({'name': 'Client Payment'})
        
        cls.booking = cls.env['transport.booking'].create({
            'trip_id': cls.trip.id,
            'partner_id': cls.partner.id,
            'passenger_name': 'Test Payment',
            'passenger_phone': '+225 07 00 00 00 00',
            'ticket_price': 5000,
            'boarding_stop_id': cls.city_dep.id,
            'alighting_stop_id': cls.city_arr.id,
        })
        cls.booking.action_reserve()

    def test_payment_creation(self):
        """Test de création d'un paiement"""
        payment = self.env['transport.payment'].create({
            'booking_id': self.booking.id,
            'amount': 5000,
            'payment_method': 'wave',
        })
        
        self.assertTrue(payment.name != '/')
        self.assertEqual(payment.state, 'pending')
        self.assertEqual(payment.company_id, self.company)

    def test_payment_completion(self):
        """Test de complétion d'un paiement"""
        payment = self.env['transport.payment'].create({
            'booking_id': self.booking.id,
            'amount': 5000,
            'payment_method': 'cash',
        })
        
        payment.action_complete_payment()
        
        self.assertEqual(payment.state, 'completed')
        self.assertEqual(self.booking.amount_paid, 5000)
        self.assertEqual(self.booking.state, 'confirmed')
